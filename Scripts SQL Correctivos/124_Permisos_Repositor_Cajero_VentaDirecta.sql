-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 124: Permisos Repositor/Cajero + eliminar Registrar Venta Directa
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- Cambios:
--   A) Repositor (7): sin acceso a Compras, Configuración, Seguridad, Inventario
--   B) Repositor (7) + Cajero (4): Tiendas solo lectura (ya manejado en código)
--   C) Todos los roles: PERMISOS.Activo=0 para "Registrar Venta Directa"
--      (La facturación desde OV usa [AuthorizeRol("OrdenVenta","Consultar Pre-ventas")])
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── A1. Repositor (7) — bloquear módulo COMPRAS ────────────────────────────
-- (script 37 le daba: Registrar OC, Consultar OC, Registrar Compra, Consultar Compra)
UPDATE p SET p.Activo = 0
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE p.IdRol = 7
  AND s.Controlador IN (
      'OrdenCompra', 'Compra', 'NotaCredito',
      'ReporteGerencia', 'Proveedor'
  );
PRINT 'OK: Repositor — módulo Compras bloqueado.';
GO

-- ─── A2. Repositor (7) — bloquear módulo CONFIGURACIÓN ─────────────────────
-- Quita acceso a Categoría, Producto, Precios, etc.
-- (Tienda queda activa pero read-only vía código)
UPDATE p SET p.Activo = 0
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE p.IdRol = 7
  AND s.Controlador IN (
      'Categoria', 'Producto', 'ProductoTienda'
  );
PRINT 'OK: Repositor — módulo Configuración bloqueado.';
GO

-- ─── A3. Repositor (7) — bloquear módulo SEGURIDAD ─────────────────────────
UPDATE p SET p.Activo = 0
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE p.IdRol = 7
  AND s.Controlador IN ('Rol', 'Usuario', 'Permisos');
PRINT 'OK: Repositor — módulo Seguridad bloqueado.';
GO

-- ─── A4. Repositor (7) — bloquear módulo INVENTARIO ────────────────────────
-- Bloquea traslados, bajas e incluso Stock por Tienda
UPDATE p SET p.Activo = 0
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE p.IdRol = 7
  AND s.Controlador IN ('Inventario', 'Stock')
  AND s.Nombre NOT IN ('Consultar Ventas', 'Consultar Pre-ventas');  -- por si acaso
PRINT 'OK: Repositor — módulo Inventario bloqueado.';
GO

-- También por IdSubMenu fijo para subsistemas de inventario conocidos
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 7 AND IdSubMenu IN (26, 27, 28);  -- Traslado, Baja, Stock por Tienda
PRINT 'OK: Repositor — submenús de Inventario (26,27,28) bloqueados.';
GO

-- ─── C. Todos los roles: deshabilitar "Registrar Venta Directa" ─────────────
-- La facturación desde pre-venta se controla ahora por
-- [AuthorizeRol("OrdenVenta","Consultar Pre-ventas")] + check de rol en código.
UPDATE p SET p.Activo = 0
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE s.Controlador = 'Venta'
  AND s.Nombre      = 'Registrar Venta Directa';
PRINT 'OK: Registrar Venta Directa deshabilitado para todos los roles.';
GO

-- ─── Verificación ────────────────────────────────────────────────────────────
SELECT
    r.Descripcion AS Rol,
    m.Nombre      AS Menu,
    s.Nombre      AS Submenu,
    CASE p.Activo WHEN 1 THEN 'SI' ELSE 'NO' END AS Acceso
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER JOIN dbo.MENU    m ON m.IdMenu    = s.IdMenu
INNER JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
WHERE p.IdRol IN (4, 7)
ORDER BY r.Descripcion, m.Nombre, s.Nombre;

PRINT '════ Script 124 completado ════';
GO
