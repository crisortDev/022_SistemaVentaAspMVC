-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 119: Separar permisos de Pre-venta (Repositor carga / Cajero factura)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03
--
-- Matriz objetivo (Roles: 1=Admin, 4=Cajero, 6=Encargado, 7=Repositor,
--                          11=Supervisor, 14=SuperAdmin):
--
--   Acción                  REPOS(7) CAJERO(4) ENC(6) SUPER(11) ADMIN(1) SA(14)
--   Registrar Pre-venta       ✓        ✗        ✗       ✗        ✓        ✓
--   Registrar Venta Directa   ✗        ✓        ✗       ✗        ✓        ✓   (= facturar)
--   Consultar Pre-ventas      ✓        ✓        ✓       ✓        ✓        ✓
--
-- NOTA: "facturar pre-venta" usa el permiso "Registrar Venta Directa".
--   La segregación adicional (quien cargó ≠ quien factura) ya está en el SP (script 116).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

DECLARE @smRegOV  INT, @smVD INT, @smConsOV INT;
SELECT @smRegOV  = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Registrar Pre-venta';
SELECT @smVD     = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Venta'      AND Nombre='Registrar Venta Directa';
SELECT @smConsOV = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Consultar Pre-ventas';

PRINT 'SubMenus -> RegOV:'+ISNULL(CAST(@smRegOV AS VARCHAR),'?')
     +' VentaDirecta:'+ISNULL(CAST(@smVD AS VARCHAR),'?')
     +' ConsOV:'+ISNULL(CAST(@smConsOV AS VARCHAR),'?');

CREATE TABLE #P (IdRol INT, IdSubMenu INT, Activo BIT);

-- Registrar Pre-venta: SOLO Repositor(7), Admin(1), SuperAdmin(14)
IF @smRegOV IS NOT NULL INSERT INTO #P VALUES
    (7,@smRegOV,1),(4,@smRegOV,0),(6,@smRegOV,0),(11,@smRegOV,0),(1,@smRegOV,1),(14,@smRegOV,1);

-- Registrar Venta Directa / Facturar: Cajero(4), Admin(1), SuperAdmin(14)
IF @smVD IS NOT NULL INSERT INTO #P VALUES
    (7,@smVD,0),(4,@smVD,1),(6,@smVD,0),(11,@smVD,0),(1,@smVD,1),(14,@smVD,1);

-- Consultar Pre-ventas: todos
IF @smConsOV IS NOT NULL INSERT INTO #P VALUES
    (7,@smConsOV,1),(4,@smConsOV,1),(6,@smConsOV,1),(11,@smConsOV,1),(1,@smConsOV,1),(14,@smConsOV,1);

-- UPSERT
UPDATE p SET p.Activo = x.Activo
FROM dbo.PERMISOS p JOIN #P x ON x.IdRol=p.IdRol AND x.IdSubMenu=p.IdSubMenu;

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT x.IdRol, x.IdSubMenu, x.Activo, GETDATE()
FROM #P x
WHERE NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol=x.IdRol AND p.IdSubMenu=x.IdSubMenu);

DROP TABLE #P;
PRINT 'OK: Permisos de pre-venta separados (Repositor carga / Cajero factura).';
GO

-- ── Verificación ────────────────────────────────────────────────────────────────
SELECT r.Descripcion AS Rol, s.Nombre AS Submenu,
       CASE WHEN p.Activo=1 THEN 'SI' ELSE 'NO' END AS Acceso
FROM dbo.SUBMENU s
JOIN dbo.PERMISOS p ON p.IdSubMenu = s.IdSubMenu
JOIN dbo.ROL r ON r.IdRol = p.IdRol
WHERE s.Controlador IN ('OrdenVenta','Venta')
  AND s.Nombre IN ('Registrar Pre-venta','Registrar Venta Directa','Consultar Pre-ventas')
  AND r.IdRol IN (1,4,6,7,11,14)
ORDER BY s.Nombre, r.IdRol;
GO
