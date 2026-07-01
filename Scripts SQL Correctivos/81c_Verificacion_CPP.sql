-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 81c: Verificación final CPP + fix PRINT subquery
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
-- ════════════════════════════════════════════════════════════════════════════════
USE [DBVENTAS_WEB]
GO

-- ─── 1. Verificar columna CostoPromedio ──────────────────────────────────────
PRINT '════ 1. Columna CostoPromedio en PRODUCTO_TIENDA ════';
SELECT
    p.Nombre        AS Producto,
    t.Nombre        AS Tienda,
    pt.Stock,
    pt.PrecioUnidadCompra   AS UltimoPrecioCompra,
    pt.CostoPromedio        AS CPP
FROM dbo.PRODUCTO_TIENDA pt
INNER JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
INNER JOIN dbo.TIENDA   t ON t.IdTienda   = pt.IdTienda
WHERE pt.Activo = 1
ORDER BY p.Nombre;
GO

-- ─── 2. Verificar submenú Rentabilidad ───────────────────────────────────────
PRINT '════ 2. Submenús del módulo Reporte ════';
SELECT
    s.IdSubMenu,
    s.Nombre,
    s.Controlador,
    s.Vista,
    s.Activo
FROM dbo.SUBMENU s
WHERE s.Controlador = 'Reporte'
ORDER BY s.Orden;
GO

-- ─── 3. Verificar permisos del submenú Rentabilidad ─────────────────────────
PRINT '════ 3. Permisos asignados a Rentabilidad (CPP) ════';
SELECT
    r.Descripcion   AS Rol,
    s.Nombre        AS Submenu,
    p.Activo
FROM dbo.PERMISOS  p
INNER JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE s.Controlador = 'Reporte' AND s.Vista = 'Rentabilidad';
GO

-- ─── 4. Probar usp_rptRentabilidadProducto ───────────────────────────────────
PRINT '════ 4. Prueba del SP Rentabilidad ════';
EXEC dbo.usp_rptRentabilidadProducto
    @IdTienda    = 0,
    @FechaInicio = '2026-01-01',
    @FechaFin    = '2026-12-31',
    @IdCategoria = 0;
GO

-- ─── 5. Fix: si el submenú no tiene menú padre, corregir ─────────────────────
PRINT '════ 5. Verificar menú padre del submenú Rentabilidad ════';
SELECT
    m.IdMenu,
    m.Nombre    AS NombreMenu,
    s.IdSubMenu,
    s.Nombre    AS NombreSubmenu
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE s.Controlador = 'Reporte' AND s.Vista = 'Rentabilidad';
GO

PRINT '════ Verificación completada ════';
GO
