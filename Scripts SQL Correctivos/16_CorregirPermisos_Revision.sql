-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 16: Corregir Permisos — SubMenus 33, 34 y 35
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Problemas detectados en tabla PERMISOS:
--   1. SubMenu=35 tiene filas duplicadas por doble ejecución del script 15
--   2. SubMenus 33 (Recepción), 34 (OP), 35 (Revisión) tienen Activo=0 para todos
--   3. Dos filas con IdSubMenu=NULL (ids 553-554) deben eliminarse
--
-- Segregación de funciones aplicada:
--   ┌─────────────────────┬────────┬─────────┬──────────┬──────────────┐
--   │ SubMenu             │ Cajero │ Encarg. │ Superv.  │ Admin/SAdmin │
--   │                     │  (4)   │   (6)   │  (11)    │  (1) / (14)  │
--   ├─────────────────────┼────────┼─────────┼──────────┼──────────────┤
--   │ 33 - Recepción      │   ✔    │   ✔     │    ✔     │      ✔       │
--   │ 34 - Órdenes Pago   │   ✘    │   ✘     │    ✔     │      ✔       │
--   │ 35 - Revisión/Conf. │   ✘    │   ✘     │    ✔     │      ✔       │
--   └─────────────────────┴────────┴─────────┴──────────┴──────────────┘
--
--   REPOSITOR (7) no tiene acceso al módulo Compras por diseño.
--   El SUPERADMIN (14) puede hacer todo.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

PRINT '━━━ PASO 1: Eliminar filas con IdSubMenu = NULL ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
DELETE FROM dbo.PERMISOS WHERE IdSubMenu IS NULL;
PRINT '  OK: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s) eliminadas';
GO

PRINT '━━━ PASO 2: Eliminar DUPLICADOS de SubMenu=35 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
-- Conserva solo la fila con menor IdPermisos por cada IdRol para IdSubMenu=35
DELETE FROM dbo.PERMISOS
WHERE IdSubMenu = 35
  AND IdPermisos NOT IN (
      SELECT MIN(IdPermisos)
      FROM dbo.PERMISOS
      WHERE IdSubMenu = 35
      GROUP BY IdRol
  );
PRINT '  OK: duplicados eliminados. Quedan ' + CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s) para IdSubMenu=35';
GO

PRINT '━━━ PASO 3: Verificar estado actual de SubMenus 33/34/35 ━━━━━━━━━━━━━━━━━━━'
SELECT
    p.IdPermisos,
    r.Descripcion  AS Rol,
    sm.Nombre      AS SubMenu,
    p.Activo
FROM dbo.PERMISOS p
JOIN dbo.ROL     r  ON r.IdRol     = p.IdRol
JOIN dbo.SUBMENU sm ON sm.IdSubMenu = p.IdSubMenu
WHERE p.IdSubMenu IN (33, 34, 35)
ORDER BY p.IdSubMenu, r.Descripcion;
GO

PRINT '━━━ PASO 4: Activar permisos según Segregación O&M ━━━━━━━━━━━━━━━━━━━━━━━━━'

-- ── SubMenu 33: Recepción de Compra ──────────────────────────────────────────
-- Pueden registrar la recepción: Cajero(4), Encargado(6), Supervisor(11),
--                                Administrador(1), SuperAdmin(14)
UPDATE dbo.PERMISOS
   SET Activo = 1
WHERE IdSubMenu = 33
  AND IdRol IN (1, 4, 6, 11, 14);

PRINT '  OK: SubMenu 33 (Recepción) activado para roles 1,4,6,11,14 — '
    + CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s)';
GO

-- ── SubMenu 34: Órdenes de Pago ──────────────────────────────────────────────
-- Pueden emitir OP: Supervisor(11), Administrador(1), SuperAdmin(14)
UPDATE dbo.PERMISOS
   SET Activo = 1
WHERE IdSubMenu = 34
  AND IdRol IN (1, 11, 14);

PRINT '  OK: SubMenu 34 (OP) activado para roles 1,11,14 — '
    + CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s)';
GO

-- ── SubMenu 35: Revisión de Compras (Confirmar / Anular) ─────────────────────
-- SOLO pueden confirmar/anular: Supervisor(11), Administrador(1), SuperAdmin(14)
-- ⚠ El SP bloquea que el mismo usuario que registró también confirme.
UPDATE dbo.PERMISOS
   SET Activo = 1
WHERE IdSubMenu = 35
  AND IdRol IN (1, 11, 14);

PRINT '  OK: SubMenu 35 (Revisión) activado para roles 1,11,14 — '
    + CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s)';
GO


PRINT '━━━ PASO 5: Verificar resultado final ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
SELECT
    sm.IdSubMenu,
    sm.Nombre       AS SubMenu,
    r.Descripcion   AS Rol,
    p.Activo,
    CASE p.Activo WHEN 1 THEN '✔ Activo' ELSE '✘ Inactivo' END AS Estado
FROM dbo.PERMISOS p
JOIN dbo.ROL     r  ON r.IdRol      = p.IdRol
JOIN dbo.SUBMENU sm ON sm.IdSubMenu = p.IdSubMenu
WHERE p.IdSubMenu IN (33, 34, 35)
ORDER BY sm.IdSubMenu, p.Activo DESC, r.Descripcion;
GO


PRINT ''
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'SCRIPT 16 COMPLETADO'
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'Resumen de acceso por función:'
PRINT '  SubMenu 33 - Recepción de Compra  → Cajero, Encargado, Supervisor, Admin, SAdmin'
PRINT '  SubMenu 34 - Órdenes de Pago       → Supervisor, Administrador, SuperAdmin'
PRINT '  SubMenu 35 - Revisión de Compras   → Supervisor, Administrador, SuperAdmin'
PRINT ''
PRINT 'IMPORTANTE: El SP usp_ConfirmarCompraEImpactarStock valida que'
PRINT '  el usuario que CONFIRMA sea distinto al que REGISTRÓ la factura.'
PRINT '  Esto garantiza la segregación O&M a nivel de base de datos.'
PRINT ''
