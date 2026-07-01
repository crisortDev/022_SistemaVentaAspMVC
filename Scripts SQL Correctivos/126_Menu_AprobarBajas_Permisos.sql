-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 126: Submenú "Aprobar Bajas" + permisos (Inventario, Etapa 1)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
--
-- Crea el submenú "Aprobar Bajas" (Controlador=Inventario, Vista=AprobarBajas)
-- y le asigna permiso a: Encargado(6), Supervisor(11), Administrador(1), SuperAdmin(14).
-- El que carga la baja (Repositor/Cajero) NO aprueba (segregación).
--
-- Idempotente. Busca el IdMenu de Inventario por sus submenús existentes.
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

DECLARE @IdMenu INT;

-- Buscar el menú al que pertenecen los submenús de Inventario
SELECT TOP 1 @IdMenu = IdMenu FROM dbo.SUBMENU WHERE Controlador = 'Inventario' AND IdMenu IS NOT NULL;

IF @IdMenu IS NULL
BEGIN
    -- Si no hay submenús de Inventario aún, intentar por nombre del menú
    SELECT TOP 1 @IdMenu = IdMenu FROM dbo.MENU WHERE Nombre LIKE '%nventario%';
END

IF @IdMenu IS NULL
BEGIN
    PRINT 'ERROR: no se encontró el menú de Inventario. Verificá la tabla MENU/SUBMENU.';
    RETURN;
END

PRINT 'IdMenu Inventario = ' + CAST(@IdMenu AS VARCHAR);

-- Crear submenú "Aprobar Bajas" si no existe
DECLARE @IdSm INT;
SELECT @IdSm = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'Inventario' AND Vista = 'AprobarBajas';

IF @IdSm IS NULL
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenu, 'Aprobar Bajas', 'Inventario', 'AprobarBajas', 'fas fa-clipboard-check', 50, 1);
    SET @IdSm = SCOPE_IDENTITY();
    PRINT 'OK: submenú "Aprobar Bajas" creado (IdSubMenu=' + CAST(@IdSm AS VARCHAR) + ').';
END
ELSE
BEGIN
    UPDATE dbo.SUBMENU SET Activo = 1, Nombre = 'Aprobar Bajas' WHERE IdSubMenu = @IdSm;
    PRINT 'INFO: submenú "Aprobar Bajas" ya existía (IdSubMenu=' + CAST(@IdSm AS VARCHAR) + '), reactivado.';
END

-- Permisos: Encargado(6), Supervisor(11), Administrador(1), SuperAdmin(14)
DECLARE @roles TABLE (IdRol INT);
INSERT INTO @roles VALUES (6),(11),(1),(14);

UPDATE p SET p.Activo = 1
FROM dbo.PERMISOS p JOIN @roles r ON r.IdRol = p.IdRol AND p.IdSubMenu = @IdSm;

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSm, 1, GETDATE()
FROM @roles r
WHERE NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = r.IdRol AND p.IdSubMenu = @IdSm);

PRINT 'OK: permisos de "Aprobar Bajas" asignados (Encargado, Supervisor, Admin, SuperAdmin).';
GO

-- Verificación
SELECT s.IdSubMenu, s.Nombre, s.Controlador, s.Vista, s.Activo,
       r.Descripcion AS Rol, p.Activo AS Permiso
FROM dbo.SUBMENU s
LEFT JOIN dbo.PERMISOS p ON p.IdSubMenu = s.IdSubMenu
LEFT JOIN dbo.ROL r ON r.IdRol = p.IdRol
WHERE s.Controlador = 'Inventario' AND s.Vista = 'AprobarBajas'
ORDER BY r.IdRol;
GO

PRINT '════ Script 126 completado ════';
GO
