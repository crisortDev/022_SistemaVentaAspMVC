-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 55: Registrar CajaVenta en MENU / SUBMENU y asignar PERMISOS
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
--
-- Agrega "Caja de Ventas" al menú Caja y otorga acceso a:
--   IdRol  4 = Cajero
--   IdRol  7 = Encargado / Supervisor
--   IdRol 14 = SuperAdmin
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── Obtener o crear el menú Caja ──────────────────────────────────────────────
DECLARE @IdMenuCaja INT;
SELECT  @IdMenuCaja = IdMenu
FROM    dbo.MENU
WHERE   Nombre IN ('Caja', 'ConsultarCajaCompra');

IF @IdMenuCaja IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Activo)
    VALUES ('Caja', 'fa-cash-register', 1);
    SET @IdMenuCaja = SCOPE_IDENTITY();
    PRINT 'OK: Menú Caja creado (IdMenu = ' + CAST(@IdMenuCaja AS VARCHAR) + ').';
END
ELSE
    PRINT 'INFO: Menú Caja ya existía (IdMenu = ' + CAST(@IdMenuCaja AS VARCHAR) + ').';

-- ── Insertar submenu CajaVenta si no existe ───────────────────────────────────
DECLARE @IdSubMenu INT;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE  Controlador = 'CajaVenta' AND Nombre = 'Caja de Ventas'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuCaja, 'Caja de Ventas', 'CajaVenta', 'Index', 'fa-cash-register', 2, 1);
    SET @IdSubMenu = SCOPE_IDENTITY();
    PRINT 'OK: Submenu "Caja de Ventas" creado (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSubMenu = IdSubMenu
    FROM   dbo.SUBMENU
    WHERE  Controlador = 'CajaVenta' AND Nombre = 'Caja de Ventas';
    PRINT 'INFO: Submenu ya existía (IdSubMenu = ' + CAST(@IdSubMenu AS VARCHAR) + ').';
END
GO

-- ── Asignar permisos a los roles que usan la caja ────────────────────────────
DECLARE @IdSubMenu INT;
SELECT  @IdSubMenu = IdSubMenu
FROM    dbo.SUBMENU
WHERE   Controlador = 'CajaVenta' AND Nombre = 'Caja de Ventas';

-- Roles: 4 = Cajero, 7 = Encargado/Supervisor, 14 = SuperAdmin
-- Ajustá los IdRol si en tu BD tienen IDs distintos
DECLARE @Roles TABLE (IdRol INT);
INSERT INTO @Roles VALUES (4), (7), (14);

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSubMenu, 1, GETDATE()
FROM   @Roles r
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSubMenu
);

PRINT 'OK: Permisos asignados. Filas insertadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
SELECT r.Nombre AS Rol, s.Nombre AS Submenu, p.Activo
FROM   dbo.PERMISOS p
INNER  JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
INNER  JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE  s.Controlador = 'CajaVenta'
ORDER  BY r.Nombre;
GO
