-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 88: Fix cobros CXC huérfanos (IdCaja = NULL) durante una caja activa
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- PROBLEMA:
--   El bug de usp_ObtenerCajaActiva con SuperAdmin (@IdTienda=0) impedía
--   que se cargara Session["CajaId"]. Por eso, cuando el usuario cobró una
--   cuenta desde "Cuentas por Cobrar", usp_CobrarCuentaPendiente insertó
--   en COBRO_CXC con IdCaja = NULL.
--
--   Esos cobros huérfanos no se suman en TotalCobrosCXC de la caja, por lo
--   que no impactan el cuadre ni el saldo esperado.
--
-- SOLUCIÓN:
--   1. Primero ver cuáles son los cobros huérfanos (IdCaja IS NULL) realizados
--      durante el período de la caja que corresponde.
--   2. Vincularlos a la caja correcta actualizando IdCaja.
--
-- IMPORTANTE: Ejecutar primero el SELECT de diagnóstico para verificar
--             antes de aplicar el UPDATE.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: Diagnóstico — ver cobros CXC sin caja asignada ───────────────────
-- Esto muestra qué cobros quedaron huérfanos y a qué caja pertenecerían
SELECT
    cx.IdCobroCXC,
    cx.IdCompCobro,
    cx.FechaCobro,
    cx.MontoRecibido,
    cx.MontoCambio,
    cx.IdCaja                          AS IdCaja_Actual,
    c.IdCaja                           AS IdCaja_Correcta,
    c.FechaApertura,
    c.FechaCierre,
    c.Estado                           AS EstadoCaja,
    t.Nombre                           AS Tienda,
    v.NumeroFactura,
    cli.Nombre                         AS Cliente
FROM dbo.COBRO_CXC cx
INNER JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdComprobanteCobro = cx.IdCompCobro
INNER JOIN dbo.VENTA             v  ON v.IdVenta             = cc.IdVenta
INNER JOIN dbo.CLIENTE           cli ON cli.IdCliente        = v.IdCliente
INNER JOIN dbo.CAJA              c   ON c.IdTienda           = v.IdTienda
                                     AND cx.FechaCobro      >= c.FechaApertura
                                     AND (c.FechaCierre IS NULL OR cx.FechaCobro <= c.FechaCierre)
WHERE cx.IdCaja IS NULL;
GO

-- ── PASO 2: Corrección — vincular los cobros huérfanos a la caja correcta ────
-- Solo ejecutar si el SELECT del PASO 1 muestra los registros esperados.
UPDATE cx
   SET cx.IdCaja = c.IdCaja
FROM dbo.COBRO_CXC cx
INNER JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdComprobanteCobro = cx.IdCompCobro
INNER JOIN dbo.VENTA             v  ON v.IdVenta             = cc.IdVenta
INNER JOIN dbo.CAJA              c   ON c.IdTienda           = v.IdTienda
                                     AND cx.FechaCobro      >= c.FechaApertura
                                     AND (c.FechaCierre IS NULL OR cx.FechaCobro <= c.FechaCierre)
WHERE cx.IdCaja IS NULL;

PRINT 'Filas actualizadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- ── PASO 3: Verificación ──────────────────────────────────────────────────────
-- Confirmar que ya no quedan cobros huérfanos
SELECT COUNT(*) AS CobrosHuerfanos FROM dbo.COBRO_CXC WHERE IdCaja IS NULL;
GO

PRINT '════ Script 88 completado ════';
GO
