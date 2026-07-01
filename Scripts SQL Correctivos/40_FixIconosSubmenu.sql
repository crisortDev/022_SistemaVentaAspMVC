-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 40: Corregir iconos de submenús del módulo Ventas
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-12
--
-- Problema: Los submenús insertados en 38c/38c_fix tienen iconos sin prefijo 'fas'
--   Ejemplo: 'fa-bolt'  →  debe ser 'fas fa-bolt'
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

UPDATE dbo.SUBMENU SET Icono = 'fas fa-bolt'           WHERE Icono = 'fa-bolt';
UPDATE dbo.SUBMENU SET Icono = 'fas fa-list'           WHERE Icono = 'fa-list';
UPDATE dbo.SUBMENU SET Icono = 'fas fa-clipboard-list' WHERE Icono = 'fa-clipboard-list';
UPDATE dbo.SUBMENU SET Icono = 'fas fa-file-invoice'   WHERE Icono = 'fa-file-invoice';
UPDATE dbo.SUBMENU SET Icono = 'fas fa-file-contract'  WHERE Icono = 'fa-file-contract';
UPDATE dbo.SUBMENU SET Icono = 'fas fa-receipt'        WHERE Icono = 'fa-receipt';

PRINT 'OK: Iconos de submenús corregidos.';
GO

-- Verificar resultado
SELECT IdSubMenu, IdMenu, Nombre, Icono FROM dbo.SUBMENU ORDER BY IdMenu, Orden;
GO
