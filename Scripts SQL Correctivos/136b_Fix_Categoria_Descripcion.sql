-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 136b: Fix columna CATEGORIA — Descripcion (no Nombre)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-22
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── usp_ObtenerProductosParaConteo ──────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerProductosParaConteo
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProducto,
        p.Codigo,
        p.Nombre,
        ISNULL(c.Descripcion, 'Sin categoría') AS Categoria
        -- ⚠ NO se expone Stock, Costo ni Precio
    FROM dbo.PRODUCTO_TIENDA pt
    JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto AND p.Activo = 1
    LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdTienda = @IdTienda AND pt.Activo = 1
    ORDER BY c.Descripcion, p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductosParaConteo (fix Descripcion)';
GO

-- ── usp_ObtenerDetalleInventario ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleInventario
    @IdInventario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Codigo               AS CodigoProducto,
        p.Nombre               AS NombreProducto,
        ISNULL(c.Descripcion,'—') AS Categoria,
        d.StockSistema,
        d.StockContado,
        d.Diferencia
    FROM dbo.DETALLE_INVENTARIO d
    JOIN dbo.PRODUCTO p ON p.IdProducto = d.IdProducto
    LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE d.IdInventario = @IdInventario
    ORDER BY c.Descripcion, p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerDetalleInventario (fix Descripcion)';
GO

PRINT '════ Script 136b completado ════';
GO
