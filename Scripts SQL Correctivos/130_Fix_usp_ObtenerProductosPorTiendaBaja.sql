-- ════════════════════════════════════════════════════════════════════
-- SCRIPT 130: Fix usp_ObtenerProductosPorTiendaBaja
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
--
-- Problema: el SP original filtraba Stock > 0, ocultando productos
--           asignados a una sucursal pero con stock en cero.
--           Para Baja y Toma de Inventario se deben mostrar TODOS
--           los productos activos asignados a la sucursal.
-- ════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerProductosPorTiendaBaja
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pt.IdProductoTienda,
        p.IdProducto,
        p.Codigo,
        p.Nombre,
        ISNULL(pt.Stock, 0) AS Stock
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
    WHERE pt.IdTienda = @IdTienda
      AND p.Activo = 1
    ORDER BY p.Nombre;
END
GO

PRINT 'OK: usp_ObtenerProductosPorTiendaBaja recreado (sin filtro de Stock > 0).';
GO
