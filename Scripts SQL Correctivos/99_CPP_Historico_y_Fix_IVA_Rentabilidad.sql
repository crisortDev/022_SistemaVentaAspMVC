-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 99: Precisión del CPP en rentabilidad
--   1. CPP histórico por línea de venta (trigger captura el CPP al momento de vender)
--   2. Fix IVA en usp_rptRentabilidadProducto (comparar ingreso y costo sin IVA)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-30
--
-- PROBLEMAS QUE RESUELVE:
--   A) El reporte valuaba las ventas con el CostoPromedio ACTUAL del producto, no
--      con el CPP que existía al momento de cada venta → margen histórico distorsionado.
--      FIX: nueva columna DETALLE_VENTA.CostoUnitarioCPP, poblada por un TRIGGER en
--           cada inserción (sirve para cualquier SP de venta, presente o futuro).
--   B) IngresosTotales usaba PrecioUnidad CON IVA y lo restaba contra el CPP SIN IVA
--      → utilidad inflada. FIX: descontar el IVA del ingreso antes de comparar.
--
-- IMPORTANTE: las ventas YA EXISTENTES no tienen CPP histórico (no existía la columna);
--   se inicializan con el CostoPromedio actual como mejor aproximación disponible.
--   De aquí en adelante, cada venta guardará su CPP real del momento.
--
-- Idempotente. No borra datos. Hacer BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Columna CostoUnitarioCPP en DETALLE_VENTA ───────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA') AND name = 'CostoUnitarioCPP'
)
BEGIN
    ALTER TABLE dbo.DETALLE_VENTA ADD CostoUnitarioCPP DECIMAL(18,2) NULL;
    PRINT 'OK: Columna DETALLE_VENTA.CostoUnitarioCPP agregada.';
END
ELSE
    PRINT 'INFO: Columna CostoUnitarioCPP ya existía.';
GO

-- ─── 2. Inicializar líneas existentes con el CPP actual (mejor aproximación) ─────
UPDATE dv
   SET dv.CostoUnitarioCPP = ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
FROM dbo.DETALLE_VENTA dv
INNER JOIN dbo.VENTA          v  ON v.IdVenta     = dv.IdVenta
INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dv.IdProducto
                                  AND pt.IdTienda  = v.IdTienda
WHERE dv.CostoUnitarioCPP IS NULL;
PRINT 'OK: CostoUnitarioCPP inicializado en líneas de venta existentes.';
GO

-- ─── 3. TRIGGER: capturar el CPP vigente al insertar cada línea de venta ─────────
--   Se dispara para CUALQUIER SP que inserte en DETALLE_VENTA (venta directa,
--   facturación desde pre-venta, etc.). Solo completa las filas que vengan sin CPP.
CREATE OR ALTER TRIGGER dbo.trg_DetalleVenta_CapturarCPP
ON dbo.DETALLE_VENTA
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dv
       SET dv.CostoUnitarioCPP = ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN inserted i          ON i.IdDetalleVenta = dv.IdDetalleVenta
    INNER JOIN dbo.VENTA v         ON v.IdVenta        = dv.IdVenta
    INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dv.IdProducto
                                      AND pt.IdTienda  = v.IdTienda
    WHERE dv.CostoUnitarioCPP IS NULL;   -- no pisa un valor ya seteado explícitamente
END
GO
PRINT 'OK: Trigger trg_DetalleVenta_CapturarCPP creado.';
GO

-- ─── 4. usp_rptRentabilidadProducto — IVA correcto + CPP histórico ──────────────
--   • IngresosSinIVA = SUM(Cantidad * PrecioUnidad / (1 + IVA/100))   ← quita IVA del ingreso
--   • CostoTotal     = SUM(Cantidad * CostoUnitarioCPP_de_la_linea)   ← CPP histórico real
--   • Utilidad y margen quedan ambos SIN IVA → comparación correcta.
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

        -- CPP actual del producto (referencia de inventario)
        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)                AS CostoPromedio,

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

        -- Unidades vendidas en el período
        ISNULL(SUM(dv.Cantidad), 0)                                    AS UnidadesVendidas,

        -- Ingresos SIN IVA (se descuenta el IVA del precio de venta, que es IVA-incluido)
        ISNULL(SUM(
            dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
        ), 0)                                                          AS IngresosTotales,

        -- Costo total con el CPP HISTÓRICO de cada línea (sin IVA, como el CPP)
        ISNULL(SUM(
            dv.Cantidad * ISNULL(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
        ), 0)                                                          AS CostoTotalVentas,

        -- Utilidad Bruta = IngresosSinIVA − CostoCPP   (ambos sin IVA → correcto)
        ISNULL(SUM(
            dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
        ), 0)
        - ISNULL(SUM(
            dv.Cantidad * ISNULL(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
        ), 0)                                                          AS UtilidadBruta,

        -- Margen Bruto % = UtilidadBruta / IngresosSinIVA * 100
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
                        dv.Cantidad * ISNULL(dv.CostoUnitarioCPP, pt.CostoPromedio, pt.PrecioUnidadCompra)
                    ), 0)
                )
                / NULLIF(SUM(
                    dv.Cantidad * dv.PrecioUnidad / (1.0 + ISNULL(dv.IvaPorcentaje, p.IvaPorcentaje) / 100.0)
                ), 0) * 100.0
                AS DECIMAL(5,2))
        END                                                             AS MargenBrutoPct,

        -- Valor del inventario actual al CPP
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
PRINT 'OK: usp_rptRentabilidadProducto — IVA descontado del ingreso + CPP histórico por línea.';
GO

-- ─── 5. Verificación rápida ─────────────────────────────────────────────────────
-- Líneas de venta sin CPP histórico (debería ser 0 tras la inicialización):
SELECT COUNT(*) AS LineasSinCPP
FROM dbo.DETALLE_VENTA
WHERE CostoUnitarioCPP IS NULL AND Activo = 1;
GO

PRINT '════ Script 99 completado — CPP histórico + IVA correcto en rentabilidad ════';
GO
