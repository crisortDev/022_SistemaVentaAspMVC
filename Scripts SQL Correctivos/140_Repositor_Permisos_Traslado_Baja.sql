-- ════════════════════════════════════════════════════════════════════════════════
-- Script 140 — Dar permiso a Repositor (IdRol=7) en Traslado y Baja
-- ════════════════════════════════════════════════════════════════════════════════
USE [DBVENTAS_WEB]
GO

DECLARE @IdTraslado INT, @IdBaja INT;

SELECT @IdTraslado = IdSubMenu FROM dbo.SUBMENU WHERE Controlador = 'Inventario' AND Vista = 'Traslado';
SELECT @IdBaja     = IdSubMenu FROM dbo.SUBMENU WHERE Controlador = 'Inventario' AND Vista = 'Baja';

IF @IdTraslado IS NULL BEGIN PRINT 'ERROR: Submenu Traslado no encontrado.'; RETURN; END
IF @IdBaja     IS NULL BEGIN PRINT 'ERROR: Submenu Baja no encontrado.'; RETURN; END

PRINT 'IdSubMenu Traslado = ' + CAST(@IdTraslado AS VARCHAR);
PRINT 'IdSubMenu Baja     = ' + CAST(@IdBaja     AS VARCHAR);

-- Repositor (7) en Traslado
IF EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdTraslado)
    UPDATE dbo.PERMISOS SET Activo = 1 WHERE IdRol = 7 AND IdSubMenu = @IdTraslado;
ELSE
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (7, @IdTraslado, 1, GETDATE());
PRINT 'OK: Repositor — permiso Traslado activado.';

-- Repositor (7) en Baja
IF EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdBaja)
    UPDATE dbo.PERMISOS SET Activo = 1 WHERE IdRol = 7 AND IdSubMenu = @IdBaja;
ELSE
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (7, @IdBaja, 1, GETDATE());
PRINT 'OK: Repositor — permiso Baja activado.';

-- Verificación
SELECT s.Nombre AS Submenu, r.Descripcion AS Rol, p.Activo
FROM dbo.SUBMENU s
JOIN dbo.PERMISOS p ON p.IdSubMenu = s.IdSubMenu
JOIN dbo.ROL r      ON r.IdRol     = p.IdRol
WHERE s.IdSubMenu IN (@IdTraslado, @IdBaja)
  AND p.Activo = 1
ORDER BY s.Nombre, r.IdRol;
GO

PRINT '════ Script 140 completado ════';
GO
