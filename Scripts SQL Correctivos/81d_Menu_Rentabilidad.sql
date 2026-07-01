-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 81d: Crear submenú Rentabilidad (CPP) y asignar permisos
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
-- ════════════════════════════════════════════════════════════════════════════════
USE [DBVENTAS_WEB]
GO

DECLARE @IdMenuRpt  INT;
DECLARE @IdSmRent   INT;
DECLARE @NombreMenu VARCHAR(100);

-- Obtener IdMenu del módulo Reporte desde los submenús que ya existen
SELECT TOP 1
    @IdMenuRpt  = s.IdMenu,
    @NombreMenu = m.Nombre
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE s.Controlador = 'Reporte';

IF @IdMenuRpt IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el menú padre para el controlador Reporte.';
    RETURN;
END

PRINT 'Menú encontrado: IdMenu=' + CAST(@IdMenuRpt AS VARCHAR) + ', Nombre=' + @NombreMenu;

-- Crear submenú si no existe
IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE Controlador = 'Reporte' AND Vista = 'Rentabilidad'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuRpt, 'Rentabilidad (CPP)', 'Reporte', 'Rentabilidad', 'fas fa-chart-line', 35, 1);

    SET @IdSmRent = SCOPE_IDENTITY();
    PRINT 'OK: Submenú creado. IdSubMenu=' + CAST(@IdSmRent AS VARCHAR);
END
ELSE
BEGIN
    SELECT @IdSmRent = IdSubMenu
    FROM dbo.SUBMENU
    WHERE Controlador = 'Reporte' AND Vista = 'Rentabilidad';

    PRINT 'INFO: Submenú ya existía. IdSubMenu=' + CAST(@IdSmRent AS VARCHAR);
END

-- Asignar permisos (roles 1, 6, 11, 14)
INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSmRent, 1, GETDATE()
FROM (VALUES (1),(6),(11),(14)) AS r(IdRol)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmRent
);

PRINT 'OK: Permisos asignados (' + CAST(@@ROWCOUNT AS VARCHAR) + ' roles nuevos).';

-- Verificación final
SELECT
    m.Nombre    AS Menu,
    s.IdSubMenu,
    s.Nombre    AS Submenu,
    s.Vista,
    s.Activo
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE s.Controlador = 'Reporte'
ORDER BY s.Orden;

SELECT
    r.Descripcion AS Rol,
    s.Nombre      AS Submenu
FROM dbo.PERMISOS  p
INNER JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE s.Controlador = 'Reporte' AND s.Vista = 'Rentabilidad';
GO

PRINT '════ Script 81d completado ════';
GO
