-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 34: Registrar submenú "Gestión de NC" bajo el menú principal de Compras
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- El menú es dinámico (cargado en sesión al login).
-- Este script agrega la entrada de SUBMENU para que los roles autorizados
-- puedan acceder a NotaCredito/Index desde el menú de navegación.
-- Ejecutar UNA SOLA VEZ.  La instrucción IF NOT EXISTS lo hace idempotente.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Verificar IdMenu del grupo "Compras" ────────────────────────────────────
--    Si tu menú principal de compras tiene un nombre distinto, ajustá la
--    condición WHERE.  Para ver todos los menús disponibles:
--    SELECT IdMenu, Nombre FROM dbo.MENU ORDER BY Nombre;
DECLARE @IdMenuCompras INT;
SELECT @IdMenuCompras = IdMenu
  FROM dbo.MENU
 WHERE Nombre LIKE '%Compra%'
    OR Nombre LIKE '%compra%'
 ORDER BY IdMenu
 OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

IF @IdMenuCompras IS NULL
BEGIN
    PRINT 'ADVERTENCIA: No se encontró el menú de Compras. Verificá la tabla MENU.';
    PRINT 'Usá: SELECT IdMenu, Nombre FROM dbo.MENU ORDER BY Nombre;';
    RETURN;
END

PRINT 'IdMenu Compras = ' + CAST(@IdMenuCompras AS VARCHAR);

-- ── 2. Insertar SUBMENU si no existe ──────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
     WHERE Controlador = 'NotaCredito'
       AND Vista       = 'Index'
)
BEGIN
    INSERT INTO dbo.SUBMENU
        (IdMenu, Nombre, Controlador, Vista, Icono, Activo, Orden)
    VALUES
        (@IdMenuCompras,
         'Gestión de NC',           -- texto que aparece en el menú y en AuthorizeRol
         'NotaCredito',             -- debe coincidir con el nombre del Controller (sin "Controller")
         'Index',                   -- nombre de la acción / vista
         'fas fa-file-invoice-dollar',
         1,
         99);                       -- orden al final de las opciones de Compras

    PRINT 'OK: Submenú "Gestión de NC" creado.';
END
ELSE
    PRINT 'INFO: Submenú "Gestión de NC" ya existe.';
GO

-- ── 3. Asignar el submenú al ROL SuperAdmin (por si usa tabla de permisos) ─────
--    Si los permisos se manejan por rol, ejecutar algo similar:
--
--  DECLARE @IdSub INT;
--  SELECT @IdSub = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='NotaCredito' AND Vista='Index';
--
--  INSERT INTO dbo.ROL_PERMISO (IdRol, IdSubMenu)
--  SELECT 14, @IdSub   -- IdRol 14 = SuperAdmin
--  WHERE NOT EXISTS (SELECT 1 FROM dbo.ROL_PERMISO WHERE IdRol=14 AND IdSubMenu=@IdSub);
--
--  PRINT 'OK: Permiso asignado a SuperAdmin.';

-- ── 4. Verificar resultado ─────────────────────────────────────────────────────
SELECT sm.IdSubMenu, sm.Nombre, sm.Controlador, sm.Vista, sm.Icono, sm.Activo
  FROM dbo.SUBMENU sm
 WHERE sm.IdMenu = @IdMenuCompras
 ORDER BY ISNULL(sm.Orden, 999), sm.Nombre;
GO

PRINT '════════════════════════════════════════════════════════';
PRINT 'Script 34 completado.';
PRINT 'Reiniciar sesión en la app para ver el nuevo menú.';
PRINT '════════════════════════════════════════════════════════';
GO
