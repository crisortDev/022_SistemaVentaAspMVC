-- ============================================================
-- Script 72: Limpiar submenús duplicados y verificar permisos
-- Fecha: 2026-05-19
--
-- PROBLEMA:
--   La BD tiene submenús originales ("Registrar Venta",
--   "Consultar Venta", "Clientes") que coexisten con los
--   nuevos creados por Script 38c ("Registrar Venta Directa",
--   "Consultar Ventas"). Eso genera:
--     ► Duplicados en el menú lateral del usuario
--     ► Filas duplicadas en PERMISOS
--     ► Confusión en AuthorizeRol al resolver nombres
--
-- SOLUCIÓN:
--   1. Desactivar los submenús viejos (Activo=0) y sus permisos
--   2. Conservar los nuevos con los nombres correctos
--   3. Verificar con caracteres ASCII (evita el "?" de SSMS)
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
-- DIAGNÓSTICO PREVIO — ver todos los submenús duplicados
-- ════════════════════════════════════════════════════════════
PRINT '--- Submenús del controlador Venta ---';
SELECT IdSubMenu, Nombre, Controlador, Vista, Activo
FROM dbo.SUBMENU
WHERE Controlador IN ('Venta','OrdenVenta','Cliente','CajaVenta','PuntoCaja')
ORDER BY Controlador, Nombre;
GO

-- ════════════════════════════════════════════════════════════
-- 1. DESACTIVAR submenús viejos del controlador Venta
--    Viejos: "Registrar Venta" y "Consultar Venta"
--    Nuevos a conservar: "Registrar Venta Directa" y "Consultar Ventas"
-- ════════════════════════════════════════════════════════════
DECLARE @smViejoRV INT, @smViejoCV INT;

-- Viejo "Registrar Venta" — solo desactivar si existe el nuevo "Registrar Venta Directa"
IF EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Registrar Venta Directa' AND Activo=1)
BEGIN
    UPDATE dbo.SUBMENU
    SET Activo = 0
    WHERE Controlador = 'Venta'
      AND Nombre IN ('Registrar Venta', 'Registrar Nueva Venta', 'Nueva Venta')
      AND Nombre <> 'Registrar Venta Directa';

    -- También desactivar sus permisos huérfanos
    UPDATE p SET p.Activo = 0
    FROM dbo.PERMISOS p
    JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
    WHERE s.Controlador = 'Venta'
      AND s.Nombre IN ('Registrar Venta', 'Registrar Nueva Venta', 'Nueva Venta')
      AND s.Nombre <> 'Registrar Venta Directa';

    PRINT 'OK: Submenú(s) "Registrar Venta" (viejos) desactivados.';
END
ELSE
    PRINT 'INFO: No existe "Registrar Venta Directa" activo — no se toca nada.';
GO

-- Viejo "Consultar Venta" — solo desactivar si existe el nuevo "Consultar Ventas"
IF EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Consultar Ventas' AND Activo=1)
BEGIN
    UPDATE dbo.SUBMENU
    SET Activo = 0
    WHERE Controlador = 'Venta'
      AND Nombre IN ('Consultar Venta', 'Ver Ventas', 'Lista Ventas')
      AND Nombre <> 'Consultar Ventas';

    UPDATE p SET p.Activo = 0
    FROM dbo.PERMISOS p
    JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
    WHERE s.Controlador = 'Venta'
      AND s.Nombre IN ('Consultar Venta', 'Ver Ventas', 'Lista Ventas')
      AND s.Nombre <> 'Consultar Ventas';

    PRINT 'OK: Submenú(s) "Consultar Venta" (viejos) desactivados.';
END
ELSE
    PRINT 'INFO: No existe "Consultar Ventas" activo — no se toca nada.';
GO

-- ════════════════════════════════════════════════════════════
-- 2. DESACTIVAR submenús duplicados de Cliente
--    Mantener solo el que tenga Nombre = 'Clientes'
--    y sea el más reciente (mayor IdSubMenu)
-- ════════════════════════════════════════════════════════════
DECLARE @smClienteOk INT;

-- El "bueno" es el de mayor IdSubMenu (el creado más recientemente)
SELECT @smClienteOk = MAX(IdSubMenu)
FROM dbo.SUBMENU
WHERE Controlador = 'Cliente' AND Nombre = 'Clientes' AND Activo = 1;

IF @smClienteOk IS NOT NULL
BEGIN
    -- Desactivar todos los anteriores con mismo Controlador y nombre similar
    UPDATE dbo.SUBMENU
    SET Activo = 0
    WHERE Controlador = 'Cliente'
      AND Nombre IN ('Clientes', 'Cliente', 'Crear Cliente', 'Lista Clientes')
      AND IdSubMenu <> @smClienteOk;

    UPDATE p SET p.Activo = 0
    FROM dbo.PERMISOS p
    JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
    WHERE s.Controlador = 'Cliente'
      AND s.IdSubMenu <> @smClienteOk
      AND s.Activo = 0;  -- solo los que acabamos de desactivar

    PRINT 'OK: Submenús duplicados de Cliente desactivados. Activo conservado: IdSubMenu=' + CAST(@smClienteOk AS VARCHAR);
END
GO

-- ════════════════════════════════════════════════════════════
-- 3. VERIFICACIÓN FINAL — con SI/NO en lugar de Unicode
--    para que SSMS lo muestre correctamente
-- ════════════════════════════════════════════════════════════
PRINT '';
PRINT '==========================================================';
PRINT 'SUBMENUS ACTIVOS (Controladores relevantes)';
PRINT '==========================================================';

SELECT
    s.IdSubMenu,
    m.Nombre        AS Menu,
    s.Nombre        AS Submenu,
    s.Controlador,
    s.Vista,
    CASE s.Activo WHEN 1 THEN 'Activo' ELSE 'INACTIVO' END AS Estado
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE s.Controlador IN (
    'Venta','OrdenVenta','CajaVenta','PuntoCaja',
    'ComprobanteCobro','Cliente','ParametrosTributarios'
)
ORDER BY s.Controlador, s.Activo DESC, s.Nombre;
GO

PRINT '';
PRINT '==========================================================';
PRINT 'MATRIZ DE PERMISOS (solo submenus ACTIVOS)';
PRINT 'Acceso: SI = Activo=1 | NO = Activo=0';
PRINT '==========================================================';

SELECT
    r.Descripcion                                       AS Rol,
    m.Nombre                                            AS Menu,
    s.Nombre                                            AS Submenu,
    s.Controlador,
    CASE WHEN p.Activo = 1 THEN 'SI' ELSE 'NO' END     AS Acceso
FROM dbo.SUBMENU s
INNER JOIN dbo.MENU     m  ON m.IdMenu    = s.IdMenu
LEFT  JOIN dbo.PERMISOS p  ON p.IdSubMenu = s.IdSubMenu
LEFT  JOIN dbo.ROL      r  ON r.IdRol     = p.IdRol
WHERE s.Activo = 1   -- solo submenús activos
  AND s.Controlador IN (
      'Venta','OrdenVenta','CajaVenta','PuntoCaja',
      'ComprobanteCobro','Cliente','ParametrosTributarios'
  )
  AND p.IdRol IN (1,4,6,7,11,14)
ORDER BY s.Controlador, p.IdRol;
GO

PRINT '==== Script 72 completado ====';
GO
