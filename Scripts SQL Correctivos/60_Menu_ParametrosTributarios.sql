-- ============================================================
-- Script 60: Menú — Parámetros Tributarios
-- Fecha: 2026-05-18
-- Corrección: columna Vista (no Accion), IdRol numérico
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── 1. Obtener IdMenu de "Configuración" (ya existe según Script 60 anterior) ─
DECLARE @IdMenuCfg INT;
SELECT TOP 1 @IdMenuCfg = IdMenu FROM dbo.MENU WHERE Nombre = 'Configuración';

IF @IdMenuCfg IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Activo)
    VALUES ('Configuración', 'fas fa-cogs', 1);
    SET @IdMenuCfg = SCOPE_IDENTITY();
    PRINT 'OK: Menú Configuración creado (IdMenu = ' + CAST(@IdMenuCfg AS VARCHAR) + ').';
END
ELSE
    PRINT 'INFO: Menú Configuración ya existía (IdMenu = ' + CAST(@IdMenuCfg AS VARCHAR) + ').';
GO

-- ── 2. Submenú: Parámetros Tributarios ───────────────────────────────────────
DECLARE @IdMenuCfg  INT;
DECLARE @IdSubMenu  INT;

SELECT TOP 1 @IdMenuCfg = IdMenu FROM dbo.MENU WHERE Nombre = 'Configuración';

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE Controlador = 'ParametrosTributarios' AND Vista = 'Index'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuCfg, 'Parámetros Tributarios', 'ParametrosTributarios', 'Index',
            'fas fa-file-invoice', 10, 1);
    SET @IdSubMenu = SCOPE_IDENTITY();
    PRINT 'OK: Submenú Parámetros Tributarios creado (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU
    WHERE Controlador = 'ParametrosTributarios' AND Vista = 'Index';
    PRINT 'INFO: Submenú ya existía (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
GO

-- ── 3. Permisos — rol SuperAdmin (IdRol 14, igual que CajaVenta) ──────────────
DECLARE @IdSubMenu INT;
SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'ParametrosTributarios' AND Vista = 'Index';

-- Roles con acceso: 14 = SuperAdmin (ajustar si tu BD usa otro id)
-- Para ver tus roles: SELECT IdRol, Nombre FROM dbo.ROL
DECLARE @Roles TABLE (IdRol INT);
INSERT INTO @Roles VALUES (14);

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSubMenu, 1, GETDATE()
FROM   @Roles r
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSubMenu
);

PRINT 'OK: Permisos asignados. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
SELECT r.Nombre AS Rol, s.Nombre AS Submenu, s.Controlador, s.Vista, s.Icono
FROM   dbo.SUBMENU  s
INNER  JOIN dbo.MENU     m ON m.IdMenu    = s.IdMenu
LEFT   JOIN dbo.PERMISOS p ON p.IdSubmenu = s.IdSubmenu
LEFT   JOIN dbo.ROL      r ON r.IdRol     = p.IdRol
WHERE  s.Controlador = 'ParametrosTributarios';
GO
PRINT '════ Script 60 completado ════';
GO
