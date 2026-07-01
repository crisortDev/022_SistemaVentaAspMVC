-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 54: Módulo Caja Venta — Tabla CAJA + Stored Procedures
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
--
-- MÓDULO: Apertura, operaciones y cierre de caja para el cajero.
-- TABLAS NUEVAS: CAJA
-- TABLAS EXISTENTES USADAS: VENTA, MOVIMIENTOS, USUARIO, TIENDA
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: CAJA
--   Registra cada sesión de trabajo del cajero (apertura → cierre).
--   Una tienda solo puede tener una caja ABIERTA a la vez.
-- ════════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.CAJA') AND type = 'U')
BEGIN
    CREATE TABLE dbo.CAJA (
        IdCaja          INT           IDENTITY(1,1) NOT NULL,
        IdTienda        INT           NOT NULL,
        IdUsuario       INT           NOT NULL,          -- quien abrió la caja
        FechaApertura   DATETIME      NOT NULL DEFAULT GETDATE(),
        MontoApertura   DECIMAL(18,2) NOT NULL DEFAULT 0, -- efectivo inicial declarado
        FechaCierre     DATETIME      NULL,
        IdUsuarioCierre INT           NULL,              -- quien cerró
        MontoSistema    DECIMAL(18,2) NULL,              -- total calculado por el sistema
        MontoContado    DECIMAL(18,2) NULL,              -- efectivo contado físicamente
        Diferencia      DECIMAL(18,2) NULL,              -- MontoContado - MontoSistema
        Estado          VARCHAR(20)   NOT NULL DEFAULT 'Abierta',  -- Abierta / Cerrada
        Observacion     VARCHAR(500)  NULL,

        CONSTRAINT PK_CAJA PRIMARY KEY (IdCaja),
        CONSTRAINT FK_CAJA_Tienda   FOREIGN KEY (IdTienda)        REFERENCES dbo.TIENDA(IdTienda),
        CONSTRAINT FK_CAJA_Usuario  FOREIGN KEY (IdUsuario)       REFERENCES dbo.USUARIO(IdUsuario),
        CONSTRAINT FK_CAJA_UCierre  FOREIGN KEY (IdUsuarioCierre) REFERENCES dbo.USUARIO(IdUsuario)
    );
    PRINT 'OK: Tabla CAJA creada.';
END
ELSE
    PRINT 'INFO: Tabla CAJA ya existía.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- SP 1: usp_AbrirCaja
--   Abre una nueva sesión de caja para una tienda.
--   Solo permite una caja abierta por tienda a la vez.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_AbrirCaja
    @IdTienda       INT,
    @IdUsuario      INT,
    @MontoApertura  DECIMAL(18,2),
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT,
    @IdCaja         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Verificar que no haya una caja abierta en esta tienda
        IF EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdTienda = @IdTienda AND Estado = 'Abierta')
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Ya existe una caja abierta para esta tienda. Debe cerrarla primero.';
            SET @IdCaja    = 0;
            ROLLBACK; RETURN;
        END

        IF @MontoApertura < 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El monto de apertura no puede ser negativo.';
            SET @IdCaja    = 0;
            ROLLBACK; RETURN;
        END

        INSERT INTO dbo.CAJA (IdTienda, IdUsuario, MontoApertura, Estado)
        VALUES (@IdTienda, @IdUsuario, @MontoApertura, 'Abierta');

        SET @IdCaja    = SCOPE_IDENTITY();
        SET @Resultado = 1;
        SET @Mensaje   = 'Caja abierta correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @IdCaja = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AbrirCaja creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- SP 2: usp_ObtenerCajaActiva
--   Devuelve la caja abierta de una tienda (si existe).
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.IdCaja,
        c.IdTienda,
        t.Nombre           AS NombreTienda,
        c.IdUsuario,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        c.FechaApertura,
        c.MontoApertura,
        c.Estado,
        -- Ventas registradas desde la apertura
        ISNULL(SUM(v.TotalCosto), 0)   AS TotalVentas,
        COUNT(v.IdVenta)               AS CantidadVentas
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    LEFT  JOIN dbo.VENTA   v ON v.IdTienda  = c.IdTienda
                             AND v.FechaRegistro >= c.FechaApertura
                             AND v.Estado = 'Activa'
    WHERE c.IdTienda = @IdTienda
      AND c.Estado   = 'Abierta'
    GROUP BY c.IdCaja, c.IdTienda, t.Nombre, c.IdUsuario,
             u.Nombres, u.Apellidos, c.FechaApertura, c.MontoApertura, c.Estado;
END
GO
PRINT 'OK: usp_ObtenerCajaActiva creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- SP 3: usp_ObtenerOperacionesCaja
--   Lista todas las ventas registradas durante una sesión de caja.
--   Muestra cada venta como una operación con su monto y forma de cobro.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerOperacionesCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda      INT;
    DECLARE @FechaApertura DATETIME;
    DECLARE @FechaCierre   DATETIME;

    SELECT @IdTienda      = IdTienda,
           @FechaApertura = FechaApertura,
           @FechaCierre   = ISNULL(FechaCierre, GETDATE())
    FROM   dbo.CAJA
    WHERE  IdCaja = @IdCaja;

    -- RS1: Detalle operación por operación
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        v.FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')  AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        v.TotalCosto                          AS Monto,
        cc.MontoRecibido,
        cc.MontoCambio,
        u.Nombres + ' ' + u.Apellidos         AS NombreCajero,
        v.Estado
    FROM   dbo.VENTA            v
    INNER  JOIN dbo.USUARIO     u  ON u.IdUsuario  = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE     c  ON c.IdCliente  = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta  = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- RS2: Resumen por forma de cobro
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        COUNT(v.IdVenta)       AS Cantidad,
        SUM(v.TotalCosto)      AS TotalMonto
    FROM   dbo.VENTA            v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado = 'Activa'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- SP 4: usp_CerrarCaja
--   Cierra la sesión de caja, calcula el total del sistema y registra
--   el monto contado físicamente y la diferencia.
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

        DECLARE @IdTienda      INT;
        DECLARE @FechaApertura DATETIME;
        DECLARE @Estado        VARCHAR(20);

        SELECT @IdTienda      = IdTienda,
               @FechaApertura = FechaApertura,
               @Estado        = Estado
        FROM   dbo.CAJA
        WHERE  IdCaja = @IdCaja;

        IF @Estado IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Caja no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @Estado <> 'Abierta'
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'La caja ya fue cerrada.';
            ROLLBACK; RETURN;
        END

        -- Calcular total ventas activas del período
        DECLARE @MontoSistema DECIMAL(18,2);
        SELECT @MontoSistema = ISNULL(SUM(TotalCosto), 0)
        FROM   dbo.VENTA
        WHERE  IdTienda       = @IdTienda
          AND  FechaRegistro >= @FechaApertura
          AND  FechaRegistro <= GETDATE()
          AND  Estado = 'Activa';

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
        SET @Mensaje   = 'Caja cerrada. Total sistema: Gs. ' + FORMAT(@MontoSistema, 'N0')
                       + ' | Contado: Gs. ' + FORMAT(@MontoContado, 'N0')
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
PRINT 'OK: usp_CerrarCaja creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- SP 5: usp_ObtenerHistorialCaja
--   Lista el historial de cajas cerradas por tienda.
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerHistorialCaja
    @IdTienda INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.IdCaja,
        t.Nombre                                   AS NombreTienda,
        ua.Nombres + ' ' + ua.Apellidos            AS Aperturista,
        c.FechaApertura,
        c.MontoApertura,
        c.FechaCierre,
        ISNULL(uc.Nombres + ' ' + uc.Apellidos,'—') AS Cierre,
        c.MontoSistema,
        c.MontoContado,
        c.Diferencia,
        c.Estado,
        c.Observacion
    FROM   dbo.CAJA    c
    INNER  JOIN dbo.TIENDA  t  ON t.IdTienda  = c.IdTienda
    INNER  JOIN dbo.USUARIO ua ON ua.IdUsuario = c.IdUsuario
    LEFT   JOIN dbo.USUARIO uc ON uc.IdUsuario = c.IdUsuarioCierre
    WHERE  (@IdTienda = 0 OR c.IdTienda = @IdTienda)
    ORDER  BY c.FechaApertura DESC;
END
GO
PRINT 'OK: usp_ObtenerHistorialCaja creado.';
GO

PRINT '════ Script 54 completado ════';
GO
