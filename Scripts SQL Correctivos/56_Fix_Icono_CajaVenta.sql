-- ============================================================
-- Script 56: Corregir ícono del submenú CajaVenta
-- Font Awesome 5 requiere prefijo "fas" antes del nombre del icono
-- ============================================================

UPDATE dbo.SUBMENU
SET    Icono = 'fas fa-cash-register'
WHERE  Controlador = 'CajaVenta'
  AND  Icono       = 'fa-cash-register';

PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' fila(s) actualizada(s).';
GO

-- Verificación
SELECT IdSubMenu, Nombre, Controlador, Icono, Activo
FROM   dbo.SUBMENU
WHERE  Controlador = 'CajaVenta';
GO
