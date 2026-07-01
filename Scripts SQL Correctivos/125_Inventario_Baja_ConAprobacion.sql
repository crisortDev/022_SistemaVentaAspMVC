-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 125: Inventario — Baja de stock CON aprobación (Etapa 1)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
--
-- HOY: la baja descuenta el stock directo (sin control).
-- OBJETIVO: la baja queda 'Pendiente' (NO descuenta) y un Encargado/Admin/SuperAdmin
--           la APRUEBA (recién ahí descuenta) o la RECHAZA (no toca stock).
--
-- Usa la tabla existente HISTORIAL_MOVIMIENTO como registro de bajas, agregándole
-- columnas de flujo de aprobación (idempotente).
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Columnas de flujo de aprobación en HISTORIAL_MOVIMIENTO ──────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='EstadoAprobacion')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD EstadoAprobacion VARCHAR(20) NOT NULL DEFAULT 'Pendiente';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='IdTienda')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD IdTienda INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='IdUsuarioRegistro')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD IdUsuarioRegistro INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='IdUsuarioAprueba')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD IdUsuarioAprueba INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='FechaAprobacion')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD FechaAprobacion DATETIME NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.HISTORIAL_MOVIMIENTO') AND name='MotivoRechazo')
    ALTER TABLE dbo.HISTORIAL_MOVIMIENTO ADD MotivoRechazo VARCHAR(255) NULL;
GO
PRINT 'OK: columnas de aprobación aseguradas en HISTORIAL_MOVIMIENTO.';
GO

-- ─── 2. usp_RegistrarBajaPendiente — registra la baja SIN descontar ─────────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarBajaPendiente
    @IdProductoTienda  INT,
    @IdProducto        INT,
    @Cantidad          INT,
    @IdMotivoBaja      INT,
    @Observaciones     VARCHAR(255),
    @IdUsuarioRegistro INT,
    @Resultado         BIT           OUTPUT,
    @Mensaje           NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @StockActual BIGINT, @IdTienda INT;
        SELECT @StockActual = Stock, @IdTienda = IdTienda
        FROM dbo.PRODUCTO_TIENDA WHERE IdProductoTienda = @IdProductoTienda;

        IF @StockActual IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Producto no encontrado en la tienda.'; RETURN; END

        IF @Cantidad <= 0
        BEGIN SET @Resultado=0; SET @Mensaje='La cantidad debe ser mayor a cero.'; RETURN; END

        IF @Cantidad > @StockActual
        BEGIN SET @Resultado=0; SET @Mensaje='No puede dar de baja más que el stock disponible ('+CAST(@StockActual AS VARCHAR)+').'; RETURN; END

        -- Registrar la solicitud de baja en estado Pendiente (NO descuenta aún)
        INSERT INTO dbo.HISTORIAL_MOVIMIENTO
            (IdProductoDeposito, Estado, Cantidad, FechaMovimiento, Observaciones,
             idProducto, IdMotivoBaja, EstadoAprobacion, IdTienda, IdUsuarioRegistro)
        VALUES
            (@IdProductoTienda, 'Baja', @Cantidad, GETDATE(), @Observaciones,
             @IdProducto, @IdMotivoBaja, 'Pendiente', @IdTienda, @IdUsuarioRegistro);

        SET @Resultado = 1;
        SET @Mensaje   = 'Solicitud de baja registrada. Queda PENDIENTE de aprobación.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0; SET @Mensaje = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarBajaPendiente creado.';
GO

-- ─── 3. usp_AprobarBaja — aprueba y RECIÉN AHÍ descuenta el stock ────────────────
CREATE OR ALTER PROCEDURE dbo.usp_AprobarBaja
    @IdHistorial      INT,
    @IdUsuarioAprueba INT,
    @EsSuperAdmin     BIT = 0,
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Estado VARCHAR(20), @Cantidad INT, @IdPT INT, @IdUsuarioReg INT, @Stock BIGINT;
        SELECT @Estado = EstadoAprobacion, @Cantidad = Cantidad,
               @IdPT = IdProductoDeposito, @IdUsuarioReg = IdUsuarioRegistro
        FROM dbo.HISTORIAL_MOVIMIENTO WHERE IdHistorial = @IdHistorial;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Solicitud de baja no encontrada.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden aprobar bajas en estado Pendiente. Estado actual: '+@Estado; ROLLBACK; RETURN; END

        -- Segregación: quien registró no puede aprobar (salvo SuperAdmin)
        IF @EsSuperAdmin = 0 AND @IdUsuarioReg = @IdUsuarioAprueba
        BEGIN SET @Resultado=0; SET @Mensaje='El usuario que registró la baja no puede aprobarla (segregación de funciones).'; ROLLBACK; RETURN; END

        -- Revalidar stock al momento de aprobar
        SELECT @Stock = Stock FROM dbo.PRODUCTO_TIENDA WHERE IdProductoTienda = @IdPT;
        IF @Cantidad > @Stock
        BEGIN SET @Resultado=0; SET @Mensaje='Stock insuficiente al aprobar (disponible: '+CAST(@Stock AS VARCHAR)+').'; ROLLBACK; RETURN; END

        -- Descontar stock
        UPDATE dbo.PRODUCTO_TIENDA SET Stock = Stock - @Cantidad WHERE IdProductoTienda = @IdPT;

        -- Marcar aprobada
        UPDATE dbo.HISTORIAL_MOVIMIENTO
           SET EstadoAprobacion = 'Aprobada',
               IdUsuarioAprueba = @IdUsuarioAprueba,
               FechaAprobacion  = GETDATE()
         WHERE IdHistorial = @IdHistorial;

        SET @Resultado = 1;
        SET @Mensaje   = 'Baja aprobada. Stock descontado.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AprobarBaja creado.';
GO

-- ─── 4. usp_RechazarBaja — rechaza sin tocar stock ──────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RechazarBaja
    @IdHistorial      INT,
    @IdUsuarioAprueba INT,
    @MotivoRechazo    VARCHAR(255),
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Estado VARCHAR(20);
        SELECT @Estado = EstadoAprobacion FROM dbo.HISTORIAL_MOVIMIENTO WHERE IdHistorial = @IdHistorial;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Solicitud de baja no encontrada.'; RETURN; END
        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden rechazar bajas Pendientes.'; RETURN; END

        UPDATE dbo.HISTORIAL_MOVIMIENTO
           SET EstadoAprobacion = 'Rechazada',
               IdUsuarioAprueba = @IdUsuarioAprueba,
               FechaAprobacion  = GETDATE(),
               MotivoRechazo    = @MotivoRechazo
         WHERE IdHistorial = @IdHistorial;

        SET @Resultado = 1; SET @Mensaje = 'Baja rechazada. El stock no fue modificado.';
    END TRY
    BEGIN CATCH
        SET @Resultado=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RechazarBaja creado.';
GO

-- ─── 5. usp_ObtenerBajas — lista las bajas filtrando por estado/tienda ──────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerBajas
    @IdTienda        INT = 0,
    @EstadoAprobacion VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.IdHistorial,
        h.idProducto                                   AS IdProducto,
        p.Codigo                                       AS CodigoProducto,
        p.Nombre                                       AS NombreProducto,
        h.Cantidad,
        ISNULL(mb.Descripcion, '')                     AS MotivoBaja,
        ISNULL(h.Observaciones, '')                    AS Observaciones,
        h.EstadoAprobacion,
        t.Nombre                                       AS NombreTienda,
        h.IdTienda,
        CONVERT(VARCHAR(19), h.FechaMovimiento, 120)   AS FechaMovimiento,
        ISNULL(ur.Nombres + ' ' + ur.Apellidos, '')    AS UsuarioRegistro,
        ISNULL(ua.Nombres + ' ' + ua.Apellidos, '')    AS UsuarioAprueba,
        CONVERT(VARCHAR(19), h.FechaAprobacion, 120)   AS FechaAprobacion,
        ISNULL(h.MotivoRechazo, '')                    AS MotivoRechazo
    FROM dbo.HISTORIAL_MOVIMIENTO h
    LEFT JOIN dbo.PRODUCTO   p  ON p.IdProducto   = h.idProducto
    LEFT JOIN dbo.MotivoBaja mb ON mb.IdMotivoBaja = h.IdMotivoBaja
    LEFT JOIN dbo.TIENDA     t  ON t.IdTienda     = h.IdTienda
    LEFT JOIN dbo.USUARIO    ur ON ur.IdUsuario   = h.IdUsuarioRegistro
    LEFT JOIN dbo.USUARIO    ua ON ua.IdUsuario   = h.IdUsuarioAprueba
    WHERE h.Estado = 'Baja'
      AND (@IdTienda = 0 OR h.IdTienda = @IdTienda)
      AND (@EstadoAprobacion = '' OR h.EstadoAprobacion = @EstadoAprobacion)
    ORDER BY
        CASE WHEN h.EstadoAprobacion = 'Pendiente' THEN 0 ELSE 1 END,
        h.FechaMovimiento DESC;
END
GO
PRINT 'OK: usp_ObtenerBajas creado.';
GO

PRINT '════ Script 125 (Inventario Baja con aprobación) completado ════';
GO
