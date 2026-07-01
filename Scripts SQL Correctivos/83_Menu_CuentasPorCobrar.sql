-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 83: Menú Cuentas por Cobrar
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- Agrega el submenu "Cuentas por Cobrar" al menú "Caja".
-- Permisos:
--   IdRol 4  = CAJERO      → puede ver lista (no puede cobrar — lo hace el supervisor)
--   IdRol 7  = SUPERVISOR  → puede ver Y cobrar (solo su tienda — segregación en SP)
--   IdRol 14 = SUPERADMIN  → acceso completo todas las tiendas
--
-- NOTA: el rol CAJERO (IdRol=4) tiene acceso a la VISTA de cuentas por cobrar,
-- pero la acción "Cobrar" en el controller exige rol SUPERVISOR o ADMIN
-- mediante [AuthorizeRol("ComprobanteCobro","Cobrar")] — separar las acciones
-- en el AuthorizeRol para segregación de funciones.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Obtener IdMenu de "Caja" ───────────────────────────────────────────────
DECLARE @IdMenuCaja INT;
SELECT  @IdMenuCaja = s.IdMenu
FROM    dbo.SUBMENU s
WHERE   s.Controlador = 'CajaVenta'
  AND   s.Nombre      = 'Caja de Ventas'
  AND   s.Vista       = 'Index';

IF @IdMenuCaja IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el menú padre "Caja". Verificá que script 55 fue ejecutado.';
    RETURN;
END
PRINT 'OK: Menú Caja encontrado (IdMenu = ' + CAST(@IdMenuCaja AS VARCHAR) + ').';

-- ── 2. Insertar submenu "Cuentas por Cobrar" ─────────────────────────────────
DECLARE @IdSubMenuCXC INT;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE  Controlador = 'ComprobanteCobro'
      AND  Nombre      = 'Cuentas por Cobrar'
)
BEGIN
    INSERT INTO dbo.SUBMENU
        (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES
        (@IdMenuCaja, 'Cuentas por Cobrar', 'ComprobanteCobro', 'CuentasPorCobrar',
         'fas fa-dollar-sign', 3, 1);

    SET @IdSubMenuCXC = SCOPE_IDENTITY();
    PRINT 'OK: Submenu "Cuentas por Cobrar" creado (IdSubMenu = ' + CAST(@IdSubMenuCXC AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSubMenuCXC = IdSubMenu
    FROM   dbo.SUBMENU
    WHERE  Controlador = 'ComprobanteCobro'
      AND  Nombre      = 'Cuentas por Cobrar';
    PRINT 'INFO: Submenu "Cuentas por Cobrar" ya existía (IdSubMenu = ' + CAST(@IdSubMenuCXC AS VARCHAR) + ').';
END

-- ── 3. Permisos por rol ───────────────────────────────────────────────────────

-- CAJERO (IdRol = 4): puede VER la lista de cuentas por cobrar
-- No tiene permiso de "Cobrar" — esa acción usa AuthorizeRol separado
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 4 AND IdSubMenu = @IdSubMenuCXC)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (4, @IdSubMenuCXC, 1, GETDATE());
    PRINT 'OK: Permiso CAJERO (IdRol=4) insertado para Cuentas por Cobrar.';
END
ELSE
    PRINT 'INFO: Permiso CAJERO ya existía.';

-- SUPERVISOR/ENCARGADO (IdRol = 7): puede VER y COBRAR (su tienda)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdSubMenuCXC)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (7, @IdSubMenuCXC, 1, GETDATE());
    PRINT 'OK: Permiso SUPERVISOR (IdRol=7) insertado para Cuentas por Cobrar.';
END
ELSE
    PRINT 'INFO: Permiso SUPERVISOR ya existía.';

-- SUPERADMIN (IdRol = 14)
IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 14 AND IdSubMenu = @IdSubMenuCXC)
BEGIN
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    VALUES (14, @IdSubMenuCXC, 1, GETDATE());
    PRINT 'OK: Permiso SUPERADMIN (IdRol=14) insertado para Cuentas por Cobrar.';
END
ELSE
    PRINT 'INFO: Permiso SUPERADMIN ya existía.';

-- ── 4. También verificar que ComprobanteCobro/Index (comprobantes de cobro historial)
--      tenga los mismos permisos ────────────────────────────────────────────────
DECLARE @IdSubMenuCC INT;
SELECT  @IdSubMenuCC = IdSubMenu
FROM    dbo.SUBMENU
WHERE   Controlador = 'ComprobanteCobro'
  AND   Nombre      = 'Comprobantes de Cobro';

IF @IdSubMenuCC IS NOT NULL
BEGIN
    -- Asegurar que CAJERO (4) pueda ver historial de comprobantes
    IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 4 AND IdSubMenu = @IdSubMenuCC)
    BEGIN
        INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
        VALUES (4, @IdSubMenuCC, 1, GETDATE());
        PRINT 'OK: Permiso CAJERO agregado a Comprobantes de Cobro.';
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 7 AND IdSubMenu = @IdSubMenuCC)
    BEGIN
        INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
        VALUES (7, @IdSubMenuCC, 1, GETDATE());
        PRINT 'OK: Permiso SUPERVISOR agregado a Comprobantes de Cobro.';
    END
END

-- ── 5. Verificación ──────────────────────────────────────────────────────────
SELECT
    s.IdSubMenu,
    s.Nombre     AS Submenu,
    s.Controlador,
    s.Vista,
    r.Descripcion AS Rol,
    p.Activo
FROM   dbo.PERMISOS p
INNER  JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER  JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
WHERE  s.Controlador = 'ComprobanteCobro'
ORDER  BY s.Nombre, r.Descripcion;

PRINT '════ Script 83 completado ════';
GO
