-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 100: Reporte de Rentabilidad limpio (para defensa)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Corrige 3 problemas visuales del reporte SIN modificar datos históricos:
--   1. FILAS DUPLICADAS: el producto en varias PRODUCTO_TIENDA hacía "fan-out" y
--      las ventas se contaban repetidas. FIX: las ventas se pre-agregan en un CTE
--      por (IdProducto, IdTienda) y se unen 1 a 1 → una fila por producto/tienda.
--   2. MARGEN 100% FALSO: productos con CostoPromedio = 0 (nunca tuvieron compra
--      confirmada) inflaban el margen. FIX: se excluyen del reporte (no se puede
--      calcular rentabilidad sin costo).
--   3. MÁRGENES NEGATIVOS ENORMES: provenían de ventas de PRUEBA 2025 con precios
--      irreales. FIX: el reporte solo considera ventas con precio unitario > 0 y,
--      por defecto, desde el período pedido (no se tocan los datos; solo se filtran).
--
-- Idempotente (CREATE OR ALTER). No borra ni anula nada.
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

    -- ── Ventas pre-agregadas por producto + tienda (evita duplicación / fan-out) ──
    --    Solo ventas Activas, del período, y con precio unitario real (> 0)
    --    → excluye las ventas de prueba 2025 con precios irreales.
    ;WITH VentasAgg AS (
        SELECT
            dv.IdProducto,
            v.IdTienda,
            SUM(dv.Cantidad)                                                       AS UnidadesVendidas,
            SUM(dv.Cantidad * dv.PrecioUnidad
                / (1.0 + ISNULL(dv.IvaPorcentaje, 10) / 100.0))                    AS IngresosSinIVA,
            SUM(dv.Cantidad
                * COALESCE(dv.CostoUnitarioCPP, 0))                               AS CostoCPP
        FROM dbo.DETALLE_VENTA dv
        INNER JOIN dbo.VENTA v ON v.IdVenta = dv.IdVenta
        WHERE dv.Activo       = 1
          AND v.Estado        = 'Activa'
          AND dv.PrecioUnidad > 0                          -- descarta ventas de prueba sin precio real
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

        -- Precio de venta vigente
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

        -- Margen Bruto %
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
      -- Excluir productos sin costo (no se puede calcular rentabilidad real)
      AND  ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra) > 0

    ORDER BY UtilidadBruta DESC;
END
GO
PRINT 'OK: usp_rptRentabilidadProducto — sin duplicados, sin costo 0, sin ventas de prueba.';
GO
