-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 123: Fix usp_ObtenerOperacionesCaja — fallback por fecha para ventas huérfanas
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- PROBLEMA:
--   Script 118 dejó el filtro como: WHERE v.IdCaja = @IdCaja (estricto).
--   Ventas con v.IdCaja = NULL (ventas anteriores o de sesiones sin caja activa)
--   no aparecen en el historial. Afecta especialmente a SuperAdmin que puede
--   visualizar cajas con ventas históricas.
--
-- FIX (consistente con usp_ObtenerDetalleCaja — script 115):
--   Misma lógica del cuadre: IdCaja estricto cuando está seteado; fallback por
--   fecha cuando IdCaja es NULL.
--   Aplica a TODOS los roles (cajero, supervisor, SuperAdmin).
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

    -- RS1: detalle operación por operación
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
              v.IdCaja = @IdCaja                                  -- venta con caja explícita
           OR (v.IdCaja IS NULL                                   -- venta huérfana: fallback por fecha
               AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte)
           )
    ORDER  BY v.FechaRegistro;

    -- RS2: resumen por forma de cobro (solo ventas Activas para el cuadre)
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        COUNT(v.IdVenta)                                         AS Cantidad,
        SUM(v.TotalCosto)                                        AS TotalMonto
    FROM   dbo.VENTA              v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta    = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO   fc ON fc.IdFormaCobro   = cc.IdFormaCobro
    WHERE  v.Estado = 'Activa'
      AND  v.IdTienda = @IdTienda
      AND  (
              v.IdCaja = @IdCaja
           OR (v.IdCaja IS NULL
               AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte)
           )
    GROUP  BY ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja — fallback por fecha para ventas huérfanas (IdCaja NULL). Todos los roles.';
GO

-- ── Verificación rápida ───────────────────────────────────────────────────────
SELECT TOP 5
    c.IdCaja, c.IdTienda, c.Estado, c.FechaApertura,
    COUNT(v.IdVenta)      AS VentasConIdCaja,
    COUNT(vn.IdVenta)     AS VentasSinIdCaja
FROM dbo.CAJA c
LEFT JOIN dbo.VENTA v  ON v.IdCaja   = c.IdCaja AND v.Estado IN ('Activa','Anulada')
LEFT JOIN dbo.VENTA vn ON vn.IdCaja IS NULL
                       AND vn.IdTienda = c.IdTienda
                       AND vn.FechaRegistro BETWEEN c.FechaApertura AND ISNULL(c.FechaCierre, GETDATE())
                       AND vn.Estado IN ('Activa','Anulada')
GROUP BY c.IdCaja, c.IdTienda, c.Estado, c.FechaApertura
ORDER BY c.IdCaja DESC;

PRINT '════ Script 123 completado ════';
GO
