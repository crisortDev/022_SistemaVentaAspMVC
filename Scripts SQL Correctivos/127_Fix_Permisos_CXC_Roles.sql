-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 127: Corregir permisos CXC para SuperAdmin, Admin y Supervisor
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- Habilita el submenú "Cuentas por Cobrar" para los roles que deben verlo:
--   IdRol  1 = Administrador
--   IdRol  4 = Cajero        (ya habilitado en script 126)
--   IdRol 11 = Supervisor
--   IdRol 14 = SuperAdmin    (mostraba Bloqueado pese a tener acceso por AuthorizeRol)
--
-- Nota: Repositor (7) se mantiene bloqueado (no maneja cobros).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

DECLARE @IdSubMenuCXC INT;
SELECT  @IdSubMenuCXC = IdSubMenu
FROM    dbo.SUBMENU
WHERE   Controlador = 'ComprobanteCobro'
  AND   Nombre      = 'Cuentas por Cobrar';

IF @IdSubMenuCXC IS NULL
BEGIN
    PRINT 'ERROR: Submenú "Cuentas por Cobrar" no encontrado.';
    RETURN;
END

-- UPSERT para cada rol que debe tener acceso
;WITH roles AS (
    SELECT IdRol FROM (VALUES (1),(4),(11),(14)) AS r(IdRol)
)
MERGE dbo.PERMISOS AS target
USING (SELECT r.IdRol, @IdSubMenuCXC AS IdSubMenu FROM roles r) AS src
   ON target.IdRol = src.IdRol AND target.IdSubMenu = src.IdSubMenu
WHEN MATCHED THEN
    UPDATE SET Activo = 1
WHEN NOT MATCHED THEN
    INSERT (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (src.IdRol, src.IdSubMenu, 1, GETDATE());

PRINT 'OK: Cuentas por Cobrar habilitado para Administrador (1), Cajero (4), Supervisor (11), SuperAdmin (14).';
GO

-- Verificación
SELECT
    r.Descripcion AS Rol,
    s.Nombre      AS Submenu,
    CASE p.Activo WHEN 1 THEN 'Habilitado' ELSE 'Bloqueado' END AS Estado
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
WHERE s.Controlador = 'ComprobanteCobro'
  AND s.Nombre      = 'Cuentas por Cobrar'
ORDER BY p.IdRol;

PRINT '════ Script 127 completado ════';
GO
