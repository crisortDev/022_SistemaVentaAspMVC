-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 82: Módulo Cuentas por Cobrar (CXC) + corrección Caja para crédito
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- PROBLEMA:
--   Las ventas a crédito (Condicion = 'Crédito') se insertaban en COMPROBANTE_COBRO
--   con Estado = 'Pendiente' y MontoRecibido = 0, pero:
--   (a) usp_CerrarCaja sumaba TODAS las ventas (incluyendo crédito) en MontoSistema
--   (b) usp_ObtenerCajaActiva mostraba TotalVentas mezclando contado y crédito
--   (c) No había tabla ni SP para registrar el cobro posterior del crédito
--
-- SOLUCIÓN:
--   1. Crear tabla COBRO_CXC — registra cada pago de crédito y lo vincula a la CAJA
--   2. usp_ObtenerCuentasPorCobrar — lista facturas crédito pendientes por tienda
--   3. usp_CobrarCuentaPendiente  — registra el pago, actualiza CC, inserta COBRO_CXC
--   4. usp_ObtenerCobrosCXC_Caja  — cobros de crédito de una sesión de caja
--   5. Corregir usp_CerrarCaja    — MontoSistema = ventas contado + cobros CXC
--   6. Corregir usp_ObtenerCajaActiva — separar TotalVentasContado / TotalVentasCredito / TotalCobrosCXC
--   7. Corregir usp_ObtenerOperacionesCaja — agregar Condicion + RS3 cobros CXC
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. TABLA: COBRO_CXC
--    Registra cada pago recibido sobre una factura a crédito.
--    Un COMPROBANTE_COBRO en estado 'Pendiente' puede tener exactamente un COBRO_CXC
--    cuando es cobrado (modelo simple: pago total del saldo, no cuotas).
-- ════════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.COBRO_CXC') AND type = 'U')
BEGIN
    CREATE TABLE dbo.COBRO_CXC (
        IdCobroCXC      INT           IDENTITY(1,1) NOT NULL,
        IdCompCobro     INT           NOT NULL,          -- COMPROBANTE_COBRO cobrado
        IdCaja          INT           NULL,              -- Caja donde se registró (puede ser NULL si no hay caja abierta)
        IdTienda        INT           NOT NULL,          -- Tienda del cobro (segregación)
        IdUsuario       INT           NOT NULL,          -- Quién registró el cobro
        IdFormaCobro    INT           NOT NULL,          -- Forma de pago del cobro
        MontoRecibido   DECIMAL(18,2) NOT NULL,
        MontoCambio     DECIMAL(18,2) NOT NULL DEFAULT 0,
        FechaCobro      DATETIME      NOT NULL DEFAULT GETDATE(),
        Observacion     VARCHAR(500)  NULL,

        CONSTRAINT PK_COBRO_CXC       PRIMARY KEY (IdCobroCXC),
        CONSTRAINT FK_COBRO_CXC_CC    FOREIGN KEY (IdCompCobro)  REFERENCES dbo.COMPROBANTE_COBRO(IdComprobanteCobro),
        CONSTRAINT FK_COBRO_CXC_CAJA  FOREIGN KEY (IdCaja)       REFERENCES dbo.CAJA(IdCaja),
        CONSTRAINT FK_COBRO_CXC_TIEND FOREIGN KEY (IdTienda)     REFERENCES dbo.TIENDA(IdTienda),
        CONSTRAINT FK_COBRO_CXC_USR   FOREIGN KEY (IdUsuario)    REFERENCES dbo.USUARIO(IdUsuario),
        CONSTRAINT FK_COBRO_CXC_FC    FOREIGN KEY (IdFormaCobro) REFERENCES dbo.FORMA_COBRO(IdFormaCobro)
    );
    PRINT 'OK: Tabla COBRO_CXC creada.';
END
ELSE
    PRINT 'INFO: Tabla COBRO_CXC ya existía.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. SP: usp_ObtenerCuentasPorCobrar
--    Lista facturas a crédito pendientes de cobro para una tienda.
--    @IdTienda = 0 → todas (solo para SuperAdmin)
--    Calcula días al vencimiento (negativo = vencida).
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCuentasPorCobrar
    @IdTienda  INT = 0,
    @SoloVencidas BIT = 0         -- 1 = mostrar solo vencidas
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cc.IdComprobanteCobro,
        cc.NumeroCobro,
        cc.Estado,
        cc.MontoTotal,
        cc.MontoRecibido,
        cc.MontoCambio,
        FORMAT(cc.FechaRegistro, 'dd/MM/yyyy HH:mm') AS FechaEmision,
        v.NumeroFactura,
        v.Codigo          AS CodigoVenta,
        ISNULL(v.Condicion, 'Contado')               AS Condicion,
        v.PlazoCredito,
        CONVERT(VARCHAR(10), v.FechaVencimientoCredito, 103) AS FechaVencimiento,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE),
                 v.FechaVencimientoCredito)          AS DiasParaVencer,  -- negativo = vencida
        -- Cliente
        c.IdCliente,
        c.Nombre          AS NombreCliente,
        c.NumeroDocumento,
        ISNULL(c.Telefono, '')                       AS TelefonoCliente,
        -- Tienda
        t.IdTienda,
        t.Nombre          AS NombreTienda,
        -- Cajero que emitió
        u.Nombres + ' ' + u.Apellidos                AS NombreCajero,
        -- Forma de cobro original de la factura
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion,'—')) AS FormaCobroOriginal
    FROM dbo.COMPROBANTE_COBRO cc
    INNER JOIN dbo.VENTA       v  ON v.IdVenta        = cc.IdVenta
    INNER JOIN dbo.CLIENTE     c  ON c.IdCliente       = v.IdCliente
    INNER JOIN dbo.TIENDA      t  ON t.IdTienda        = cc.IdTienda
    INNER JOIN dbo.USUARIO     u  ON u.IdUsuario       = cc.IdUsuario
    LEFT  JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro   = cc.IdFormaCobro
    WHERE cc.Estado = 'Pendiente'
      AND ISNULL(v.Condicion, 'Contado') = 'Crédito'
      AND (@IdTienda = 0 OR cc.IdTienda = @IdTienda)
      AND (@SoloVencidas = 0 OR v.FechaVencimientoCredito < CAST(GETDATE() AS DATE))
    ORDER BY
        v.FechaVencimientoCredito ASC,   -- primeras las más urgentes / vencidas
        cc.FechaRegistro ASC;
END
GO
PRINT 'OK: usp_ObtenerCuentasPorCobrar creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. SP: usp_CobrarCuentaPendiente
--    Registra el pago de una factura a crédito.
--    Reglas de negocio:
--      - El COMPROBANTE_COBRO debe estar en estado 'Pendiente'
--      - El cobrador debe pertenecer a la misma tienda del comprobante (segregación)
--      - Si hay caja abierta, se vincula; si no, IdCaja queda NULL
--      - Se actualiza COMPROBANTE_COBRO (Estado, MontoRecibido, MontoCambio)
--      - Se inserta un registro en COBRO_CXC para el arqueo de caja
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_CobrarCuentaPendiente
    @IdCompCobro    INT,
    @IdCaja         INT,           -- 0 si no hay caja abierta
    @IdUsuario      INT,           -- usuario que cobra
    @IdFormaCobro   INT,
    @MontoRecibido  DECIMAL(18,2),
    @Observacion    VARCHAR(500)   = NULL,
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- ── Obtener datos del comprobante ─────────────────────────────
        DECLARE @IdTiendaCC  INT,
                @EstadoCC    VARCHAR(20),
                @MontoTotal  DECIMAL(18,2),
                @IdVenta     INT;

        SELECT @IdTiendaCC = cc.IdTienda,
               @EstadoCC   = cc.Estado,
               @MontoTotal = cc.MontoTotal,
               @IdVenta    = cc.IdVenta
        FROM   dbo.COMPROBANTE_COBRO cc
        WHERE  cc.IdComprobanteCobro = @IdCompCobro;

        IF @IdTiendaCC IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Comprobante de cobro no encontrado.';
            ROLLBACK; RETURN;
        END

        IF @EstadoCC <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Este comprobante ya fue cobrado o no está en estado Pendiente.';
            ROLLBACK; RETURN;
        END

        -- ── Segregación: el usuario debe pertenecer a la misma tienda ─
        DECLARE @IdTiendaUsuario INT;
        SELECT @IdTiendaUsuario = IdTienda
        FROM   dbo.USUARIO
        WHERE  IdUsuario = @IdUsuario;

        -- SuperAdmin (IdTienda NULL o 0) puede cobrar en cualquier tienda
        IF @IdTiendaUsuario IS NOT NULL AND @IdTiendaUsuario <> 0
           AND @IdTiendaUsuario <> @IdTiendaCC
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No puede cobrar facturas de otra sucursal.';
            ROLLBACK; RETURN;
        END

        -- ── Validar monto recibido ────────────────────────────────────
        IF @MontoRecibido < @MontoTotal
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El monto recibido (Gs. ' + FORMAT(@MontoRecibido,'N0') +
                             ') es menor al total de la factura (Gs. ' + FORMAT(@MontoTotal,'N0') + ').';
            ROLLBACK; RETURN;
        END

        DECLARE @MontoCambio DECIMAL(18,2) = @MontoRecibido - @MontoTotal;

        -- ── Si hay caja, verificar que pertenece a la misma tienda ────
        IF @IdCaja > 0
        BEGIN
            DECLARE @IdTiendaCaja INT, @EstadoCaja VARCHAR(20);
            SELECT @IdTiendaCaja = IdTienda, @EstadoCaja = Estado
            FROM   dbo.CAJA
            WHERE  IdCaja = @IdCaja;

            IF @IdTiendaCaja IS NULL
            BEGIN
                SET @Resultado = 0;
                SET @Mensaje   = 'La caja indicada no existe.';
                ROLLBACK; RETURN;
            END

            IF @EstadoCaja <> 'Abierta'
            BEGIN
                SET @Resultado = 0;
                SET @Mensaje   = 'La caja no está abierta. No se puede registrar el cobro.';
                ROLLBACK; RETURN;
            END

            IF @IdTiendaCaja <> @IdTiendaCC
            BEGIN
                SET @Resultado = 0;
                SET @Mensaje   = 'La caja abierta no corresponde a la tienda de esta factura.';
                ROLLBACK; RETURN;
            END
        END

        -- ── Actualizar COMPROBANTE_COBRO ──────────────────────────────
        UPDATE dbo.COMPROBANTE_COBRO
        SET    Estado        = 'Cobrado',
               MontoRecibido = @MontoRecibido,
               MontoCambio   = @MontoCambio,
               IdFormaCobro  = @IdFormaCobro,
               IdUsuario     = @IdUsuario
        WHERE  IdComprobanteCobro = @IdCompCobro;

        -- ── Insertar COBRO_CXC ────────────────────────────────────────
        INSERT INTO dbo.COBRO_CXC
            (IdCompCobro, IdCaja, IdTienda, IdUsuario, IdFormaCobro,
             MontoRecibido, MontoCambio, FechaCobro, Observacion)
        VALUES
            (@IdCompCobro,
             CASE WHEN @IdCaja > 0 THEN @IdCaja ELSE NULL END,
             @IdTiendaCC, @IdUsuario, @IdFormaCobro,
             @MontoRecibido, @MontoCambio, GETDATE(), @Observacion);

        SET @Resultado = 1;
        SET @Mensaje   = 'Cobro registrado correctamente. Cambio: Gs. ' + FORMAT(@MontoCambio, 'N0') + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_CobrarCuentaPendiente creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. SP: usp_ObtenerCobrosCXC_Caja
--    Lista los cobros de crédito registrados durante una sesión de caja.
--    Usado en el arqueo y en el resumen de operaciones.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCobrosCXC_Caja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cx.IdCobroCXC,
        cx.FechaCobro,
        cc.NumeroCobro,
        v.NumeroFactura,
        c.Nombre   AS NombreCliente,
        c.NumeroDocumento,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion,'Efectivo')) AS FormaCobro,
        cx.MontoRecibido,
        cx.MontoCambio,
        cc.MontoTotal AS MontoFactura,
        u.Nombres + ' ' + u.Apellidos AS NombreCobrador
    FROM   dbo.COBRO_CXC          cx
    INNER  JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdComprobanteCobro = cx.IdCompCobro
    INNER  JOIN dbo.VENTA             v  ON v.IdVenta             = cc.IdVenta
    INNER  JOIN dbo.CLIENTE           c  ON c.IdCliente           = v.IdCliente
    INNER  JOIN dbo.USUARIO           u  ON u.IdUsuario           = cx.IdUsuario
    LEFT   JOIN dbo.FORMA_COBRO       fc ON fc.IdFormaCobro       = cx.IdFormaCobro
    WHERE  cx.IdCaja = @IdCaja
    ORDER  BY cx.FechaCobro;
END
GO
PRINT 'OK: usp_ObtenerCobrosCXC_Caja creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 5. FIX: usp_CerrarCaja
--    ANTES: MontoSistema = SUM de TODAS las ventas activas (incluía crédito → error)
--    AHORA: MontoSistema = ventas Contado cobradas + cobros de crédito recibidos en esta caja
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_CerrarCaja
    @IdCaja         INT,
    @IdUsuario      INT,
    @MontoContado   DECIMAL(18,2),
    @Observacion    VARCHAR(500),
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda      INT,
                @FechaApertura DATETIME,
                @Estado        VARCHAR(20);

        SELECT @IdTienda      = IdTienda,
               @FechaApertura = FechaApertura,
               @Estado        = Estado
        FROM   dbo.CAJA
        WHERE  IdCaja = @IdCaja;

        IF @Estado IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Caja no encontrada.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Abierta'
        BEGIN SET @Resultado = 0; SET @Mensaje = 'La caja ya fue cerrada.'; ROLLBACK; RETURN; END

        -- ── MontoSistema = ventas CONTADO del período + cobros CXC de esta caja ──
        DECLARE @TotalContado  DECIMAL(18,2),
                @TotalCobrosCXC DECIMAL(18,2);

        -- Ventas contado cobradas en este turno
        SELECT @TotalContado = ISNULL(SUM(v.TotalCosto), 0)
        FROM   dbo.VENTA v
        INNER  JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
        WHERE  v.IdTienda        = @IdTienda
          AND  v.FechaRegistro  >= @FechaApertura
          AND  v.FechaRegistro  <= GETDATE()
          AND  v.Estado          = 'Activa'
          AND  ISNULL(v.Condicion, 'Contado') = 'Contado';

        -- Cobros de crédito recibidos durante este turno de caja
        SELECT @TotalCobrosCXC = ISNULL(SUM(cx.MontoRecibido - cx.MontoCambio), 0)
        FROM   dbo.COBRO_CXC cx
        WHERE  cx.IdCaja = @IdCaja;

        DECLARE @MontoSistema DECIMAL(18,2) = @TotalContado + @TotalCobrosCXC;

        UPDATE dbo.CAJA
           SET FechaCierre     = GETDATE(),
               IdUsuarioCierre = @IdUsuario,
               MontoSistema    = @MontoSistema,
               MontoContado    = @MontoContado,
               Diferencia      = @MontoContado - @MontoSistema,
               Estado          = 'Cerrada',
               Observacion     = @Observacion
         WHERE IdCaja = @IdCaja;

        SET @Resultado = 1;
        SET @Mensaje   = 'Caja cerrada. '
                       + 'Ventas contado: Gs. ' + FORMAT(@TotalContado,  'N0')
                       + ' | Cobros crédito: Gs. ' + FORMAT(@TotalCobrosCXC, 'N0')
                       + ' | Total sistema: Gs. ' + FORMAT(@MontoSistema, 'N0')
                       + ' | Contado físico: Gs. ' + FORMAT(@MontoContado, 'N0')
                       + ' | Diferencia: Gs. ' + FORMAT(@MontoContado - @MontoSistema, 'N0') + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_CerrarCaja corregido (excluye crédito, suma cobros CXC).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 6. FIX: usp_ObtenerCajaActiva
--    Agrega columnas separadas: TotalVentasContado, TotalVentasCredito, TotalCobrosCXC
--    para que el panel de caja muestre el detalle correcto.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IdCaja,
        c.IdTienda,
        t.Nombre                      AS NombreTienda,
        c.IdUsuario,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        c.FechaApertura,
        c.MontoApertura,
        c.Estado,
        -- Total ventas del turno (todas)
        ISNULL(vt.CantidadVentas, 0)  AS CantidadVentas,
        ISNULL(vt.TotalVentas,    0)  AS TotalVentas,
        -- Ventas SOLO contado (dinero real ingresado)
        ISNULL(vt.TotalContado,   0)  AS TotalVentasContado,
        ISNULL(vt.CantContado,    0)  AS CantVentasContado,
        -- Ventas crédito (vendidas pero aún no cobradas)
        ISNULL(vt.TotalCredito,   0)  AS TotalVentasCredito,
        ISNULL(vt.CantCredito,    0)  AS CantVentasCredito,
        -- Cobros de crédito recibidos en este turno (dinero real ingresado)
        ISNULL(cx.TotalCobrosCXC, 0)  AS TotalCobrosCXC,
        ISNULL(cx.CantCobrosCXC,  0)  AS CantCobrosCXC
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    -- Subquery ventas del turno
    OUTER APPLY (
        SELECT
            COUNT(v.IdVenta)                                        AS CantidadVentas,
            ISNULL(SUM(v.TotalCosto), 0)                            AS TotalVentas,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN v.TotalCosto ELSE 0 END), 0) AS TotalContado,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN 1 END)                          AS CantContado,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN v.TotalCosto ELSE 0 END), 0) AS TotalCredito,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN 1 END)                          AS CantCredito
        FROM dbo.VENTA v
        WHERE v.IdTienda       = c.IdTienda
          AND v.FechaRegistro >= c.FechaApertura
          AND v.Estado         = 'Activa'
    ) vt
    -- Subquery cobros CXC del turno
    OUTER APPLY (
        SELECT
            ISNULL(SUM(cx.MontoRecibido - cx.MontoCambio), 0) AS TotalCobrosCXC,
            COUNT(cx.IdCobroCXC)                               AS CantCobrosCXC
        FROM dbo.COBRO_CXC cx
        WHERE cx.IdCaja = c.IdCaja
    ) cx
    WHERE c.IdTienda = @IdTienda
      AND c.Estado   = 'Abierta';
END
GO
PRINT 'OK: usp_ObtenerCajaActiva actualizado (contado / crédito / cobros CXC separados).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 7. FIX: usp_ObtenerOperacionesCaja
--    RS1: agrega columna Condicion a cada venta
--    RS2: resumen solo de ventas CONTADO por forma de cobro
--    RS3 NUEVO: cobros de crédito recibidos en esta sesión (de COBRO_CXC)
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerOperacionesCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda      INT,
            @FechaApertura DATETIME,
            @FechaCierre   DATETIME;

    SELECT @IdTienda      = IdTienda,
           @FechaApertura = FechaApertura,
           @FechaCierre   = ISNULL(FechaCierre, GETDATE())
    FROM   dbo.CAJA
    WHERE  IdCaja = @IdCaja;

    -- ── RS1: Detalle ventas (con Condicion) ──────────────────────────────
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        v.FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')                     AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        v.TotalCosto                                             AS Monto,
        ISNULL(cc.MontoRecibido, 0)                              AS MontoRecibido,
        ISNULL(cc.MontoCambio, 0)                                AS MontoCambio,
        u.Nombres + ' ' + u.Apellidos                            AS NombreCajero,
        v.Estado,
        ISNULL(v.Condicion, 'Contado')                           AS Condicion
    FROM   dbo.VENTA            v
    INNER  JOIN dbo.USUARIO     u  ON u.IdUsuario    = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE     c  ON c.IdCliente    = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- ── RS2: Resumen ventas CONTADO por forma de cobro (dinero real) ─────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        COUNT(v.IdVenta)                                         AS Cantidad,
        SUM(v.TotalCosto)                                        AS TotalMonto
    FROM   dbo.VENTA            v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado         = 'Activa'
      AND  ISNULL(v.Condicion, 'Contado') = 'Contado'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;

    -- ── RS3 NUEVO: Cobros de crédito recibidos en esta sesión ────────────
    SELECT
        cx.IdCobroCXC,
        cx.FechaCobro,
        cc.NumeroCobro,
        v.NumeroFactura,
        c.Nombre   AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion,'Efectivo'))     AS FormaCobro,
        cc.MontoTotal  AS MontoFactura,
        cx.MontoRecibido,
        cx.MontoCambio,
        u.Nombres + ' ' + u.Apellidos AS NombreCobrador
    FROM   dbo.COBRO_CXC          cx
    INNER  JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdComprobanteCobro = cx.IdCompCobro
    INNER  JOIN dbo.VENTA             v  ON v.IdVenta             = cc.IdVenta
    INNER  JOIN dbo.CLIENTE           c  ON c.IdCliente           = v.IdCliente
    INNER  JOIN dbo.USUARIO           u  ON u.IdUsuario           = cx.IdUsuario
    LEFT   JOIN dbo.FORMA_COBRO       fc ON fc.IdFormaCobro       = cx.IdFormaCobro
    WHERE  cx.IdCaja = @IdCaja
    ORDER  BY cx.FechaCobro;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja actualizado (Condicion + RS3 cobros CXC).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 8. FIX: usp_ObtenerListaComprobanteCobro (ya existente)
--    Agrega columnas Condicion, FechaVencimiento, DiasParaVencer para la vista
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerListaComprobanteCobro
    @IdTienda    INT,
    @FechaInicio DATE,
    @FechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cc.IdComprobanteCobro,
        cc.NumeroCobro,
        v.NumeroFactura,
        v.Codigo      AS CodigoVenta,
        cc.Estado,
        cc.MontoTotal,
        cc.MontoRecibido,
        cc.MontoCambio,
        FORMAT(cc.FechaRegistro, 'dd/MM/yyyy HH:mm') AS FechaRegistro,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        c.Nombre          AS NombreCliente,
        c.NumeroDocumento AS NumeroDocumento,
        u.Nombres + ' ' + u.Apellidos AS NombreCajero,
        t.Nombre          AS NombreTienda,
        ISNULL(v.Condicion, 'Contado') AS Condicion,
        CONVERT(VARCHAR(10), v.FechaVencimientoCredito, 103) AS FechaVencimiento,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), v.FechaVencimientoCredito) AS DiasParaVencer
    FROM   dbo.COMPROBANTE_COBRO cc
    INNER  JOIN dbo.VENTA       v  ON v.IdVenta        = cc.IdVenta
    INNER  JOIN dbo.TIENDA      t  ON t.IdTienda        = cc.IdTienda
    INNER  JOIN dbo.USUARIO     u  ON u.IdUsuario       = cc.IdUsuario
    INNER  JOIN dbo.CLIENTE     c  ON c.IdCliente       = v.IdCliente
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro   = cc.IdFormaCobro
    WHERE  (@IdTienda = 0 OR cc.IdTienda = @IdTienda)
      AND  CAST(cc.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER  BY cc.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerListaComprobanteCobro actualizado (Condicion + FechaVencimiento).';
GO

PRINT '════ Script 82 completado ════';
GO
