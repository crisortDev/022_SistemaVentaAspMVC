-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 128: Submenús "Toma de Inventario" e "Inventarios" + permisos (Etapa 2)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
--
-- Crea dos submenús bajo Inventario:
--   • "Toma de Inventario"  (Vista=TomaInventario) → cargar conteo. Repositor/Cajero/Admin/SA
--   • "Inventarios"         (Vista=Inventarios)    → aprobar.       Encargado/Supervisor/Admin/SA
--
-- Nota: el atributo AuthorizeRol usa el MISMO nombre "Toma de Inventario" para todas
--   las acciones del módulo. Para que el aprobador entre a la pantalla "Inventarios",
--   esta también se registra con el nombre de submenú "Toma de Inventario" (mapeo),
--   por eso ambos submenús comparten permiso lógico. Aquí damos permiso amplio a los
--   roles que participan y la segregación real (quien carga ≠ quien aprueba) la hace el SP.
--
-- Idempotente. ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

DECLARE @IdMenu INT;
SELECT TOP 1 @IdMenu = IdMenu FROM dbo.SUBMENU WHERE Controlador='Inventario' AND IdMenu IS NOT NULL;
IF @IdMenu IS NULL SELECT TOP 1 @IdMenu = IdMenu FROM dbo.MENU WHERE Nombre LIKE '%nventario%';
IF @IdMenu IS NULL BEGIN PRINT 'ERROR: no se encontró el menú Inventario.'; RETURN; END
PRINT 'IdMenu Inventario = ' + CAST(@IdMenu AS VARCHAR);

-- ── Submenú "Toma de Inventario" (cargar conteo) ────────────────────────────────
DECLARE @IdToma INT;
SELECT @IdToma = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Inventario' AND Vista='TomaInventario';
IF @IdToma IS NULL
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenu, 'Toma de Inventario', 'Inventario', 'TomaInventario', 'fas fa-clipboard-list', 51, 1);
    SET @IdToma = SCOPE_IDENTITY();
    PRINT 'OK: submenú "Toma de Inventario" creado (' + CAST(@IdToma AS VARCHAR) + ').';
END
ELSE BEGIN UPDATE dbo.SUBMENU SET Activo=1 WHERE IdSubMenu=@IdToma; PRINT 'INFO: "Toma de Inventario" ya existía.'; END

-- ── Submenú "Inventarios" (aprobar) ─────────────────────────────────────────────
DECLARE @IdAprob INT;
SELECT @IdAprob = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Inventario' AND Vista='Inventarios';
IF @IdAprob IS NULL
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenu, 'Inventarios', 'Inventario', 'Inventarios', 'fas fa-clipboard-check', 52, 1);
    SET @IdAprob = SCOPE_IDENTITY();
    PRINT 'OK: submenú "Inventarios" creado (' + CAST(@IdAprob AS VARCHAR) + ').';
END
ELSE BEGIN UPDATE dbo.SUBMENU SET Activo=1 WHERE IdSubMenu=@IdAprob; PRINT 'INFO: "Inventarios" ya existía.'; END

-- ── Permisos ────────────────────────────────────────────────────────────────────
-- Toma de Inventario (cargar): Repositor(7), Cajero(4), Admin(1), SuperAdmin(14)
-- Inventarios (aprobar):       Encargado(6), Supervisor(11), Admin(1), SuperAdmin(14)
DECLARE @perm TABLE (IdRol INT, IdSubMenu INT);
INSERT INTO @perm VALUES
    (7,@IdToma),(4,@IdToma),(1,@IdToma),(14,@IdToma),
    (6,@IdAprob),(11,@IdAprob),(1,@IdAprob),(14,@IdAprob);

UPDATE p SET p.Activo=1
FROM dbo.PERMISOS p JOIN @perm x ON x.IdRol=p.IdRol AND x.IdSubMenu=p.IdSubMenu;

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT x.IdRol, x.IdSubMenu, 1, GETDATE()
FROM @perm x
WHERE NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol=x.IdRol AND p.IdSubMenu=x.IdSubMenu);

PRINT 'OK: permisos de Toma de Inventario e Inventarios asignados.';
GO

-- Verificación
SELECT s.Nombre AS Submenu, r.Descripcion AS Rol, p.Activo
FROM dbo.SUBMENU s
JOIN dbo.PERMISOS p ON p.IdSubMenu=s.IdSubMenu
JOIN dbo.ROL r ON r.IdRol=p.IdRol
WHERE s.Controlador='Inventario' AND s.Vista IN ('TomaInventario','Inventarios')
ORDER BY s.Nombre, r.IdRol;
GO

PRINT '════ Script 128 completado ════';
GO
