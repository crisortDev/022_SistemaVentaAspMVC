-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 131: Traslado de stock CON aprobación
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-11
--
-- HOY: el traslado mueve el stock directamente (sin control).
-- OBJETIVO: el traslado queda 'Pendiente' (NO mueve stock) y el Encargado/Admin
--           de la sucursal DESTINO lo APRUEBA (recién ahí mueve el stock)
--           o lo RECHAZA (no toca stock).
--
-- Segregación:
--   - Quien registra el traslado no puede aprobarlo (salvo SuperAdmin).
--   - Solo puede aprobar el encargado de la sucursal DESTINO.
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Columnas de aprobación en TRASLADO ──────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TRASLADO') AND name='EstadoAprobacion')
    ALTER TABLE dbo.TRASLADO ADD EstadoAprobacion VARCHAR(20) NOT NULL DEFAULT 'Aprobado';
    -- DEFAULT 'Aprobado' para no romper registros históricos existentes
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TRASLADO') AND name='IdUsuarioAprueba')
    ALTER TABLE dbo.TRASLADO ADD IdUsuarioAprueba INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TRASLADO') AND name='FechaAprobacion')
    ALTER TABLE dbo.TRASLADO ADD FechaAprobacion DATETIME NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TRASLADO') AND name='MotivoRechazo')
    ALTER TABLE dbo.TRASLADO ADD MotivoRechazo VARCHAR(255) NULL;
GO
PRINT 'OK: columnas de aprobación aseguradas en TRASLADO.';
GO

-- ─── 2. usp_RegistrarTrasladoPendiente — registra SIN mover stock ────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarTrasladoPendiente
    @IdProducto        INT,
    @IdTiendaOrigen    INT,
    @IdTiendaDestino   INT,
    @Cantidad          INT,
    @Observaciones     VARCHAR(500),
    @IdUsuario         INT,
    @Resultado         BIT           OUTPUT,
    @Mensaje           NVARCHAR(300) OUTPUT,
    @IdTraslado        INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validaciones básicas
        IF @IdTiendaOrigen = @IdTiendaDestino
        BEGIN SET @Resultado=0; SET @Mensaje='La sucursal origen y destino no pueden ser la misma.'; SET @IdTraslado=0; RETURN; END

        IF @Cantidad <= 0
        BEGIN SET @Resultado=0; SET @Mensaje='La cantidad debe ser mayor a cero.'; SET @IdTraslado=0; RETURN; END

        DECLARE @StockOrigen BIGINT, @IdProductoTiendaOrigen INT;
        SELECT @StockOrigen = Stock, @IdProductoTiendaOrigen = IdProductoTienda
        FROM dbo.PRODUCTO_TIENDA
        WHERE IdProducto = @IdProducto AND IdTienda = @IdTiendaOrigen;

        IF @StockOrigen IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='El producto no existe en la sucursal origen.'; SET @IdTraslado=0; RETURN; END

        IF @Cantidad > @StockOrigen
        BEGIN SET @Resultado=0; SET @Mensaje='Stock insuficiente en origen (disponible: '+CAST(@StockOrigen AS VARCHAR)+').'; SET @IdTraslado=0; RETURN; END

        -- Registrar traslado en estado Pendiente (NO mueve stock todavía)
        INSERT INTO dbo.TRASLADO
            (IdProducto, IdTiendaOrigen, IdTiendaDestino, Cantidad,
             Observaciones, IdUsuario, FechaTraslado, EstadoAprobacion)
        VALUES
            (@IdProducto, @IdTiendaOrigen, @IdTiendaDestino, @Cantidad,
             @Observaciones, @IdUsuario, GETDATE(), 'Pendiente');

        SET @IdTraslado = SCOPE_IDENTITY();
        SET @Resultado  = 1;
        SET @Mensaje    = 'Traslado registrado. Queda PENDIENTE de aprobación por la sucursal destino.';
    END TRY
    BEGIN CATCH
        SET @Resultado=0; SET @IdTraslado=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarTrasladoPendiente creado.';
GO

-- ─── 3. usp_AprobarTraslado — aprueba y RECIÉN AHÍ mueve el stock ───────────────
CREATE OR ALTER PROCEDURE dbo.usp_AprobarTraslado
    @IdTraslado       INT,
    @IdUsuarioAprueba INT,
    @EsSuperAdmin     BIT = 0,
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Estado VARCHAR(20), @Cantidad INT, @IdProd INT,
                @IdOrigen INT, @IdDestino INT, @IdUsuReg INT;

        SELECT @Estado    = EstadoAprobacion,
               @Cantidad  = Cantidad,
               @IdProd    = IdProducto,
               @IdOrigen  = IdTiendaOrigen,
               @IdDestino = IdTiendaDestino,
               @IdUsuReg  = IdUsuario
        FROM dbo.TRASLADO WHERE IdTraslado = @IdTraslado;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Traslado no encontrado.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden aprobar traslados Pendientes. Estado actual: '+@Estado; ROLLBACK; RETURN; END

        -- Segregación: quien registró no puede aprobar (salvo SuperAdmin)
        IF @EsSuperAdmin = 0 AND @IdUsuReg = @IdUsuarioAprueba
        BEGIN SET @Resultado=0; SET @Mensaje='El usuario que registró el traslado no puede aprobarlo (segregación de funciones).'; ROLLBACK; RETURN; END

        -- Revalidar stock origen al momento de aprobar
        DECLARE @StockOrigen BIGINT;
        SELECT @StockOrigen = Stock FROM dbo.PRODUCTO_TIENDA
        WHERE IdProducto = @IdProd AND IdTienda = @IdOrigen;

        IF ISNULL(@StockOrigen, 0) < @Cantidad
        BEGIN SET @Resultado=0; SET @Mensaje='Stock insuficiente en origen al aprobar (disponible: '+CAST(ISNULL(@StockOrigen,0) AS VARCHAR)+').'; ROLLBACK; RETURN; END

        -- Descontar de origen
        UPDATE dbo.PRODUCTO_TIENDA SET Stock = Stock - @Cantidad
        WHERE IdProducto = @IdProd AND IdTienda = @IdOrigen;

        -- Agregar en destino (si existe el registro, sino insertar)
        IF EXISTS (SELECT 1 FROM dbo.PRODUCTO_TIENDA WHERE IdProducto = @IdProd AND IdTienda = @IdDestino)
            UPDATE dbo.PRODUCTO_TIENDA SET Stock = Stock + @Cantidad
            WHERE IdProducto = @IdProd AND IdTienda = @IdDestino;
        ELSE
        BEGIN
            -- Tomar datos del producto en origen como base
            INSERT INTO dbo.PRODUCTO_TIENDA (IdProducto, IdTienda, Stock, StockMinimo, StockMaximo)
            SELECT IdProducto, @IdDestino, @Cantidad, StockMinimo, StockMaximo
            FROM dbo.PRODUCTO_TIENDA WHERE IdProducto = @IdProd AND IdTienda = @IdOrigen;
        END

        -- Marcar aprobado
        UPDATE dbo.TRASLADO
           SET EstadoAprobacion = 'Aprobado',
               IdUsuarioAprueba = @IdUsuarioAprueba,
               FechaAprobacion  = GETDATE()
         WHERE IdTraslado = @IdTraslado;

        SET @Resultado = 1;
        SET @Mensaje   = 'Traslado aprobado. Stock movido de sucursal.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AprobarTraslado creado.';
GO

-- ─── 4. usp_RechazarTraslado — rechaza sin tocar stock ──────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RechazarTraslado
    @IdTraslado       INT,
    @IdUsuarioAprueba INT,
    @MotivoRechazo    VARCHAR(255),
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Estado VARCHAR(20);
        SELECT @Estado = EstadoAprobacion FROM dbo.TRASLADO WHERE IdTraslado = @IdTraslado;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Traslado no encontrado.'; RETURN; END
        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden rechazar traslados Pendientes.'; RETURN; END

        UPDATE dbo.TRASLADO
           SET EstadoAprobacion = 'Rechazado',
               IdUsuarioAprueba = @IdUsuarioAprueba,
               FechaAprobacion  = GETDATE(),
               MotivoRechazo    = @MotivoRechazo
         WHERE IdTraslado = @IdTraslado;

        SET @Resultado=1; SET @Mensaje='Traslado rechazado. El stock no fue modificado.';
    END TRY
    BEGIN CATCH SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE(); END CATCH
END
GO
PRINT 'OK: usp_RechazarTraslado creado.';
GO

-- ─── 5. usp_ObtenerTrasladosHistorial — incluye estado de aprobación ─────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerTrasladosHistorial
    @FechaInicio      DATE,
    @FechaFin         DATE,
    @IdTienda         INT  = 0,
    @EstadoAprobacion VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.IdTraslado,
        p.Nombre                                        AS NombreProducto,
        p.Codigo                                        AS CodigoProducto,
        to2.Nombre                                      AS TiendaOrigen,
        td.Nombre                                       AS TiendaDestino,
        t.Cantidad,
        ISNULL(t.Observaciones, '')                     AS Observaciones,
        ur.Nombres + ' ' + ur.Apellidos                 AS Usuario,
        CONVERT(VARCHAR(19), t.FechaTraslado, 120)      AS FechaTraslado,
        t.EstadoAprobacion,
        ISNULL(ua.Nombres + ' ' + ua.Apellidos, '')     AS UsuarioAprueba,
        CONVERT(VARCHAR(19), t.FechaAprobacion, 120)    AS FechaAprobacion,
        ISNULL(t.MotivoRechazo, '')                     AS MotivoRechazo,
        t.IdTiendaDestino
    FROM dbo.TRASLADO t
    INNER JOIN dbo.PRODUCTO p    ON p.IdProducto  = t.IdProducto
    INNER JOIN dbo.TIENDA   to2  ON to2.IdTienda  = t.IdTiendaOrigen
    INNER JOIN dbo.TIENDA   td   ON td.IdTienda   = t.IdTiendaDestino
    INNER JOIN dbo.USUARIO  ur   ON ur.IdUsuario  = t.IdUsuario
    LEFT  JOIN dbo.USUARIO  ua   ON ua.IdUsuario  = t.IdUsuarioAprueba
    WHERE CAST(t.FechaTraslado AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (@IdTienda = 0 OR t.IdTiendaOrigen = @IdTienda OR t.IdTiendaDestino = @IdTienda)
      AND (@EstadoAprobacion = '' OR t.EstadoAprobacion = @EstadoAprobacion)
    ORDER BY
        CASE WHEN t.EstadoAprobacion = 'Pendiente' THEN 0 ELSE 1 END,
        t.FechaTraslado DESC;
END
GO
PRINT 'OK: usp_ObtenerTrasladosHistorial actualizado.';
GO

-- ─── 6. Permiso de menú: Aprobar Traslados ──────────────────────────────────────
-- Agregar submenú "Aprobar Traslados" bajo "Inventario" para roles Encargado/Admin/SuperAdmin
-- (Ajustar los IdMenu/IdRol según tu base de datos)
-- EJEMPLO:
-- INSERT INTO dbo.MENU (Nombre, Controlador, Accion, IdMenuPadre, Orden, Icono, Activo)
-- VALUES ('Aprobar Traslados', 'Inventario', 'AprobarTraslados', <IdMenuInventario>, 4, 'fas fa-check-double', 1);
PRINT 'PENDIENTE: agregar manualmente el submenú Aprobar Traslados con el script de permisos correspondiente.';
GO

PRINT '════ Script 131 (Traslado con aprobación) completado ════';
GO
