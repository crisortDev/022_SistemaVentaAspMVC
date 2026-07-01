-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 129: usp_ObtenerOperacionesCaja — incluye cobros CXC en el listado
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- PROBLEMA:
--   El grid "Operaciones del turno" solo mostraba VENTAS nuevas.
--   Los cobros de deuda (COBRO_CXC) aparecían en el arqueo de cierre pero
--   no en el listado de operaciones de la caja activa.
--
-- FIX:
--   RS1 ahora incluye con UNION los cobros CXC de la caja, marcados con
--   Condicion='CobroCXC' para que el JS los distinga y muestre diferente.
--   RS2 (resumen) también los incluye en el total por forma de cobro.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerOperacionesCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda      INT,
            @FechaApertura DATETIME,
            @FechaCorte    DATETIME;

    SELECT @IdTienda      = IdTienda,
           @FechaApertura = FechaApertura,
           @FechaCorte    = ISNULL(FechaCierre, GETDATE())
    FROM   dbo.CAJA
    WHERE  IdCaja = @IdCaja;

    -- ── RS1: Ventas del turno + Cobros CXC del turno ──────────────────────────
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        CONVERT(VARCHAR(19), v.FechaRegistro, 120)               AS FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')                     AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        v.TotalCosto                                             AS Monto,
        ISNULL(cc.MontoRecibido, 0)                              AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                              AS MontoCambio,
        u.Nombres + ' ' + u.Apellidos                            AS NombreCajero,
        v.Estado,
        ISNULL(v.Condicion, 'Contado')                           AS Condicion

    FROM   dbo.VENTA              v
    INNER  JOIN dbo.USUARIO       u  ON u.IdUsuario     = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE       c  ON c.IdCliente     = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta  = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO   fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.Estado IN ('Activa', 'Anulada')
      AND  v.IdTienda = @IdTienda
      AND  (
              v.IdCaja = @IdCaja
           OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte)
           )

    UNION ALL

    -- Cobros de deuda CXC recibidos en esta caja
    SELECT
        NULL                                                     AS IdVenta,
        vv.NumeroFactura,
        CONVERT(VARCHAR(19), cx.FechaCobro, 120)                 AS FechaRegistro,
        ISNULL(cli.Nombre, 'Consumidor Final')                   AS NombreCliente,
        ISNULL(fcc.Nombre, ISNULL(fcc.Descripcion, 'Efectivo'))  AS FormaCobro,
        cx.MontoRecibido                                         AS Monto,
        cx.MontoRecibido                                         AS MontoRecibido,
        cx.MontoCambio                                           AS MontoCambio,
        u2.Nombres + ' ' + u2.Apellidos                          AS NombreCajero,
        'Cobrada'                                                AS Estado,
        'CobroCXC'                                               AS Condicion   -- marca especial

    FROM   dbo.COBRO_CXC          cx
    INNER  JOIN dbo.COMPROBANTE_COBRO comp ON comp.IdComprobanteCobro = cx.IdCompCobro
    INNER  JOIN dbo.VENTA         vv       ON vv.IdVenta  = comp.IdVenta
    INNER  JOIN dbo.USUARIO       u2       ON u2.IdUsuario = cx.IdUsuario
    LEFT   JOIN dbo.CLIENTE       cli      ON cli.IdCliente = vv.IdCliente
    LEFT   JOIN dbo.FORMA_COBRO   fcc      ON fcc.IdFormaCobro = cx.IdFormaCobro
    WHERE  cx.IdCaja = @IdCaja

    ORDER  BY FechaRegistro;

    -- ── RS2: Resumen por forma de cobro (ventas contado + cobros CXC) ─────────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        COUNT(*)                                                  AS Cantidad,
        SUM(Monto)                                                AS TotalMonto
    FROM (
        -- Ventas contado cobradas
        SELECT cc.IdFormaCobro, v.TotalCosto AS Monto
        FROM   dbo.VENTA v
        INNER  JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
        WHERE  v.Estado = 'Activa'
          AND  v.IdTienda = @IdTienda
          AND  (v.IdCaja = @IdCaja OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte))
          AND  ISNULL(v.Condicion,'Contado') = 'Contado'

        UNION ALL

        -- Cobros CXC de esta caja
        SELECT cx.IdFormaCobro, cx.MontoRecibido AS Monto
        FROM   dbo.COBRO_CXC cx
        WHERE  cx.IdCaja = @IdCaja
    ) sub
    LEFT JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = sub.IdFormaCobro
    GROUP BY fc.Nombre, fc.Descripcion
    ORDER BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja — incluye cobros CXC en RS1 y RS2.';
GO

PRINT '════ Script 129 completado ════';
GO
