-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 90d: Restaurar usp_ObtenerProductoTienda con aliases correctos
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- El script 89 (y 90c) rompió este SP al:
--   - Agregar @IdTienda como parámetro (el C# lo llama SIN parámetros)
--   - Cambiar aliases: p.Codigo en vez de p.Codigo AS CodigoProducto, etc.
--   - No incluir el JOIN a TIENDA para NombreTienda/DireccionTienda/RUC
--   - Usar "Porcentaje" desde tabla IVA en vez de IvaPorcentaje directo
--
-- Este script restaura la estructura de script 58 + agrega las nuevas columnas:
--   CostoPromedio, UnidadMedida, DescuentoMaxPermitido
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductoTienda]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pt.IdProductoTienda,
        p.IdProducto,
        p.Codigo                                        AS CodigoProducto,
        p.Nombre                                        AS NombreProducto,
        p.Descripcion                                   AS DescripcionProducto,
        t.IdTienda,
        t.RUC,
        t.Nombre                                        AS NombreTienda,
        t.Direccion                                     AS DireccionTienda,

        -- Costos
        pt.PrecioUnidadCompra,
        ISNULL(pt.CostoPromedio, 0)                     AS CostoPromedio,

        -- Precio compra con IVA
        CEILING(
            pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje / 100.0)
        )                                               AS PrecioCompraIvaIncluido,

        -- Precio sugerido = CPP × (1 + margen%) × (1 + IVA%)
        --   Si no hay CPP o margen, cae al precio calculado por PrecioUnidadCompra
        CASE
            WHEN ISNULL(pt.CostoPromedio, 0) > 0
                 AND ISNULL(c.PorcentajeGanancia, 0) > 0
            THEN ROUND(
                    pt.CostoPromedio
                    * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
                    * (1.0 + p.IvaPorcentaje / 100.0),
                 0)
            ELSE
                CEILING(
                    pt.PrecioUnidadCompra
                    * (1.0 + p.IvaPorcentaje / 100.0)
                    * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
                )
        END                                             AS PrecioSugerido,

        -- Margen de categoría (alias que lee CD_ProductoTienda.cs)
        ISNULL(c.PorcentajeGanancia, 0)                 AS PorcentajeGanancia,

        -- Descuento máximo y unidad de medida (nuevas columnas script 89)
        ISNULL(c.DescuentoMaxPermitido, 0)              AS DescuentoMaxPermitido,
        ISNULL(p.UnidadMedida, 'Unidad')                AS UnidadMedida,

        -- Precio de venta efectivo (manual > calculado)
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
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                               AS PrecioVenta,

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
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                               AS PrecioVentaIvaIncluido,

        pt.Stock,
        p.IvaPorcentaje                                 AS Porcentaje,
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
PRINT 'OK: usp_ObtenerProductoTienda restaurado — aliases correctos + CostoPromedio + UnidadMedida + DescuentoMaxPermitido.';
GO

-- Verificación rápida
SELECT TOP 3 CodigoProducto, NombreProducto, PorcentajeGanancia, DescuentoMaxPermitido, UnidadMedida, CostoPromedio
FROM OPENROWSET('SQLNCLI', 'Server=.;Trusted_Connection=yes;',
    'EXEC DBVENTAS_WEB.dbo.usp_ObtenerProductoTienda');
-- Nota: si OPENROWSET no está habilitado, comentar la verificación y probar desde la app.

PRINT '════ Script 90d completado ════';
GO
