-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 100b: Rentabilidad — ocultar filas con margen negativo (ventas a pérdida)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Sobre el script 100, agrega: excluir del reporte los productos cuya utilidad del
-- período sea NEGATIVA (ventas por debajo del costo = datos de prueba irreales).
-- Se conservan:
--   • productos con margen >= 0
--   • productos sin ventas en el período (se muestran con 0, informativos)
-- No se modifican datos. Solo cambia lo que muestra el SP.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_rptRentabilidadProducto]
    @IdTienda     INT  = 0,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL,
    @IdCategoria  INT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)));
    SET @FechaFin    = ISNULL(@FechaFin,    CAST(GETDATE() AS DATE));

    ;WITH VentasAgg AS (
        SELECT
            dv.IdProducto,
            v.IdTienda,
            SUM(dv.Cantidad)                                                       AS UnidadesVendidas,
            SUM(dv.Cantidad * dv.PrecioUnidad
                / (1.0 + ISNULL(dv.IvaPorcentaje, 10) / 100.0))                    AS IngresosSinIVA,
            SUM(dv.Cantidad * COALESCE(dv.CostoUnitarioCPP, 0))                    AS CostoCPP
        FROM dbo.DETALLE_VENTA dv
        INNER JOIN dbo.VENTA v ON v.IdVenta = dv.IdVenta
        WHERE dv.Activo       = 1
          AND v.Estado        = 'Activa'
          AND dv.PrecioUnidad > 0
          AND CAST(v.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
        GROUP BY dv.IdProducto, v.IdTienda
    )

    SELECT
        p.IdProducto,
        p.Codigo                                                        AS Codigo,
        p.Nombre                                                        AS Producto,
        ISNULL(cat.Descripcion, '—')                                   AS Categoria,
        t.Nombre                                                        AS Tienda,
        ISNULL(pt.Stock, 0)                                            AS StockActual,

        CONVERT(DECIMAL(18,2), ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)) AS CostoPromedio,

        ISNULL(
            (SELECT TOP 1 pv.PrecioVenta
             FROM   dbo.PRECIO_VENTA pv
             WHERE  pv.IdProducto   = p.IdProducto
               AND  pv.FechaInicio <= GETDATE()
               AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
             ORDER  BY pv.FechaInicio DESC),
            CEILING(
                ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(cat.PorcentajeGanancia, 0) / 100.0)
            )
        )                                                               AS PrecioVentaVigente,

        ISNULL(va.UnidadesVendidas, 0)                                 AS UnidadesVendidas,
        CONVERT(DECIMAL(18,2), ISNULL(va.IngresosSinIVA, 0))           AS IngresosTotales,
        CONVERT(DECIMAL(18,2), ISNULL(va.CostoCPP, 0))                 AS CostoTotalVentas,
        CONVERT(DECIMAL(18,2),
            ISNULL(va.IngresosSinIVA, 0) - ISNULL(va.CostoCPP, 0))     AS UtilidadBruta,

        CASE
            WHEN ISNULL(va.IngresosSinIVA, 0) = 0 THEN 0
            ELSE CONVERT(DECIMAL(7,2),
                (ISNULL(va.IngresosSinIVA,0) - ISNULL(va.CostoCPP,0))
                / va.IngresosSinIVA * 100.0)
        END                                                             AS MargenBrutoPct,

        CONVERT(DECIMAL(18,2),
            ISNULL(pt.Stock, 0) * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)) AS ValorInventarioCPP

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p   ON p.IdProducto    = pt.IdProducto
    INNER JOIN dbo.TIENDA    t   ON t.IdTienda      = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA cat ON cat.IdCategoria = p.IdCategoria
    LEFT  JOIN VentasAgg     va  ON va.IdProducto   = p.IdProducto
                                 AND va.IdTienda    = pt.IdTienda

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1
      AND  (@IdTienda    = 0 OR pt.IdTienda    = @IdTienda)
      AND  (@IdCategoria = 0 OR p.IdCategoria  = @IdCategoria)
      AND  ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra) > 0
      -- Ocultar ventas a pérdida (margen negativo = datos de prueba irreales).
      -- Se conservan productos sin ventas (va NULL) y los de margen >= 0.
      AND  (va.IdProducto IS NULL OR ISNULL(va.IngresosSinIVA,0) >= ISNULL(va.CostoCPP,0))

    ORDER BY UtilidadBruta DESC;
END
GO
PRINT 'OK: usp_rptRentabilidadProducto — oculta filas con margen negativo.';
GO
