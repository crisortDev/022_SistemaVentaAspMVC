-- ============================================================
--  Script 74 — Renombrar submenú "Gestión de NC" → "Registrar NC"
--  Motivo: petición del tutor — el nombre debe reflejar la acción
--          de registrar el documento físico del proveedor.
-- ============================================================
USE [DBVENTAS_WEB]
GO

-- ── 1. Renombrar el submenú ───────────────────────────────────
UPDATE dbo.SUBMENU
SET    Nombre = 'Registrar NC'
WHERE  Nombre = 'Gestión de NC'
   AND Activo = 1;

PRINT 'OK: Submenú renombrado a "Registrar NC". Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ── 2. Verificación ──────────────────────────────────────────
SELECT s.IdSubMenu, s.Nombre, s.Activo, m.Nombre AS Menu
FROM   dbo.SUBMENU s
JOIN   dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE  s.Nombre IN ('Registrar NC', 'Gestión de NC');
GO
