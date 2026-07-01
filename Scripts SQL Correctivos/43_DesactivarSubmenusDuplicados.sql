-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 43: Desactivar submenús duplicados del módulo Ventas
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-12
--
-- Los submenús originales "Registrar Venta" y "Consultar Venta" apuntan a las
-- mismas URLs que los nuevos "Registrar Venta Directa" y "Consultar Ventas".
-- Se desactivan los originales para evitar duplicados en el menú.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

UPDATE dbo.SUBMENU
SET Activo = 0
WHERE Nombre IN ('Registrar Venta', 'Consultar Venta')
  AND Controlador = 'Venta';

PRINT 'OK: Submenús duplicados "Registrar Venta" y "Consultar Venta" desactivados.';
GO

-- Verificar estado actual del menú Ventas
SELECT s.IdSubMenu, s.Nombre, s.Controlador, s.Vista, s.Activo
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE m.Nombre IN ('Venta','Ventas')
ORDER BY s.Orden, s.IdSubMenu;
GO
