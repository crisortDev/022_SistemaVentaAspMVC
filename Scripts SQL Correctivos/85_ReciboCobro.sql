-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 85: Recibo de Cobro imprimible
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- 1. Agrega @IdCompCobro OUTPUT a usp_CobrarCuentaPendiente
--    (para que el controller pueda abrir el recibo en nueva pestaña)
-- 2. Crea usp_ObtenerReciboCobro
--    (devuelve todos los datos necesarios para imprimir el recibo)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. MODIFICAR usp_CobrarCuentaPendiente → agregar @IdCompCobro OUTPUT
--    El SP ya existía; se reescribe con CREATE OR ALTER.
--    Único cambio: se agrega el parámetro OUTPUT @IdCompCobro.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_CobrarCuentaPendiente
    @IdCompCobro    INT,
    @IdCaja         INT,
    @IdUsuario      INT,
    @IdFormaCobro   INT,
    @MontoRecibido  DECIMAL(18,2),
    @Observacion    VARCHAR(500)   = NULL,
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(400) OUTPUT,
    @IdCompCobroOut INT           OUTPUT   -- ← NUEVO: devuelve el mismo IdCompCobro para imprimir
AS
BEGIN
    SET NOCOUNT ON;
    SET @IdCompCobroOut = 0;

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
            SET @Resultado      = 0;
            SET @Mensaje        = 'Comprobante de cobro no encontrado.';
            SET @IdCompCobroOut = 0;
            ROLLBACK; RETURN;
        END

        IF @EstadoCC <> 'Pendiente'
        BEGIN
            SET @Resultado      = 0;
            SET @Mensaje        = 'Este comprobante ya fue cobrado o no está en estado Pendiente.';
            SET @IdCompCobroOut = 0;
            ROLLBACK; RETURN;
        END

        -- ── Segregación: el usuario debe pertenecer a la misma tienda ─
        DECLARE @IdTiendaUsuario INT;
        SELECT @IdTiendaUsuario = IdTienda
        FROM   dbo.USUARIO
        WHERE  IdUsuario = @IdUsuario;

        IF @IdTiendaUsuario IS NOT NULL AND @IdTiendaUsuario <> 0
           AND @IdTiendaUsuario <> @IdTiendaCC
        BEGIN
            SET @Resultado      = 0;
            SET @Mensaje        = 'No puede cobrar facturas de otra sucursal.';
            SET @IdCompCobroOut = 0;
            ROLLBACK; RETURN;
        END

        -- ── Validar monto recibido ────────────────────────────────────
        IF @MontoRecibido < @MontoTotal
        BEGIN
            SET @Resultado      = 0;
            SET @Mensaje        = 'El monto recibido (Gs. ' + FORMAT(@MontoRecibido,'N0') +
                                  ') es menor al total de la factura (Gs. ' + FORMAT(@MontoTotal,'N0') + ').';
            SET @IdCompCobroOut = 0;
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
                SET @Resultado      = 0;
                SET @Mensaje        = 'La caja indicada no existe.';
                SET @IdCompCobroOut = 0;
                ROLLBACK; RETURN;
            END

            IF @EstadoCaja <> 'Abierta'
            BEGIN
                SET @Resultado      = 0;
                SET @Mensaje        = 'La caja no está abierta. No se puede registrar el cobro.';
                SET @IdCompCobroOut = 0;
                ROLLBACK; RETURN;
            END

            IF @IdTiendaCaja <> @IdTiendaCC
            BEGIN
                SET @Resultado      = 0;
                SET @Mensaje        = 'La caja abierta no corresponde a la tienda de esta factura.';
                SET @IdCompCobroOut = 0;
                ROLLBACK; RETURN;
            END
        END

        -- ── Actualizar COMPROBANTE_COBRO ──────────────────────────────
        UPDATE dbo.COMPROBANTE_COBRO
        SET    Estado         = 'Cobrado',
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

        -- ── Retornar IdCompCobro para abrir el recibo ─────────────────
        SET @IdCompCobroOut = @IdCompCobro;
        SET @Resultado      = 1;
        SET @Mensaje        = 'Cobro registrado correctamente. Cambio: Gs. ' + FORMAT(@MontoCambio, 'N0') + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado      = 0;
        SET @Mensaje        = 'Error: ' + ERROR_MESSAGE();
        SET @IdCompCobroOut = 0;
    END CATCH
END
GO
PRINT 'OK: usp_CobrarCuentaPendiente actualizado (agrega @IdCompCobroOut).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. SP: usp_ObtenerReciboCobro
--    Retorna todos los datos necesarios para imprimir el recibo de un cobro.
--    Funciona para cobros al contado Y cobros de crédito (CXC).
--
--    Lógica:
--      - Contado: COMPROBANTE_COBRO tiene todo; COBRO_CXC no existe → muestra datos CC.
--      - Crédito cobrado: une con COBRO_CXC para FechaCobro, FormaCobro real, Cobrador.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerReciboCobro
    @IdCompCobro INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        -- Identificación
        cc.IdComprobanteCobro,
        cc.NumeroCobro,
        v.NumeroFactura,
        ISNULL(v.Condicion, 'Contado')                          AS Condicion,

        -- Cliente
        c.Nombre                                                AS NombreCliente,
        c.NumeroDocumento,
        ISNULL(c.Telefono, '')                                  AS TelefonoCliente,
        ISNULL(c.Direccion,'')                                  AS DireccionCliente,

        -- Montos
        cc.MontoTotal,

        -- Para contado: usa los valores de CC.
        -- Para crédito: usa los de COBRO_CXC (son el cobro real posterior).
        ISNULL(cx.MontoRecibido, cc.MontoRecibido)              AS MontoRecibido,
        ISNULL(cx.MontoCambio,   cc.MontoCambio)                AS MontoCambio,

        -- Forma de cobro: la del cobro CXC si existe, sino la original de la venta
        ISNULL(fcCX.Nombre, fcCC.Nombre)                        AS FormaCobro,

        -- Fechas
        FORMAT(cc.FechaRegistro,  'dd/MM/yyyy HH:mm')           AS FechaEmision,
        FORMAT(ISNULL(cx.FechaCobro, cc.FechaRegistro), 'dd/MM/yyyy HH:mm') AS FechaCobro,

        -- Plazo crédito
        v.PlazoCredito,
        CONVERT(VARCHAR(10), v.FechaVencimientoCredito, 103)    AS FechaVencimiento,

        -- Usuario que cobró
        -- Para crédito: el usuario del COBRO_CXC; para contado: el cajero del CC
        ISNULL(uCX.Nombres + ' ' + uCX.Apellidos,
               uCC.Nombres + ' ' + uCC.Apellidos)               AS NombreCobrador,

        -- Observación del cobro (solo CXC)
        ISNULL(cx.Observacion, '')                              AS Observacion,

        -- Tienda
        t.Nombre                                                AS NombreTienda,
        ISNULL(t.Direccion, '')                                 AS DireccionTienda,
        ISNULL(t.Telefono,  '')                                 AS TelefonoTienda

    FROM dbo.COMPROBANTE_COBRO cc
    INNER JOIN dbo.VENTA          v    ON v.IdVenta       = cc.IdVenta
    INNER JOIN dbo.CLIENTE        c    ON c.IdCliente     = v.IdCliente
    INNER JOIN dbo.TIENDA         t    ON t.IdTienda      = cc.IdTienda
    INNER JOIN dbo.USUARIO        uCC  ON uCC.IdUsuario   = cc.IdUsuario
    LEFT  JOIN dbo.FORMA_COBRO    fcCC ON fcCC.IdFormaCobro = cc.IdFormaCobro
    -- Cobro CXC (solo existe si fue crédito y ya se cobró)
    LEFT  JOIN dbo.COBRO_CXC      cx   ON cx.IdCompCobro  = cc.IdComprobanteCobro
    LEFT  JOIN dbo.FORMA_COBRO    fcCX ON fcCX.IdFormaCobro = cx.IdFormaCobro
    LEFT  JOIN dbo.USUARIO        uCX  ON uCX.IdUsuario   = cx.IdUsuario
    WHERE cc.IdComprobanteCobro = @IdCompCobro;
END
GO
PRINT 'OK: usp_ObtenerReciboCobro creado.';
GO

-- ── Verificación ──────────────────────────────────────────────────────────────
PRINT '════ Script 85 completado ════';
GO
