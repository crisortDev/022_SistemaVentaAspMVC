-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 78: Desactivar submenú "Registrar Venta Directa"
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- La venta directa queda desactivada del menú de navegación.
-- El código y el controlador permanecen intactos; solo se oculta el acceso.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

UPDATE dbo.SUBMENU
SET    Activo = 0
WHERE  Controlador = 'Venta'
  AND  Nombre      = 'Registrar Venta Directa';

PRINT 'OK: Submenú "Registrar Venta Directa" desactivado (' + CAST(@@ROWCOUNT AS VARCHAR) + ' fila/s).';
GO
