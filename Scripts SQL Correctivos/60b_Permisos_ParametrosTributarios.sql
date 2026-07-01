-- ============================================================
-- Script 60b: Permisos — Parámetros Tributarios
-- Fecha: 2026-05-18
-- Corrección: usa Descripcion (no Nombre) en ROL, inserts explícitos
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- Ver roles disponibles (para confirmar IdRol del SuperAdmin)
SELECT IdRol, Descripcion FROM dbo.ROL ORDER BY IdRol;
GO

-- Ver el submenú recién creado
SELECT IdSubMenu, Nombre, Controlador, Vista FROM dbo.SUBMENU
WHERE Controlador = 'ParametrosTributarios';
GO

-- ── Asignar permisos ──────────────────────────────────────────────────────────
DECLARE @IdSubMenu INT;
SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'ParametrosTributarios' AND Vista = 'Index';

PRINT 'IdSubMenu: ' + ISNULL(CAST(@IdSubMenu AS VARCHAR), 'NULL');

IF @IdSubMenu IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el submenú. Verificá que el Script 60 se ejecutó.';
    RETURN;
END

-- SuperAdmin (IdRol = 14)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 14 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (14, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso SuperAdmin (IdRol=14) insertado.';
END
ELSE
    PRINT 'INFO: SuperAdmin ya tenía permiso.';
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
SELECT r.Descripcion AS Rol, s.Nombre AS Submenu, s.Vista, p.Activo
FROM   dbo.PERMISOS p
INNER  JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
INNER  JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE  s.Controlador = 'ParametrosTributarios';
GO
PRINT '════ Script 60b completado ════';
GO
