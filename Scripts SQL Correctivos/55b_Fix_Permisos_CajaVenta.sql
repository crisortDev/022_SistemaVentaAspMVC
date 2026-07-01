-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 55b: Insertar permisos de CajaVenta y verificar resultado
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- Verificar que el submenu existe
SELECT IdSubMenu, Nombre, Controlador FROM dbo.SUBMENU WHERE Controlador = 'CajaVenta';
GO

-- Insertar permiso para cada rol si no existe
-- IdRol 4  = Cajero
-- IdRol 7  = Encargado/Supervisor
-- IdRol 14 = SuperAdmin

DECLARE @IdSubMenu INT;
SELECT @IdSubMenu = IdSubMenu FROM dbo.SUBMENU WHERE Controlador = 'CajaVenta';

PRINT 'IdSubMenu obtenido: ' + ISNULL(CAST(@IdSubMenu AS VARCHAR), 'NULL');

IF @IdSubMenu IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el submenu CajaVenta. Verificá que el Script 55 se ejecutó correctamente.';
    RETURN;
END

-- Insertar para Cajero (IdRol = 4)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 4 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (4, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso Cajero (IdRol=4) insertado.';
END
ELSE
    PRINT 'INFO: Cajero ya tenía permiso.';

-- Insertar para Encargado/Supervisor (IdRol = 7)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (7, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso Encargado (IdRol=7) insertado.';
END
ELSE
    PRINT 'INFO: Encargado ya tenía permiso.';

-- Insertar para SuperAdmin (IdRol = 14)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 14 AND IdSubMenu = @IdSubMenu)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (14, @IdSubMenu, 1, GETDATE());
    PRINT 'OK: Permiso SuperAdmin (IdRol=14) insertado.';
END
ELSE
    PRINT 'INFO: SuperAdmin ya tenía permiso.';
GO

-- Verificación final
SELECT r.Descripcion AS Rol, s.Nombre AS Submenu, p.Activo
FROM   dbo.PERMISOS p
INNER  JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
INNER  JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE  s.Controlador = 'CajaVenta'
ORDER  BY r.Descripcion;
GO
