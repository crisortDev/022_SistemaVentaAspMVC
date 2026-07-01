-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 50: Corregir permisos del rol Cajero (IdRol = 4)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
--
-- El Cajero tenía acceso a Seguridad completa y Configuración completa,
-- lo que viola la segregación de funciones.
-- El Cajero debe operar solo en: Ventas, módulos propios de caja, y
-- consultas de inventario/reportes de ventas que necesite en su trabajo diario.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── VER estado actual (para referencia) ─────────────────────────────────────
SELECT s.IdSubMenu, m.Nombre AS Menu, s.Nombre AS Submenu, p.Activo
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER JOIN dbo.MENU    m ON m.IdMenu    = s.IdMenu
WHERE p.IdRol = 4 AND p.Activo = 1
ORDER BY m.Nombre, s.Nombre;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: Quitar acceso a SEGURIDAD
--   IdSubMenu 1 = Rol
--   IdSubMenu 2 = Asignar Permisos
--   IdSubMenu 3 = Usuarios
-- ════════════════════════════════════════════════════════════════════════════════
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 4 AND IdSubMenu IN (1, 2, 3);

PRINT 'OK: Seguridad (Rol, Permisos, Usuarios) quitado al Cajero.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: Quitar acceso a CONFIGURACIÓN
--   IdSubMenu 4  = Categorias
--   IdSubMenu 5  = Productos
--   IdSubMenu 18 = Precios y Vigencia
--   IdSubMenu 21 = Persona
--   IdSubMenu 22 = Empleados
--   IdSubMenu 23 = Motivo de Baja
-- ════════════════════════════════════════════════════════════════════════════════
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 4 AND IdSubMenu IN (4, 5, 18, 21, 22, 23);

PRINT 'OK: Configuración completa quitada al Cajero.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3: Quitar acceso a COMPRAS (el Cajero no gestiona compras a proveedores)
--   IdSubMenu 8  = Asignar producto a Tienda
--   IdSubMenu 9  = Registrar Compra
--   IdSubMenu 10 = Consultar Compra
--   IdSubMenu 29 = Registrar Orden Compra
--   IdSubMenu 30 = Consultar Orden Compra
--   IdSubMenu 32 = Anular Orden Compra
--   IdSubMenu 33 = Recepción de Compra
-- ════════════════════════════════════════════════════════════════════════════════
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 4 AND IdSubMenu IN (8, 9, 10, 29, 30, 32, 33);

PRINT 'OK: Compras completo quitado al Cajero.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 4: Quitar Inventario de movimientos (Cajero no hace traslados ni bajas)
--   IdSubMenu 26 = Traslado entre Tiendas
--   IdSubMenu 27 = Baja de Productos
--   IdSubMenu 28 = Stock por Tienda (este SÍ puede quedar — consulta)
-- ════════════════════════════════════════════════════════════════════════════════
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 4 AND IdSubMenu IN (26, 27);

PRINT 'OK: Traslado y Baja de Inventario quitados al Cajero.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 5: Quitar Caja Compra (es del lado de compras/finanzas, no del cajero)
--   IdSubMenu 16 = Caja Compra
-- ════════════════════════════════════════════════════════════════════════════════
UPDATE dbo.PERMISOS SET Activo = 0
WHERE IdRol = 4 AND IdSubMenu = 16;

PRINT 'OK: Caja Compra quitada al Cajero.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICAR resultado final — lo que QUEDA activo para el Cajero
-- ════════════════════════════════════════════════════════════════════════════════
SELECT s.IdSubMenu, m.Nombre AS Menu, s.Nombre AS Submenu
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER JOIN dbo.MENU    m ON m.IdMenu    = s.IdMenu
WHERE p.IdRol = 4 AND p.Activo = 1
ORDER BY m.Nombre, s.Nombre;
GO
