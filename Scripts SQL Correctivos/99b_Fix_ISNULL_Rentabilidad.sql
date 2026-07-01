-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 99b: Fix Msg 174 en usp_rptRentabilidadProducto
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- El script 99 usó ISNULL(a, b, c) con 3 argumentos → ISNULL solo acepta 2.
-- Se reemplaza por COALESCE (que sí acepta N argumentos) en el costo histórico:
--     COALESCE(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
-- Resto del SP idéntico al 99.
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

    SELECT
        p.IdProducto,
        p.Codigo                                                        AS Codigo,
        p.Nombre                                                        AS Producto,
        ISNULL(cat.Descripcion, '—')                                   AS Categoria,
        t.Nombre                                                        AS Tienda,
        ISNULL(pt.Stock, 0)                                            AS StockActual,

        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)                AS CostoPromedio,

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

        ISNULL(SUM(dv.Cantidad), 0)                                    AS UnidadesVendidas,

        -- Ingresos SIN IVA
        ISNULL(SUM(
            dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
        ), 0)                                                          AS IngresosTotales,

        -- Costo con CPP histórico de cada línea (COALESCE = acepta 3 argumentos)
        ISNULL(SUM(
            dv.Cantidad * COALESCE(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
        ), 0)                                                          AS CostoTotalVentas,

        -- Utilidad Bruta (ambos lados sin IVA)
        ISNULL(SUM(
            dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
        ), 0)
        - ISNULL(SUM(
            dv.Cantidad * COALESCE(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
        ), 0)                                                          AS UtilidadBruta,

        -- Margen Bruto %
        CASE
            WHEN ISNULL(SUM(
                    dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
                 ), 0) = 0 THEN 0
            ELSE CAST(
                (
                    ISNULL(SUM(
                        dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
                    ), 0)
                    - ISNULL(SUM(
                        dv.Cantidad * COALESCE(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
                    ), 0)
                )
                / NULLIF(SUM(
                    dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
                ), 0) * 100.0
                AS DECIMAL(5,2))
        END                                                             AS MargenBrutoPct,

        ISNULL(pt.Stock, 0)
        * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)             AS ValorInventarioCPP

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p    ON p.IdProducto    = pt.IdProducto
    INNER JOIN dbo.TIENDA          t    ON t.IdTienda      = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       cat  ON cat.IdCategoria = p.IdCategoria
    LEFT  JOIN dbo.DETALLE_VENTA   dv   ON dv.IdProducto  = p.IdProducto
                                       AND dv.Activo      = 1
    LEFT  JOIN dbo.VENTA           v    ON v.IdVenta      = dv.IdVenta
                                       AND v.Estado       = 'Activa'
                                       AND v.IdTienda     = pt.IdTienda
                                       AND CAST(v.FechaRegistro AS DATE)
                                           BETWEEN @FechaInicio AND @FechaFin

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1
      AND  (@IdTienda    = 0 OR pt.IdTienda    = @IdTienda)
      AND  (@IdCategoria = 0 OR p.IdCategoria  = @IdCategoria)

    GROUP BY
        p.IdProducto, p.Codigo, p.Nombre, p.IvaPorcentaje,
        cat.Descripcion, cat.PorcentajeGanancia,
        t.Nombre,
        pt.Stock, pt.CostoPromedio, pt.PrecioUnidadCompra

    ORDER BY UtilidadBruta DESC;
END
GO
PRINT 'OK: usp_rptRentabilidadProducto corregido (COALESCE en lugar de ISNULL de 3 args).';
GO
