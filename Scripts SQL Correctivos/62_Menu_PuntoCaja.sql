-- ============================================================
-- Script 62: Menú — Gestión de Cajas (PuntoCaja)
-- Fecha: 2026-05-18
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── Obtener IdMenu de "Caja" ──────────────────────────────────────────────────
DECLARE @IdMenuCaja INT;
SELECT TOP 1 @IdMenuCaja = IdMenu FROM dbo.MENU WHERE Nombre IN ('Caja','ConsultarCajaCompra');

PRINT 'IdMenu Caja: ' + ISNULL(CAST(@IdMenuCaja AS VARCHAR), 'NULL');

-- ── Submenú: Gestión de Cajas ─────────────────────────────────────────────────
DECLARE @IdSubMenu INT;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE Controlador = 'PuntoCaja' AND Vista = 'Index'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuCaja, 'Gestión de Cajas', 'PuntoCaja', 'Index', 'fas fa-cash-register', 1, 1);
    SET @IdSubMenu = SCOPE_IDENTITY();
    PRINT 'OK: Submenú Gestión de Cajas creado (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU
    WHERE Controlador = 'PuntoCaja' AND Vista = 'Index';
    PRINT 'INFO: Submenú ya existía (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
GO

-- ── Permisos: SuperAdmin (14) + Encargado (7) ─────────────────────────────────
DECLARE @IdSubMenu INT;
SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'PuntoCaja' AND Vista = 'Index';

-- SuperAdmin
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 14 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (14, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso SuperAdmin (14) insertado.';
END
ELSE PRINT 'INFO: SuperAdmin ya tenía permiso.';

-- Encargado/Supervisor
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (7, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso Encargado (7) insertado.';
END
ELSE PRINT 'INFO: Encargado ya tenía permiso.';
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
SELECT r.Descripcion AS Rol, s.Nombre AS Submenu, s.Vista, m.Nombre AS Menu
FROM   dbo.SUBMENU  s
INNER  JOIN dbo.MENU     m ON m.IdMenu    = s.IdMenu
LEFT   JOIN dbo.PERMISOS p ON p.IdSubMenu = s.IdSubMenu
LEFT   JOIN dbo.ROL      r ON r.IdRol     = p.IdRol
WHERE  s.Controlador = 'PuntoCaja';
GO
PRINT '════ Script 62 completado ════';
GO
