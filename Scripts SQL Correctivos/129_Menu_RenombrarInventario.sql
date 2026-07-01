-- ════════════════════════════════════════════════════════════════════
-- SCRIPT 129: Renombrar menú 'Inventario' → 'Control de Inventario'
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
-- ════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

UPDATE dbo.MENU
   SET Nombre = 'Control de Inventario'
 WHERE Nombre = 'Inventario';

PRINT 'OK: Menú renombrado a ''Control de Inventario''. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO
