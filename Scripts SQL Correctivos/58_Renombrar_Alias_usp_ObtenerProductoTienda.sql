-- ============================================================
-- Script 58: Renombrar alias de precios en usp_ObtenerProductoTienda
-- Fecha: 2026-05-18
--
-- Cambios de nomenclatura:
--   PrecioVentaSugerido  →  PrecioSugerido
--   (PrecioVenta y PorcentajeGanancia sin cambio — el C# los mapea igual)
-- ============================================================

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductoTienda]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pt.IdProductoTienda,
        p.IdProducto,
        p.Codigo                          AS CodigoProducto,
        p.Nombre                          AS NombreProducto,
        p.Descripcion                     AS DescripcionProducto,
        t.IdTienda,
        t.RUC,
        t.Nombre                          AS NombreTienda,
        t.Direccion                       AS DireccionTienda,

        -- Costo de compra sin IVA
        pt.PrecioUnidadCompra,

        -- Costo con IVA incluido
        CEILING(
            pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje / 100.0)
        )                                 AS PrecioCompraIvaIncluido,

        -- Precio de venta sugerido por margen de categoría (IVA incluido)
        CEILING(
            pt.PrecioUnidadCompra
            * (1.0 + p.IvaPorcentaje        / 100.0)
            * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
        )                                 AS PrecioSugerido,

        -- Porcentaje de ganancia de la categoría
        ISNULL(c.PorcentajeGanancia, 0)   AS PorcentajeGanancia,

        -- Precio de venta efectivo:
        --   prioridad 1 → precio vigente en PRECIO_VENTA (asignado manualmente)
        --   prioridad 2 → precio calculado por margen
        ISNULL(
            (
                SELECT TOP 1 pv.PrecioVenta
                FROM   dbo.PRECIO_VENTA pv
                WHERE  pv.IdProducto   = p.IdProducto
                  AND  pv.FechaInicio <= GETDATE()
                  AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                ORDER  BY pv.FechaInicio DESC
            ),
            CEILING(
                pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje        / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                 AS PrecioVenta,

        -- PrecioVentaIvaIncluido = igual a PrecioVenta (precios de venta
        -- se manejan IVA-incluido en todo el sistema)
        ISNULL(
            (
                SELECT TOP 1 pv.PrecioVenta
                FROM   dbo.PRECIO_VENTA pv
                WHERE  pv.IdProducto   = p.IdProducto
                  AND  pv.FechaInicio <= GETDATE()
                  AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                ORDER  BY pv.FechaInicio DESC
            ),
            CEILING(
                pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje        / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                 AS PrecioVentaIvaIncluido,

        pt.Stock,
        p.IvaPorcentaje                   AS Porcentaje,
        pt.Iniciado

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = pt.IdProducto
    INNER JOIN dbo.TIENDA          t  ON t.IdTienda    = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       c  ON c.IdCategoria = p.IdCategoria

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1

    ORDER BY p.Nombre;
END
GO

PRINT 'OK: usp_ObtenerProductoTienda — alias PrecioVentaSugerido renombrado a PrecioSugerido.';
GO
