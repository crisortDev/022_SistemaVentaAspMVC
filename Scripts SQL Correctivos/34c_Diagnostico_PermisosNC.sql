-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 34c: Diagnóstico y fix de permisos para el submenú "Gestión de NC"
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Ver el submenú recién creado ──────────────────────────────────────────
SELECT sm.IdSubMenu, sm.Nombre, sm.Controlador, sm.Vista, sm.Icono, sm.Activo,
       m.Nombre AS MenuPadre
  FROM dbo.SUBMENU sm
  JOIN dbo.MENU    m ON m.IdMenu = sm.IdMenu
 WHERE sm.Controlador = 'NotaCredito';
GO

-- ── 2. Ver la tabla PERMISOS para confirmar su estructura ────────────────────
SELECT TOP 5 * FROM dbo.PERMISOS ORDER BY IdPermisos DESC;
GO

-- ── 3. Ver roles disponibles ─────────────────────────────────────────────────
SELECT IdRol, Descripcion, Activo FROM dbo.ROL ORDER BY IdRol;
GO

-- ── 4. Ver si ya existe algún permiso para el submenú NC ─────────────────────
SELECT p.IdPermisos, p.IdRol, r.Descripcion AS Rol,
       p.IdSubMenu, sm.Nombre AS SubMenu, p.Activo
  FROM dbo.PERMISOS p
  JOIN dbo.ROL     r  ON r.IdRol    = p.IdRol
  JOIN dbo.SUBMENU sm ON sm.IdSubMenu = p.IdSubMenu
 WHERE sm.Controlador = 'NotaCredito';
GO

-- ── 5. Agregar permiso al rol SuperAdmin (IdRol=14) si no existe ─────────────
DECLARE @IdSubNC INT;
SELECT @IdSubNC = IdSubMenu FROM dbo.SUBMENU
 WHERE Controlador = 'NotaCredito' AND Vista = 'Index';

IF @IdSubNC IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el submenú NotaCredito/Index en SUBMENU.';
    RETURN;
END

PRINT 'IdSubMenu NC = ' + CAST(@IdSubNC AS VARCHAR);

-- Agregar para TODOS los roles que ya tienen al menos un permiso en Compras
-- (para que los roles que usan compras vean también NC)
INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT DISTINCT p.IdRol, @IdSubNC, 1, GETDATE()
  FROM dbo.PERMISOS p
  JOIN dbo.SUBMENU  sm ON sm.IdSubMenu = p.IdSubMenu
 WHERE sm.IdMenu = (SELECT IdMenu FROM dbo.SUBMENU WHERE Controlador='NotaCredito' AND Vista='Index')
   AND p.Activo = 1
   AND NOT EXISTS (
       SELECT 1 FROM dbo.PERMISOS x
        WHERE x.IdRol = p.IdRol AND x.IdSubMenu = @IdSubNC
   );

PRINT 'OK: Permisos agregados a roles que ya tienen acceso al menú de Compras.';

-- Ver resultado final
SELECT p.IdPermisos, p.IdRol, r.Descripcion AS Rol,
       p.IdSubMenu, sm.Nombre AS SubMenu, p.Activo
  FROM dbo.PERMISOS p
  JOIN dbo.ROL     r  ON r.IdRol     = p.IdRol
  JOIN dbo.SUBMENU sm ON sm.IdSubMenu = p.IdSubMenu
 WHERE sm.Controlador = 'NotaCredito'
 ORDER BY p.IdRol;
GO
