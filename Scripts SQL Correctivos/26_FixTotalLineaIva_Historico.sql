-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 26: Corregir TotalLineaIva = 0 en registros históricos de OC
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Problema: órdenes registradas antes del Script 25 (server-side recalc)
--           quedaron con TotalLineaIva = 0 en DetalleOrdenCompra
--           y TotalEstimadoIva = 0 en OrdenCompra.
--
-- Paso 1: recalcula TotalLineaIva en cada línea de detalle.
-- Paso 2: recalcula TotalEstimadoIva en la cabecera sumando las líneas ya corregidas.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: Corregir líneas de detalle ───────────────────────────────────────
UPDATE dbo.DetalleOrdenCompra
SET    TotalLineaIva = TotalLinea * (1 + IvaPorcentaje / 100.0)
WHERE  TotalLineaIva = 0
  AND  TotalLinea    > 0;

PRINT 'OK: DetalleOrdenCompra — ' + CAST(@@ROWCOUNT AS VARCHAR) + ' líneas corregidas (TotalLineaIva).';
GO

-- ── PASO 2: Recalcular totales de cabecera ───────────────────────────────────
UPDATE oc
SET    oc.TotalEstimadoIva = (
           SELECT ISNULL(SUM(d.TotalLineaIva), 0)
           FROM   dbo.DetalleOrdenCompra d
           WHERE  d.IdOrdenCompra = oc.IdOrdenCompra
       )
FROM   dbo.OrdenCompra oc
WHERE  oc.TotalEstimadoIva = 0;

PRINT 'OK: OrdenCompra — ' + CAST(@@ROWCOUNT AS VARCHAR) + ' cabeceras corregidas (TotalEstimadoIva).';
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
PRINT '══ Detalle con TotalLineaIva = 0 restantes ══';
SELECT COUNT(*) AS PendientesDetalle
FROM   dbo.DetalleOrdenCompra
WHERE  TotalLineaIva = 0 AND TotalLinea > 0;

PRINT '══ Cabeceras con TotalEstimadoIva = 0 restantes ══';
SELECT COUNT(*) AS PendientesCabecera
FROM   dbo.OrdenCompra
WHERE  TotalEstimadoIva = 0;

PRINT 'Script 26 completado.'
GO
