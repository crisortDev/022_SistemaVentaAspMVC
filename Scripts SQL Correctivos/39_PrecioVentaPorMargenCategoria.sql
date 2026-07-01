-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 39: Precio de venta por margen de categoría
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-12
--
-- Objetivo:
--   El precio de venta sugerido para cada producto se calcula aplicando el
--   porcentaje de ganancia mínimo de su categoría sobre el costo de compra
--   IVA-incluido:
--
--     PrecioVentaSugerido = CEILING(PrecioUnidadCompra
--                                    * (1 + IvaPorcentaje  / 100.0)
--                                    * (1 + PorcentajeGanancia / 100.0))
--
--   Si existe un precio vigente en la tabla PRECIO_VENTA (con timbrado manual),
--   ese precio tiene prioridad; en caso contrario se usa el precio sugerido.
--
-- Cambios:
--   1. CREATE OR ALTER usp_ObtenerProductoTienda
--        → JOINea CATEGORIA, devuelve PorcentajeGanancia y PrecioVentaSugerido
--        → PrecioVenta = precio PRECIO_VENTA vigente  si existe
--                       precio sugerido por margen   en caso contrario
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. usp_ObtenerProductoTienda ─────────────────────────────────────────────
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

        -- Costo de compra (sin IVA, tal como se almacena en la tabla)
        pt.PrecioUnidadCompra,

        -- Costo con IVA incluido
        CEILING(
            pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje / 100.0)
        )                                 AS PrecioCompraIvaIncluido,

        -- Precio de venta sugerido por margen de categoría (IVA incluido)
        -- = costo_con_iva * (1 + margen)
        CEILING(
            pt.PrecioUnidadCompra
            * (1.0 + p.IvaPorcentaje        / 100.0)
            * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
        )                                 AS PrecioVentaSugerido,

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

PRINT 'OK: usp_ObtenerProductoTienda actualizado (precio por margen de categoría).';
GO

-- ── 2. Diagnóstico: productos con margen y precio sugerido ───────────────────
SELECT
    p.Codigo,
    p.Nombre,
    c.Descripcion                                    AS Categoria,
    ISNULL(c.PorcentajeGanancia, 0)                  AS [Margen %],
    pt.PrecioUnidadCompra                            AS [Costo s/IVA],
    CEILING(pt.PrecioUnidadCompra
            * (1.0 + p.IvaPorcentaje / 100.0))       AS [Costo c/IVA],
    CEILING(pt.PrecioUnidadCompra
            * (1.0 + p.IvaPorcentaje / 100.0)
            * (1.0 + ISNULL(c.PorcentajeGanancia,0) / 100.0))
                                                     AS [Precio Sugerido c/IVA],
    p.IvaPorcentaje                                  AS [IVA %],
    pt.Stock,
    t.Nombre                                         AS Tienda
FROM       dbo.PRODUCTO_TIENDA pt
INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = pt.IdProducto
INNER JOIN dbo.TIENDA          t  ON t.IdTienda    = pt.IdTienda
LEFT  JOIN dbo.CATEGORIA       c  ON c.IdCategoria = p.IdCategoria
WHERE  p.Activo  = 1
  AND  pt.Activo = 1
ORDER BY p.Nombre;
GO
