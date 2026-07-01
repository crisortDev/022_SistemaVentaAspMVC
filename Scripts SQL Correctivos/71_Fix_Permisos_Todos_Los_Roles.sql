-- ============================================================
-- Script 71: Fix completo de permisos por rol
-- Fecha: 2026-05-19
--
-- PROBLEMA:
--   Scripts anteriores (55, 62) asignaron IdRol 7 (REPOSITOR)
--   pensando que era Encargado/Supervisor. Los roles reales son:
--     IdRol 1  = ADMINISTRADOR
--     IdRol 4  = CAJERO
--     IdRol 6  = Encargado
--     IdRol 7  = REPOSITOR
--     IdRol 11 = SUPERVISOR
--     IdRol 14 = SUPERADMIN
--
-- MÓDULOS CORREGIDOS:
--   ► CajaVenta   — Caja de Ventas
--   ► PuntoCaja   — Gestión de Cajas
--   ► ParametrosTributarios — Parámetros Tributarios
--   ► Ventas y Pre-ventas (verificación completa)
--   ► Cliente     — acceso para Cajero
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── Confirmar roles existentes en la BD ──────────────────────────────────────
PRINT 'Roles actuales:';
SELECT IdRol, Descripcion FROM dbo.ROL ORDER BY IdRol;
GO

-- ════════════════════════════════════════════════════════════
-- HELPER: función reutilizable para UPSERT de permisos
-- ════════════════════════════════════════════════════════════
-- Se usa un patrón UPDATE+INSERT para no duplicar filas

-- ════════════════════════════════════════════════════════════
-- 1. CAJA DE VENTAS  (Controlador = CajaVenta)
-- ════════════════════════════════════════════════════════════
DECLARE @smCaja INT;
SELECT @smCaja = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'CajaVenta' AND Nombre = 'Caja de Ventas';

PRINT 'IdSubMenu CajaVenta: ' + ISNULL(CAST(@smCaja AS VARCHAR), 'NULL — verificá que Script 55 se ejecutó');

IF @smCaja IS NOT NULL
BEGIN
    -- Matriz de permisos: CAJERO✓ Encargado✓ SUPERVISOR✓ ADMIN✓ SA✓ | REPOS✗
    DECLARE @pCaja TABLE (IdRol INT, Activo BIT);
    INSERT INTO @pCaja VALUES (7,0),(4,1),(6,1),(11,1),(1,1),(14,1);

    -- UPSERT
    UPDATE p SET p.Activo = pc.Activo
    FROM dbo.PERMISOS p JOIN @pCaja pc ON pc.IdRol = p.IdRol AND p.IdSubMenu = @smCaja;

    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT pc.IdRol, @smCaja, pc.Activo, GETDATE()
    FROM @pCaja pc
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = pc.IdRol AND p.IdSubMenu = @smCaja
    );

    PRINT 'OK: Permisos CajaVenta actualizados.';
END
GO

-- ════════════════════════════════════════════════════════════
-- 2. GESTIÓN DE CAJAS  (Controlador = PuntoCaja)
-- ════════════════════════════════════════════════════════════
DECLARE @smPunto INT;
SELECT @smPunto = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'PuntoCaja' AND Vista = 'Index';

PRINT 'IdSubMenu PuntoCaja: ' + ISNULL(CAST(@smPunto AS VARCHAR), 'NULL — verificá que Script 62 se ejecutó');

IF @smPunto IS NOT NULL
BEGIN
    -- Solo gerencia/admin administra los puntos de caja, no el cajero operativo
    DECLARE @pPunto TABLE (IdRol INT, Activo BIT);
    INSERT INTO @pPunto VALUES (7,0),(4,0),(6,1),(11,1),(1,1),(14,1);

    UPDATE p SET p.Activo = pp.Activo
    FROM dbo.PERMISOS p JOIN @pPunto pp ON pp.IdRol = p.IdRol AND p.IdSubMenu = @smPunto;

    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT pp.IdRol, @smPunto, pp.Activo, GETDATE()
    FROM @pPunto pp
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = pp.IdRol AND p.IdSubMenu = @smPunto
    );

    PRINT 'OK: Permisos PuntoCaja actualizados.';
END
GO

-- ════════════════════════════════════════════════════════════
-- 3. PARÁMETROS TRIBUTARIOS  (Controlador = ParametrosTributarios)
-- ════════════════════════════════════════════════════════════
DECLARE @smTrib INT;
SELECT @smTrib = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'ParametrosTributarios' AND Vista = 'Index';

PRINT 'IdSubMenu ParametrosTributarios: ' + ISNULL(CAST(@smTrib AS VARCHAR), 'NULL — verificá que Script 60 se ejecutó');

IF @smTrib IS NOT NULL
BEGIN
    -- Solo SuperAdmin y Administrador manejan timbrados fiscales
    DECLARE @pTrib TABLE (IdRol INT, Activo BIT);
    INSERT INTO @pTrib VALUES (7,0),(4,0),(6,0),(11,0),(1,1),(14,1);

    UPDATE p SET p.Activo = pt.Activo
    FROM dbo.PERMISOS p JOIN @pTrib pt ON pt.IdRol = p.IdRol AND p.IdSubMenu = @smTrib;

    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT pt.IdRol, @smTrib, pt.Activo, GETDATE()
    FROM @pTrib pt
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = pt.IdRol AND p.IdSubMenu = @smTrib
    );

    PRINT 'OK: Permisos ParametrosTributarios actualizados.';
END
GO

-- ════════════════════════════════════════════════════════════
-- 4. VENTAS — verificar que Cajero y roles tengan acceso
--    (solo corrige si faltan; no toca lo que ya esté bien)
-- ════════════════════════════════════════════════════════════
DECLARE @smVD  INT, @smCV INT, @smRPV INT, @smCPV INT, @smCC INT;

SELECT @smVD  = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Venta'            AND Nombre='Registrar Venta Directa';
SELECT @smCV  = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Venta'            AND Nombre='Consultar Ventas';
SELECT @smRPV = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta'       AND Nombre='Registrar Pre-venta';
SELECT @smCPV = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta'       AND Nombre='Consultar Pre-ventas';
SELECT @smCC  = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='ComprobanteCobro' AND Nombre='Comprobantes de Cobro';

PRINT 'SubMenus Ventas — VentaDirecta:' + ISNULL(CAST(@smVD AS VARCHAR),'?') +
      ' ConsultarVenta:' + ISNULL(CAST(@smCV AS VARCHAR),'?') +
      ' RegistrarOV:' + ISNULL(CAST(@smRPV AS VARCHAR),'?') +
      ' ConsultarOV:' + ISNULL(CAST(@smCPV AS VARCHAR),'?') +
      ' ComprobanteCobro:' + ISNULL(CAST(@smCC AS VARCHAR),'?');

-- Tabla temporal con todos los permisos de ventas a asegurar
CREATE TABLE #pVentas (IdRol INT, IdSubMenu INT, Activo BIT);

-- Registrar Venta Directa: CAJERO✓ Encargado✓ ADMIN✓ SA✓ | REPOS✗ SUPER✗
IF @smVD IS NOT NULL INSERT INTO #pVentas VALUES
    (7,@smVD,0),(4,@smVD,1),(6,@smVD,1),(11,@smVD,0),(1,@smVD,1),(14,@smVD,1);

-- Consultar Ventas: todos ✓
IF @smCV IS NOT NULL INSERT INTO #pVentas VALUES
    (7,@smCV,1),(4,@smCV,1),(6,@smCV,1),(11,@smCV,1),(1,@smCV,1),(14,@smCV,1);

-- Registrar Pre-venta: REPOS✓ CAJERO✓ ADMIN✓ SA✓ | Encargado✗ SUPER✗
IF @smRPV IS NOT NULL INSERT INTO #pVentas VALUES
    (7,@smRPV,1),(4,@smRPV,1),(6,@smRPV,0),(11,@smRPV,0),(1,@smRPV,1),(14,@smRPV,1);

-- Consultar Pre-ventas: todos ✓
IF @smCPV IS NOT NULL INSERT INTO #pVentas VALUES
    (7,@smCPV,1),(4,@smCPV,1),(6,@smCPV,1),(11,@smCPV,1),(1,@smCPV,1),(14,@smCPV,1);

-- Comprobantes de Cobro: CAJERO✓ Encargado✓ SUPER✓ ADMIN✓ SA✓ | REPOS✗
IF @smCC IS NOT NULL INSERT INTO #pVentas VALUES
    (7,@smCC,0),(4,@smCC,1),(6,@smCC,1),(11,@smCC,1),(1,@smCC,1),(14,@smCC,1);

-- UPSERT
UPDATE p SET p.Activo = pv.Activo
FROM dbo.PERMISOS p JOIN #pVentas pv ON pv.IdRol=p.IdRol AND pv.IdSubMenu=p.IdSubMenu;

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT pv.IdRol, pv.IdSubMenu, pv.Activo, GETDATE()
FROM #pVentas pv
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol=pv.IdRol AND p.IdSubMenu=pv.IdSubMenu
);

DROP TABLE #pVentas;
PRINT 'OK: Permisos de Ventas asegurados.';
GO

-- ════════════════════════════════════════════════════════════
-- 5. CLIENTE — Cajero puede buscar y crear clientes
-- ════════════════════════════════════════════════════════════
DECLARE @smCliente INT;
SELECT @smCliente = IdSubMenu FROM dbo.SUBMENU
WHERE Controlador = 'Cliente' AND Nombre = 'Clientes';

IF @smCliente IS NOT NULL
BEGIN
    -- CAJERO✓ Encargado✓ REPOS✓ SUPER✓ ADMIN✓ SA✓
    DECLARE @pCli TABLE (IdRol INT, Activo BIT);
    INSERT INTO @pCli VALUES (7,1),(4,1),(6,1),(11,1),(1,1),(14,1);

    UPDATE p SET p.Activo = pc.Activo
    FROM dbo.PERMISOS p JOIN @pCli pc ON pc.IdRol = p.IdRol AND p.IdSubMenu = @smCliente;

    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT pc.IdRol, @smCliente, pc.Activo, GETDATE()
    FROM @pCli pc
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = pc.IdRol AND p.IdSubMenu = @smCliente
    );

    PRINT 'OK: Permisos Cliente asegurados.';
END
GO

-- ════════════════════════════════════════════════════════════
-- VERIFICACIÓN FINAL — Matriz completa de permisos relevantes
-- ════════════════════════════════════════════════════════════
PRINT '';
PRINT '══════════════════════════════════════════════════════════════';
PRINT 'MATRIZ FINAL DE PERMISOS (módulos ventas + caja)';
PRINT '══════════════════════════════════════════════════════════════';

SELECT
    r.Descripcion                                    AS Rol,
    m.Nombre                                         AS Menu,
    s.Nombre                                         AS Submenu,
    s.Controlador,
    CASE WHEN p.Activo = 1 THEN '✓' ELSE '✗' END    AS Acceso
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU     m  ON m.IdMenu    = s.IdMenu
LEFT  JOIN dbo.PERMISOS p  ON p.IdSubMenu = s.IdSubMenu
LEFT  JOIN dbo.ROL      r  ON r.IdRol     = p.IdRol
WHERE s.Controlador IN (
    'CajaVenta','PuntoCaja','ParametrosTributarios',
    'Venta','OrdenVenta','ComprobanteCobro','Cliente'
)
AND (p.IdRol IS NULL OR p.IdRol IN (1,4,6,7,11,14))
ORDER BY s.Controlador, r.IdRol;
GO

PRINT '════ Script 71 completado ════';
GO
