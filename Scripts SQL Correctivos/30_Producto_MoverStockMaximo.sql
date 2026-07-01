-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 30: Mover StockMaximo de PRODUCTO_TIENDA → PRODUCTO
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- Motivación:
--   Al registrar un producto nuevo NO existe fila en PRODUCTO_TIENDA todavía.
--   Por tanto el StockMaximo de PRODUCTO_TIENDA no podía ser validado al crear
--   una OC ni al confirmar la compra para ese producto.
--   Al mover StockMaximo a PRODUCTO queda disponible desde el primer registro.
--
-- Estrategia de migración (sin DROP COLUMN):
--   • Se agrega la columna PRODUCTO.StockMaximo (0 = sin límite).
--   • La columna PRODUCTO_TIENDA.StockMaximo se MANTIENE en la BD pero
--     deja de usarse en validaciones (no es necesario un DROP COLUMN para
--     que el cambio funcione correctamente).
--   • Todos los SPs y la capa C# pasan a leer PRODUCTO.StockMaximo.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Agregar columna a PRODUCTO (solo si no existe) ───────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID('dbo.PRODUCTO')
       AND name      = 'StockMaximo'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO
        ADD StockMaximo INT NOT NULL
            CONSTRAINT DF_PRODUCTO_StockMaximo DEFAULT 0;

    PRINT 'OK: Columna StockMaximo agregada a PRODUCTO (default 0 = sin límite).';
END
ELSE
    PRINT 'INFO: Columna StockMaximo ya existe en PRODUCTO.';
GO

-- ── 2. usp_ObtenerProductos — incluir StockMaximo ──────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductos]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProducto,
        p.Codigo,
        p.ValorCodigo,
        p.Nombre,
        p.Descripcion    AS DescripcionProducto,
        p.IdCategoria,
        c.Descripcion    AS DescripcionCategoria,
        p.IvaPorcentaje,
        p.StockMaximo,
        p.Activo
      FROM dbo.PRODUCTO p
      LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
     ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductos actualizado (incluye StockMaximo).';
GO

-- ── 3. usp_RegistrarProducto — agregar @StockMaximo ────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarProducto]
    @Nombre        NVARCHAR(200),
    @Descripcion   NVARCHAR(500),
    @IdCategoria   INT,
    @IvaPorcentaje DECIMAL(5,2) = 10,
    @StockMaximo   INT          = 0,
    @Resultado     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM dbo.PRODUCTO
             WHERE LTRIM(RTRIM(Nombre)) = LTRIM(RTRIM(@Nombre))
        )
        BEGIN
            SET @Resultado = 0; RETURN;
        END

        DECLARE @ValorCodigo INT;
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1
          FROM dbo.PRODUCTO;

        DECLARE @Codigo NVARCHAR(20) = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);

        INSERT INTO dbo.PRODUCTO
            (Codigo, ValorCodigo, Nombre, Descripcion, IdCategoria,
             IvaPorcentaje, StockMaximo, PrecioVenta, Activo, FechaRegistro)
        VALUES
            (@Codigo, @ValorCodigo, @Nombre, @Descripcion, @IdCategoria,
             @IvaPorcentaje, @StockMaximo, 0, 1, GETDATE());

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarProducto actualizado (incluye @StockMaximo).';
GO

-- ── 4. usp_ModificarProducto — agregar @StockMaximo ────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ModificarProducto]
    @IdProducto    INT,
    @Nombre        NVARCHAR(200),
    @Descripcion   NVARCHAR(500),
    @IdCategoria   INT,
    @IvaPorcentaje DECIMAL(5,2) = 10,
    @StockMaximo   INT          = 0,
    @Activo        BIT          = 1,
    @Resultado     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO WHERE IdProducto = @IdProducto)
        BEGIN
            SET @Resultado = 0; RETURN;
        END

        UPDATE dbo.PRODUCTO
           SET Nombre        = @Nombre,
               Descripcion   = @Descripcion,
               IdCategoria   = @IdCategoria,
               IvaPorcentaje = @IvaPorcentaje,
               StockMaximo   = @StockMaximo,
               Activo        = @Activo
         WHERE IdProducto    = @IdProducto;

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_ModificarProducto actualizado (incluye @StockMaximo).';
GO

-- ── 5. usp_ConfirmarCompraEImpactarStock — usar PRODUCTO.StockMaximo ────────
--    La validación de stock máximo ahora lee p.StockMaximo (PRODUCTO)
--    en lugar de pt.StockMaximo (PRODUCTO_TIENDA).
CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra      INT,
    @IdUsuario     INT  = 0,
    @EsSuperAdmin  BIT  = 0,
    @Resultado     BIT           OUTPUT,
    @Mensaje       NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda          INT,
                @EstadoRecepcion   VARCHAR(20),
                @EstadoActual      VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @IdTienda          = IdTienda,
               @EstadoRecepcion   = EstadoRecepcion,
               @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        -- ── Validar existencia ────────────────────────────────────────────────
        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        -- ── Validar estado de recepción ───────────────────────────────────────
        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se puede confirmar una compra en estado EnRecepcion. '
                           + 'Estado actual: ' + ISNULL(@EstadoRecepcion, '?');
            ROLLBACK; RETURN;
        END

        -- ── Validar NC pendiente ──────────────────────────────────────────────
        IF ISNULL((SELECT MontoNotaCredito FROM dbo.COMPRA WHERE IdCompra = @IdCompra), 0) = 0
           AND EXISTS (
               SELECT 1 FROM dbo.DETALLE_COMPRA
                WHERE IdCompra = @IdCompra
                  AND Activo   = 1
                  AND ISNULL(CantidadRecibida, Cantidad) < Cantidad
           )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Existen diferencias entre lo pedido y lo recibido. '
                           + 'Genere la Nota de Crédito antes de confirmar.';
            ROLLBACK; RETURN;
        END

        -- ── Validar segregación O&M ───────────────────────────────────────────
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que registró la factura no puede confirmarla '
                           + '(segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- ── Validar stock máximo usando PRODUCTO.StockMaximo ─────────────────
        --    Solo verifica productos con StockMaximo > 0.
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';

        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '  + CAST(ISNULL(pt.Stock, 0) AS VARCHAR) +
               ', a recibir: '          + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '             + CAST(p.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO p          ON p.IdProducto  = dc.IdProducto
          LEFT JOIN dbo.PRODUCTO_TIENDA pt  ON pt.IdProducto = dc.IdProducto
                                           AND pt.IdTienda   = @IdTienda
         WHERE dc.IdCompra    = @IdCompra
           AND dc.Activo      = 1
           AND p.StockMaximo  > 0
           AND ISNULL(ISNULL(pt.Stock, 0), 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > p.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Confirmar superaría el stock máximo en: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ── AUTO-CREAR PRODUCTO_TIENDA para productos nuevos en esta tienda ──
        INSERT INTO dbo.PRODUCTO_TIENDA
            (IdProducto, IdTienda, PrecioUnidadCompra, PrecioUnidadVenta,
             Stock, StockMinimo, StockMaximo, LimiteCompraDiaria,
             Iniciado, Activo, FechaRegistro)
        SELECT DISTINCT
            dc.IdProducto,
            @IdTienda,
            dc.PrecioUnitarioCompra,
            0,
            0, 0, 0, 0,
            0,
            1,
            GETDATE()
          FROM dbo.DETALLE_COMPRA dc
         WHERE dc.IdCompra    = @IdCompra
           AND dc.Activo      = 1
           AND dc.EstadoLinea IN ('Aceptada', 'NC')
           AND NOT EXISTS (
               SELECT 1 FROM dbo.PRODUCTO_TIENDA pt
                WHERE pt.IdProducto = dc.IdProducto
                  AND pt.IdTienda   = @IdTienda
           );

        -- ── Impactar stock ────────────────────────────────────────────────────
        ;WITH Recepcionado AS (
            SELECT IdProducto,
                   SUM(ISNULL(CantidadRecibida, Cantidad)) AS Cantidad
              FROM dbo.DETALLE_COMPRA
             WHERE IdCompra    = @IdCompra
               AND Activo      = 1
               AND EstadoLinea IN ('Aceptada', 'NC')
             GROUP BY IdProducto
        )
        UPDATE pt
           SET Stock    = ISNULL(pt.Stock, 0) + r.Cantidad,
               Iniciado = 1
          FROM dbo.PRODUCTO_TIENDA pt
         INNER JOIN Recepcionado r ON pt.IdProducto = r.IdProducto
         WHERE pt.IdTienda = @IdTienda;

        -- ── Actualizar estado de la compra ────────────────────────────────────
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- ── Historial ─────────────────────────────────────────────────────────
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdCompra,
                 ISNULL(@EstadoActual, 'Pendiente'),
                 'Confirmada',
                 @IdUsuario,
                 CASE WHEN @EsSuperAdmin = 1
                      THEN 'Confirmación por SuperAdmin'
                      ELSE 'Confirmación de factura e impacto de stock' END);
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra confirmada. Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error al confirmar: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ConfirmarCompraEImpactarStock actualizado (usa PRODUCTO.StockMaximo).';
GO

-- ── 6. Diagnóstico final ────────────────────────────────────────────────────
SELECT IdProducto, Codigo, Nombre, IvaPorcentaje, StockMaximo, Activo
  FROM dbo.PRODUCTO
 ORDER BY Nombre;
GO
