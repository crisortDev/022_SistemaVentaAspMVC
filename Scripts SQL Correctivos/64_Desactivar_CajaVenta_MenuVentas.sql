-- ============================================================
-- Script 64: Desactivar submenú CajaVenta del menú Ventas
-- Fecha: 2026-05-19
--
-- El módulo CajaVenta ya tiene su acceso en el menú "Caja"
-- (Script 55 + Script 62). Desactivamos la entrada duplicada
-- que aparece en el menú "Ventas".
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── Ver situación actual ──────────────────────────────────────
SELECT
    s.IdSubMenu,
    m.Nombre  AS Menu,
    s.Nombre  AS Submenu,
    s.Controlador,
    s.Vista,
    s.Activo
FROM   dbo.SUBMENU s
INNER  JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE  s.Controlador = 'CajaVenta'
ORDER  BY m.Nombre, s.Nombre;
GO

-- ── Desactivar la entrada de CajaVenta que está bajo "Ventas" ──
UPDATE dbo.SUBMENU
   SET Activo = 0
WHERE  Controlador = 'CajaVenta'
  AND  IdMenu = (
      SELECT IdMenu FROM dbo.MENU
      WHERE  Nombre IN ('Venta', 'Ventas')
  );

PRINT 'Filas actualizadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ── Verificación final ────────────────────────────────────────
SELECT
    s.IdSubMenu,
    m.Nombre  AS Menu,
    s.Nombre  AS Submenu,
    s.Activo
FROM   dbo.SUBMENU s
INNER  JOIN dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE  s.Controlador = 'CajaVenta'
ORDER  BY m.Nombre;
GO

PRINT '════ Script 64 completado ════';
GO
