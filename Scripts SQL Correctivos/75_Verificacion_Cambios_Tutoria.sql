-- ============================================================
--  Script 75 — Verificación de cambios pedidos en tutoría
--  (no requiere ejecutar cambios de datos, solo lectura)
-- ============================================================
USE [DBVENTAS_WEB]
GO

PRINT '=== Verificación de cambios de tutoría ==='
GO

-- ── 1. Confirmar que el submenú fue renombrado (Script 74) ────
SELECT 'Submenu NC' AS Verificacion,
       s.Nombre,
       CASE WHEN s.Nombre = 'Registrar NC' THEN 'OK' ELSE 'PENDIENTE (ejecutar Script 74)' END AS Estado
FROM   dbo.SUBMENU s
WHERE  s.Nombre IN ('Registrar NC', 'Gestión de NC') AND s.Activo = 1;
GO

-- ── 2. Verificar que la columna IdCaja existe en VENTA ─────────
SELECT 'Columna IdCaja en VENTA' AS Verificacion,
       CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'FALTA' END AS Estado
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME  = 'VENTA'
  AND  COLUMN_NAME = 'IdCaja';
GO

-- ── 3. Confirmar que NOTA_CREDITO tiene FechaFactura accesible ─
-- (viene del JOIN con COMPRA en usp_ObtenerNC — verificar estructura)
SELECT 'Tabla NOTA_CREDITO existe' AS Verificacion, 'OK' AS Estado
WHERE  EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'NOTA_CREDITO');
GO

-- ── 4. Verificar proveedores con deuda pendiente (preview) ─────
SELECT 'Proveedores con OP Pendiente' AS Verificacion,
       p.RazonSocial,
       COUNT(op.IdOrdenPago) AS OPs_Pendientes,
       SUM(op.Monto)         AS Total_Pendiente
FROM   dbo.ORDEN_PAGO op
JOIN   dbo.COMPRA     c ON c.IdCompra     = op.IdCompra
JOIN   dbo.PROVEEDOR  p ON p.IdProveedor  = c.IdProveedor
WHERE  op.Estado = 'Pendiente'
GROUP BY p.RazonSocial
ORDER BY Total_Pendiente DESC;
GO
