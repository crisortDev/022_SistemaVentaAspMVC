-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 122: Activar submenú "Registrar Venta Directa" (estaba inactivo)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- PROBLEMA:
--   El submenú 38 'Registrar Venta Directa' (Venta/Crear) tenía SUBMENU.Activo = 0.
--   El atributo AuthorizeRol arma el menú con submenús ACTIVOS; al estar inactivo,
--   ningún rol podía acceder a Venta/Facturar ni Venta/Crear → "Acceso denegado",
--   aunque el PERMISO del rol estuviera en 1.
--
-- FIX: activar el submenú 38. (Los submenús 12 y 13 son los viejos duplicados,
--   se dejan inactivos a propósito.)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

UPDATE dbo.SUBMENU
   SET Activo = 1
 WHERE IdSubMenu = 38
   AND Controlador = 'Venta' AND Nombre = 'Registrar Venta Directa';

PRINT 'OK: submenú 38 (Registrar Venta Directa) activado. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- Verificación: debe quedar Activo = 1
SELECT IdSubMenu, Nombre, Controlador, Vista, Activo
FROM dbo.SUBMENU
WHERE Controlador = 'Venta'
ORDER BY IdSubMenu;
GO
