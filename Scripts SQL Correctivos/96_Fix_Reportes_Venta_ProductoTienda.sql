-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 96: Fix reportes — Venta (cantidades) y Producto x Tienda (precio venta)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-30
--
-- PROBLEMA 1 (usp_rptVenta):
--   Lee v.CantidadTotal y v.CantidadProducto de la tabla VENTA. Las ventas nuevas
--   (flujo pre-venta → factura) NO llenan esas columnas → salen vacías.
--   FIX: calcular ambas cantidades desde DETALLE_VENTA.
--   IMPORTANTE: el Total de la venta se mantiene tal como fue guardado (v.TotalCosto).
--               NO se recalcula ningún precio de venta.
--
-- PROBLEMA 2 (usp_rptProductoTienda):
--   Lee pt.PrecioUnidadVenta que está en 0. El precio de venta hoy es dinámico
--   (margen de categoría + Costo Promedio Ponderado).
--   FIX: calcular el "Precio Venta" igual que usp_ObtenerProductoTienda:
--        prioridad 1 → precio vigente en PRECIO_VENTA (si existe)
--        prioridad 2 → CEILING(CostoPromedio × (1+margen%) × (1+IVA%))
--   Esto es el precio de CATÁLOGO del producto, no afecta ventas ya hechas.
--
-- Idempotente (CREATE OR ALTER). No borra datos.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_rptVenta — cantidades desde DETALLE_VENTA (Total intacto)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE usp_rptVenta (
    @FechaInicio date,
    @FechaFin    date,
    @IdTienda    int = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CONVERT(CHAR(10), v.FechaRegistro, 103)        AS [Fecha Venta],
        v.Codigo                                        AS [Numero Documento],
        v.TipoDocumento                                 AS [Tipo Documento],
        t.Nombre                                        AS [Nombre Tienda],
        t.RUC                                           AS [Ruc Tienda],
        CONCAT(u.Nombres, ' ', u.Apellidos)             AS [Nombre Empleado],

        -- Unidades vendidas = suma de cantidades de las líneas (activas)
        ISNULL((
            SELECT SUM(dv.Cantidad)
            FROM dbo.DETALLE_VENTA dv
            WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1
        ), 0)                                           AS [Cantidad Unidades Vendidas],

        -- Productos distintos = cantidad de líneas distintas (activas)
        ISNULL((
            SELECT COUNT(DISTINCT dv.IdProducto)
            FROM dbo.DETALLE_VENTA dv
            WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1
        ), 0)                                           AS [Cantidad Productos],

        -- Total: tal como se guardó al facturar (NO se recalcula)
        v.TotalCosto                                    AS [Total Venta]

    FROM dbo.VENTA v
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = v.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = v.IdUsuario
    WHERE CONVERT(date, v.FechaRegistro) BETWEEN @FechaInicio AND @FechaFin
      AND v.IdTienda = IIF(@IdTienda = 0, v.IdTienda, @IdTienda)
    ORDER BY v.FechaRegistro, v.Codigo;
END
GO
PRINT 'OK: usp_rptVenta — cantidades calculadas desde DETALLE_VENTA (Total intacto).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_rptProductoTienda — Precio Venta por margen de categoría + CPP
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE usp_rptProductoTienda (
    @IdTienda int = 0,
    @Codigo   varchar(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.RUC                                           AS [Ruc Tienda],
        t.Nombre                                        AS [Nombre Tienda],
        t.Direccion                                     AS [Direccion Tienda],
        p.Codigo                                        AS [Codigo Producto],
        p.Nombre                                        AS [Nombre Producto],
        p.Descripcion                                   AS [Descripcion Producto],
        pt.Stock                                        AS [Stock en tienda],
        CONVERT(decimal(18,2), pt.PrecioUnidadCompra)   AS [Precio Compra],

        -- Precio Venta dinámico (mismo criterio que usp_ObtenerProductoTienda):
        --   1) precio vigente en PRECIO_VENTA si existe
        --   2) CEILING(CostoPromedio × (1+margen%) × (1+IVA%))
        --   El costo base es CostoPromedio (CPP); si es 0, cae a PrecioUnidadCompra.
        CONVERT(decimal(18,2),
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
                    ISNULL(NULLIF(pt.CostoPromedio, 0), pt.PrecioUnidadCompra)
                    * (1.0 + ISNULL(p.IvaPorcentaje, 0)        / 100.0)
                    * (1.0 + ISNULL(c.PorcentajeGanancia, 0)   / 100.0)
                )
            )
        )                                               AS [Precio Venta]

    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    INNER JOIN dbo.TIENDA    t ON t.IdTienda    = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdTienda = IIF(@IdTienda = 0, pt.IdTienda, @IdTienda)
      AND p.Codigo LIKE '%' + @Codigo + '%'
    ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_rptProductoTienda — Precio Venta por margen de categoría + CPP.';
GO

PRINT '════ Script 96 completado ════';
GO
