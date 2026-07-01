-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 27: Diagnóstico + Fix usp_ConfirmarCompraEImpactarStock
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-08
--
-- Problemas que resuelve:
--   1. La validación de StockMáximo bloqueaba la confirmación cuando
--      StockMaximo = 0 o NULL en PRODUCTO_TIENDA (cualquier recepción fallaba).
--      Fix: solo valida el límite si StockMaximo > 0.
--
--   2. La validación de NecesitaNC se hace ahora en el SP también:
--      si hay líneas NC sin MontoNotaCredito registrado, la confirmación
--      se rechaza con mensaje claro.
--
-- ══════════ PARTE 1: DIAGNÓSTICO (ejecutar primero para ver el estado) ════════
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

PRINT '══ DIAGNÓSTICO: COMPRAS recientes (últimas 20) ══';
SELECT TOP 20
    c.IdCompra,
    RIGHT('000000' + CAST(c.IdCompra AS VARCHAR), 6)    AS NumeroCompra,
    c.NumeroFactura,
    c.Estado,
    c.EstadoRecepcion,
    ISNULL(c.MontoNotaCredito, 0)                        AS MontoNC,
    CASE
        WHEN ISNULL(c.MontoNotaCredito,0) = 0
         AND EXISTS (
             SELECT 1 FROM dbo.DETALLE_COMPRA dc
              WHERE dc.IdCompra = c.IdCompra
                AND dc.Activo   = 1
                AND ISNULL(dc.CantidadRecibida, dc.Cantidad) < dc.Cantidad
         )
        THEN 'SÍ — NC pendiente'
        ELSE 'No'
    END                                                  AS NecesitaNC,
    c.IdUsuario                                          AS IdUsuarioRegistra,
    CONVERT(CHAR(16), c.FechaRegistro, 120)              AS FechaRegistro
FROM dbo.COMPRA c
ORDER BY c.IdCompra DESC;

PRINT '══ DETALLE_COMPRA de la compra más reciente ══';
SELECT TOP 20
    dc.IdDetalleCompra,
    dc.IdCompra,
    p.Nombre                AS Producto,
    dc.Cantidad             AS Ordenada,
    dc.CantidadRecibida     AS Recibida,
    dc.EstadoLinea,
    pt.Stock                AS StockActual,
    pt.StockMaximo
FROM dbo.DETALLE_COMPRA dc
INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dc.IdProducto
LEFT  JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                 AND pt.IdTienda   = (
                                     SELECT IdTienda FROM dbo.COMPRA WHERE IdCompra = dc.IdCompra
                                 )
WHERE dc.IdCompra = (SELECT MAX(IdCompra) FROM dbo.COMPRA)
  AND dc.Activo   = 1
ORDER BY dc.IdDetalleCompra;
GO


-- ═══════════ PARTE 2: CORREGIR el SP ════════════════════════════════════════
-- ════════════════════════════════════════════════════════════════════════════════

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

        -- ── Validar que la compra exista ─────────────────────────────────────
        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        -- ── Validar estado de recepción ──────────────────────────────────────
        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se puede confirmar una compra en estado EnRecepcion. '
                           + 'Estado actual: ' + ISNULL(@EstadoRecepcion, '?');
            ROLLBACK; RETURN;
        END

        -- ── Validar: NC pendiente antes de confirmar ─────────────────────────
        --    Si hay líneas recibidas < ordenadas y aún no se generó NC,
        --    se bloquea la confirmación para forzar la emisión de la NC primero.
        IF ISNULL((SELECT MontoNotaCredito FROM dbo.COMPRA WHERE IdCompra = @IdCompra), 0) = 0
           AND EXISTS (
               SELECT 1 FROM dbo.DETALLE_COMPRA
                WHERE IdCompra = @IdCompra
                  AND Activo   = 1
                  AND ISNULL(CantidadRecibida, Cantidad) < Cantidad
           )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Existen diferencias de cantidades entre lo pedido y lo recibido. '
                           + 'Genere la Nota de Crédito correspondiente antes de confirmar la compra.';
            ROLLBACK; RETURN;
        END

        -- ── Validar segregación O&M ──────────────────────────────────────────
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que registró la factura no puede confirmarla (segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- ── Validar stock máximo (solo si StockMaximo > 0) ───────────────────
        --    Si StockMaximo = 0 o NULL = sin límite configurado → no bloquear.
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
           AND pt.StockMaximo > 0   -- ← SOLO valida si tiene límite configurado
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > pt.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Confirmar superaría el stock máximo en: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ── Impactar stock (Aceptada + NC) ───────────────────────────────────
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

        -- ── Actualizar estado de la compra ───────────────────────────────────
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- ── Historial ────────────────────────────────────────────────────────
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

PRINT 'OK: usp_ConfirmarCompraEImpactarStock corregido:'
PRINT '    • StockMaximo = 0/NULL ya no bloquea la confirmación.'
PRINT '    • NC pendiente bloquea la confirmación con mensaje claro.'
GO
