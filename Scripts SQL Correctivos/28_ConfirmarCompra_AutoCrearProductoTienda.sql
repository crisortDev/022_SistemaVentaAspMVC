-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 28: usp_ConfirmarCompraEImpactarStock
--            Auto-crear PRODUCTO_TIENDA si el producto no está registrado
--            en la tienda destino al momento de confirmar la compra.
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-08
--
-- Regla de negocio definida:
--   • Al confirmar una compra, si un producto recibido no tiene fila en
--     PRODUCTO_TIENDA para esa sucursal, el SP la crea automáticamente
--     con Stock = cantidad recibida y precios en 0 (se configuran luego
--     desde el módulo de Productos).
--   • Los productos nuevos se registran solo en PRODUCTO (no en
--     PRODUCTO_TIENDA); la fila de tienda se genera con la primera compra.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

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

        -- ── Validar stock máximo (solo si StockMaximo > 0) ───────────────────
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';

        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '  + CAST(ISNULL(pt.Stock, 0)  AS VARCHAR) +
               ', a recibir: '          + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '             + CAST(pt.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                          AND pt.IdTienda   = @IdTienda
         INNER JOIN dbo.PRODUCTO p         ON p.IdProducto  = dc.IdProducto
         WHERE dc.IdCompra    = @IdCompra
           AND dc.Activo      = 1
           AND pt.StockMaximo > 0
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > pt.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Confirmar superaría el stock máximo en: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ── AUTO-CREAR PRODUCTO_TIENDA para productos nuevos en esta tienda ──
        --    Si el producto recibido no tiene fila para esta sucursal,
        --    se inserta con Stock = 0 (el UPDATE siguiente lo lleva al valor real).
        INSERT INTO dbo.PRODUCTO_TIENDA
            (IdProducto, IdTienda, PrecioUnidadCompra, PrecioUnidadVenta,
             Stock, StockMinimo, StockMaximo, LimiteCompraDiaria,
             Iniciado, Activo, FechaRegistro)
        SELECT DISTINCT
            dc.IdProducto,
            @IdTienda,
            dc.PrecioUnitarioCompra,   -- precio de compra tomado de la factura
            0,                         -- precio venta: pendiente de configurar
            0, 0, 0, 0,
            0,                         -- Iniciado = 0, el UPDATE lo cambia a 1
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

PRINT 'OK: usp_ConfirmarCompraEImpactarStock actualizado.'
PRINT '    Si un producto recibido no tenía fila en PRODUCTO_TIENDA para la sucursal,'
PRINT '    se crea automáticamente con el precio de compra de la factura.'
GO
