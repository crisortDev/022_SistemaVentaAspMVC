-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 37: Segregación de Funciones — Módulo Compras
-- ─────────────────────────────────────────────────────────────────────────────
-- Acciones:
--   1. Contraseña "123456" a todos los usuarios (para pruebas)
--   2. Lilian  (IdUsuario=17) → Encargado (IdRol=6)  [aprobadora]
--   3. Federico (IdUsuario=16) → REPOSITOR (IdRol=7) [solo carga/vista]
--   4. Ajusta PERMISOS para módulo Compras por la siguiente matriz:
--        Función                  | REPOS | CAJERO | Encarg | SUPERV | ADMIN | SA
--        Registrar OC             |   ✓   |   ✓   |   ✓   |   —   |   ✓  |  ✓
--        Consultar OC (+ PDF)     |   ✓   |   ✓   |   ✓   |   ✓   |   ✓  |  ✓
--        Aprobar / Rechazar OC    |   —   |   —   |   ✓   |   ✓   |   ✓  |  ✓
--        Recepción Compra         |   ✓   |   ✓   |   ✓   |   —   |   ✓  |  ✓
--        Consultar Compra         |   ✓   |   ✓   |   ✓   |   ✓   |   ✓  |  ✓
--        Revisión / Confirmar     |   —   |   —   |   ✓   |   ✓   |   ✓  |  ✓
--        Órdenes de Pago          |   —   |   —   |   ✓   |   ✓   |   ✓  |  ✓
--        Gestión de NC            |   —   |   —   |   ✓   |   ✓   |   ✓  |  ✓
--        Reporte Gerencia         |   —   |   —   |   ✓   |   ✓   |   ✓  |  ✓
--        Proveedores              |   —   |   —   |   ✓   |   —   |   ✓  |  ✓
--   5. Quita módulo Seguridad de Encargado (6) y SUPERVISOR (11)
--      (Roles/Usuarios solo para ADMINISTRADOR y SUPERADMIN)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. CONTRASEÑA "123456" PARA TODOS — SHA-256 de "123456"
-- ══════════════════════════════════════════════════════════════════════════════
UPDATE dbo.USUARIO
SET
    Clave                  = '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    PasswordTemporalHash   = NULL,
    PasswordTemporalExpira = NULL,
    RequiereCambioPassword = 0,
    IntentosFallidos       = 0,
    EstadoUsuario          = 0        -- 0 = activo / desbloqueado
WHERE IdUsuario IN (1, 3, 4, 5, 16, 17);
PRINT 'OK: Contraseña "123456" aplicada a todos los usuarios de prueba.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. LILIAN → ENCARGADO (IdRol=6)
-- ══════════════════════════════════════════════════════════════════════════════
UPDATE dbo.USUARIO SET IdRol = 6 WHERE IdUsuario = 17;
PRINT 'OK: Lilian Ferreira → Encargado (IdRol=6).';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. FEDERICO → REPOSITOR (IdRol=7)
-- ══════════════════════════════════════════════════════════════════════════════
UPDATE dbo.USUARIO SET IdRol = 7 WHERE IdUsuario = 16;
PRINT 'OK: Federico Perez → REPOSITOR (IdRol=7).';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. PERMISOS — Módulo Compras
-- ══════════════════════════════════════════════════════════════════════════════
-- Helper: aplica Activo = @val para el rol+submenu indicado.
-- Si no existe el registro lo inserta.
-- ──────────────────────────────────────────────────────────────────────────────

-- IdRoles usados: 7=REPOSITOR, 4=CAJERO, 6=Encargado, 11=SUPERVISOR, 1=ADMIN, 14=SUPERADMIN
-- Variables para guardar IdSubMenu de cada función

DECLARE @smRegOC        INT   -- OrdenCompra / Registrar Orden Compra
DECLARE @smConOC        INT   -- OrdenCompra / Consultar Orden Compra
DECLARE @smAprOC        INT   -- OrdenCompra / Aprobar Orden Compra
DECLARE @smRecComp      INT   -- Compra      / Registrar Compra  (= Recepción)
DECLARE @smConComp      INT   -- Compra      / Consultar Compra
DECLARE @smRevComp      INT   -- Compra      / Revisión de Compras
DECLARE @smOP           INT   -- Compra      / Órdenes de Pago
DECLARE @smNC           INT   -- NotaCredito / Gestión de NC
DECLARE @smRG           INT   -- ReporteGerencia / Reporte Gerencia Compras
DECLARE @smProv         INT   -- Proveedor   / Proveedores

-- Recuperar IDs
SELECT @smRegOC   = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenCompra' AND Nombre='Registrar Orden Compra'
SELECT @smConOC   = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenCompra' AND Nombre='Consultar Orden Compra'
SELECT @smAprOC   = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenCompra' AND Nombre='Aprobar Orden Compra'
SELECT @smRecComp = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Compra'      AND Nombre='Registrar Compra'
SELECT @smConComp = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Compra'      AND Nombre='Consultar Compra'
SELECT @smRevComp = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Compra'      AND Nombre='Revisión de Compras'
SELECT @smOP      = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Compra'      AND Nombre='Órdenes de Pago'
SELECT @smNC      = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='NotaCredito' AND Nombre='Gestión de NC'
SELECT @smRG      = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='ReporteGerencia' AND Nombre='Reporte Gerencia Compras'
SELECT @smProv    = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Proveedor'   AND Nombre='Proveedores'

PRINT 'SubMenus encontrados:'
PRINT '  Registrar OC     = ' + ISNULL(CAST(@smRegOC   AS VARCHAR),'NULL')
PRINT '  Consultar OC     = ' + ISNULL(CAST(@smConOC   AS VARCHAR),'NULL')
PRINT '  Aprobar OC       = ' + ISNULL(CAST(@smAprOC   AS VARCHAR),'NULL')
PRINT '  Registrar Compra = ' + ISNULL(CAST(@smRecComp AS VARCHAR),'NULL')
PRINT '  Consultar Compra = ' + ISNULL(CAST(@smConComp AS VARCHAR),'NULL')
PRINT '  Revisión Compra  = ' + ISNULL(CAST(@smRevComp AS VARCHAR),'NULL')
PRINT '  Órdenes de Pago  = ' + ISNULL(CAST(@smOP      AS VARCHAR),'NULL')
PRINT '  Gestión de NC    = ' + ISNULL(CAST(@smNC      AS VARCHAR),'NULL')
PRINT '  Reporte Gerencia = ' + ISNULL(CAST(@smRG      AS VARCHAR),'NULL')
PRINT '  Proveedores      = ' + ISNULL(CAST(@smProv    AS VARCHAR),'NULL')

-- ──────────────────────────────────────────────────────────────────────────────
-- Tabla temporal con la matriz: (IdRol, IdSubMenu, Activo)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE #Matriz (IdRol INT, IdSubMenu INT, Activo BIT)

-- REGISTRAR OC — REPOS✓ CAJERO✓ Encarg✓ SUPERV✗ ADMIN✓ SA✓
IF @smRegOC IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smRegOC,1),(4,@smRegOC,1),(6,@smRegOC,1),(11,@smRegOC,0),(1,@smRegOC,1),(14,@smRegOC,1)

-- CONSULTAR OC — todos ✓
IF @smConOC IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smConOC,1),(4,@smConOC,1),(6,@smConOC,1),(11,@smConOC,1),(1,@smConOC,1),(14,@smConOC,1)

-- APROBAR OC — REPOS✗ CAJERO✗ Encarg✓ SUPERV✓ ADMIN✓ SA✓
IF @smAprOC IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smAprOC,0),(4,@smAprOC,0),(6,@smAprOC,1),(11,@smAprOC,1),(1,@smAprOC,1),(14,@smAprOC,1)

-- REGISTRAR COMPRA (Recepción) — REPOS✓ CAJERO✓ Encarg✓ SUPERV✗ ADMIN✓ SA✓
IF @smRecComp IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smRecComp,1),(4,@smRecComp,1),(6,@smRecComp,1),(11,@smRecComp,0),(1,@smRecComp,1),(14,@smRecComp,1)

-- CONSULTAR COMPRA — todos ✓
IF @smConComp IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smConComp,1),(4,@smConComp,1),(6,@smConComp,1),(11,@smConComp,1),(1,@smConComp,1),(14,@smConComp,1)

-- REVISIÓN COMPRAS — REPOS✗ CAJERO✗ Encarg✓ SUPERV✓ ADMIN✓ SA✓
IF @smRevComp IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smRevComp,0),(4,@smRevComp,0),(6,@smRevComp,1),(11,@smRevComp,1),(1,@smRevComp,1),(14,@smRevComp,1)

-- ÓRDENES DE PAGO — REPOS✗ CAJERO✗ Encarg✓ SUPERV✓ ADMIN✓ SA✓
IF @smOP IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smOP,0),(4,@smOP,0),(6,@smOP,1),(11,@smOP,1),(1,@smOP,1),(14,@smOP,1)

-- GESTIÓN DE NC — REPOS✗ CAJERO✗ Encarg✓ SUPERV✓ ADMIN✓ SA✓
IF @smNC IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smNC,0),(4,@smNC,0),(6,@smNC,1),(11,@smNC,1),(1,@smNC,1),(14,@smNC,1)

-- REPORTE GERENCIA — REPOS✗ CAJERO✗ Encarg✓ SUPERV✓ ADMIN✓ SA✓
IF @smRG IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smRG,0),(4,@smRG,0),(6,@smRG,1),(11,@smRG,1),(1,@smRG,1),(14,@smRG,1)

-- PROVEEDORES — REPOS✗ CAJERO✗ Encarg✓ SUPERV✗ ADMIN✓ SA✓
IF @smProv IS NOT NULL
INSERT INTO #Matriz VALUES
(7,@smProv,0),(4,@smProv,0),(6,@smProv,1),(11,@smProv,0),(1,@smProv,1),(14,@smProv,1)

-- ── Aplicar: UPDATE los que existen, INSERT los que faltan ────────────────────
UPDATE p
SET    p.Activo = m.Activo
FROM   dbo.PERMISOS p
JOIN   #Matriz m ON m.IdRol = p.IdRol AND m.IdSubMenu = p.IdSubMenu

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT m.IdRol, m.IdSubMenu, m.Activo, GETDATE()
FROM   #Matriz m
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE p.IdRol = m.IdRol AND p.IdSubMenu = m.IdSubMenu
)

DROP TABLE #Matriz
PRINT 'OK: Permisos de módulo Compras actualizados según matriz de segregación.'
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. SEGURIDAD — quitar Rol/Usuarios de Encargado(6) y SUPERVISOR(11)
--    Solo ADMINISTRADOR(1) y SUPERADMIN(14) pueden gestionar seguridad
-- ══════════════════════════════════════════════════════════════════════════════
UPDATE p
SET    p.Activo = 0
FROM   dbo.PERMISOS p
JOIN   dbo.SUBMENU  s ON s.IdSubMenu = p.IdSubMenu
WHERE  p.IdRol IN (6, 11)
  AND  s.Controlador IN ('Rol','Usuario','Permisos')
PRINT 'OK: Módulo Seguridad (Roles/Usuarios/Permisos) restringido a ADMIN y SUPERADMIN.'
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- RESUMEN FINAL
-- ══════════════════════════════════════════════════════════════════════════════
PRINT '──────────────────────────────────────────────────────'
PRINT 'USUARIOS PARA PRUEBA (contraseña: 123456 para todos)'
PRINT '──────────────────────────────────────────────────────'
PRINT '  admin@gmail.com          → SUPERADMIN   (Cristian)'
PRINT '  jorge@correo.com         → ADMINISTRADOR (Jorge)'
PRINT '  cristian.a.ortega@hotmail.com → Encargado (Lilian) [APRUEBA]'
PRINT '  juan.perez@gmail.com     → CAJERO       (Juan)  [CARGA]'
PRINT '  tiantega@gmail.com       → CAJERO       (Pepe)  [CARGA]'
PRINT '  crisarielorte@fpuna.edu.py → REPOSITOR  (Federico) [VISTA]'
PRINT '──────────────────────────────────────────────────────'
PRINT 'Script 37 completado.'
GO
