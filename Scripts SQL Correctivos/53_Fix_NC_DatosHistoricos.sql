-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 53: Corrección retroactiva de datos históricos de Notas de Crédito
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
--
-- PROBLEMA DETECTADO al ejecutar Script 52:
--
--   A) NCs ya en estado 'Recibida' (IdCompra 11 y 15) nunca tuvieron
--      COMPRA.TotalCosto reducido, porque el SP anterior no lo hacía.
--      Hay que aplicar el descuento retroactivamente.
--
--   B) Varias compras tienen COMPRA.MontoNotaCredito > 0 pero no existe
--      ninguna fila en NOTA_CREDITO asociada (son datos de prueba inconsistentes).
--      Se limpia MontoNotaCredito = 0 en esos casos.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO PREVIO
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '── Estado antes de la corrección ──────────────────────────────';
SELECT c.IdCompra, c.NumeroFactura,
       c.TotalCosto,
       c.MontoNotaCredito,
       nc.Estado   AS EstadoNC,
       nc.Monto    AS MontoNC
FROM   dbo.COMPRA c
LEFT   JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
WHERE  c.MontoNotaCredito > 0
ORDER  BY c.IdCompra;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO A: Aplicar reducción retroactiva a NCs ya 'Recibida'
--   El SP anterior no reducía TotalCosto → lo aplicamos ahora.
--   Solo afecta compras cuya NC está en 'Recibida'.
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE c
SET    c.TotalCosto = CASE
                          WHEN c.TotalCosto >= nc.Monto
                          THEN c.TotalCosto - nc.Monto
                          ELSE 0
                      END
FROM   dbo.COMPRA c
INNER  JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
WHERE  nc.Estado = 'Recibida';

PRINT 'OK: TotalCosto reducido en NCs Recibidas. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO B: Limpiar MontoNotaCredito en compras sin NC asociada
--   Son datos de prueba inconsistentes: COMPRA.MontoNotaCredito > 0
--   pero no existe fila en NOTA_CREDITO para esa compra.
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE dbo.COMPRA
SET    MontoNotaCredito = 0
WHERE  MontoNotaCredito > 0
  AND  IdCompra NOT IN (SELECT IdCompra FROM dbo.NOTA_CREDITO);

PRINT 'OK: MontoNotaCredito limpiado en compras sin NC registrada. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN FINAL
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '── Estado después de la corrección ────────────────────────────';
SELECT c.IdCompra, c.NumeroFactura,
       c.TotalCosto         AS TotalActual,
       c.MontoNotaCredito,
       nc.Estado            AS EstadoNC,
       nc.Monto             AS MontoNC
FROM   dbo.COMPRA c
LEFT   JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
WHERE  nc.IdNC IS NOT NULL OR c.MontoNotaCredito > 0
ORDER  BY c.IdCompra DESC;
GO
