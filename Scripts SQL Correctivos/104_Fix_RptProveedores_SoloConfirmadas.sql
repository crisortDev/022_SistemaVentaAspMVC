-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 104: Fix Reporte de Proveedores — contar solo compras CONFIRMADAS
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- PROBLEMA:
--   usp_rptProveedores sumaba c.TotalCosto de TODAS las compras del proveedor,
--   incluyendo Anuladas y Pendientes. Eso infla el total (en esta base:
--   33.074.993 mostrado vs 25.114.991 real confirmado).
--
-- FIX:
--   El join a COMPRA solo considera compras con Estado = 'Confirmada'
--   (las que realmente impactaron inventario y representan deuda/compra real).
--   El resto del SP queda idéntico al script 76b.
--
-- Idempotente. No modifica datos. Hacer BACKUP por las dudas.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

IF OBJECT_ID('dbo.usp_rptProveedores', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_rptProveedores;
GO

CREATE PROCEDURE dbo.usp_rptProveedores
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL,
    @IdTienda     INT  = 0,
    @SoloConDeuda BIT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProveedor,
        p.RazonSocial                                        AS Proveedor,
        p.RUC                                                AS RucProveedor,
        ISNULL(p.Telefono, '')                               AS Telefono,
        ISNULL(p.Correo,   '')                               AS Correo,
        -- Compras CONFIRMADAS en el período
        COUNT(DISTINCT c.IdCompra)                           AS CantidadCompras,
        ISNULL(SUM(c.TotalCosto), 0)                         AS TotalCompras,
        -- NCs
        COUNT(DISTINCT nc.IdNC)                              AS CantidadNC,
        ISNULL(SUM(nc.Monto), 0)                             AS TotalMontoNC,
        -- NC Pendientes
        SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1    ELSE 0  END) AS NCPendientes,
        ISNULL(SUM(CASE WHEN nc.Estado = 'Pendiente' THEN nc.Monto ELSE 0 END), 0) AS MontoNCPendiente,
        -- NC Recibidas / Rechazadas
        SUM(CASE WHEN nc.Estado = 'Recibida'  THEN 1 ELSE 0 END)     AS NCRecibidas,
        SUM(CASE WHEN nc.Estado = 'Rechazada' THEN 1 ELSE 0 END)     AS NCRechazadas,
        -- Monto neto = compras confirmadas − NC recibidas
        ISNULL(SUM(c.TotalCosto), 0)
            - ISNULL(SUM(CASE WHEN nc.Estado = 'Recibida' THEN nc.Monto ELSE 0 END), 0) AS MontoNeto,
        -- Mora
        MAX(CASE WHEN nc.Estado = 'Pendiente'
                  AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
                 THEN 1 ELSE 0 END)                          AS TieneMorosa
    FROM dbo.PROVEEDOR p
    LEFT JOIN dbo.COMPRA c
           ON c.IdProveedor = p.IdProveedor
          AND c.Estado      = 'Confirmada'          -- ← SOLO compras confirmadas
          AND (@IdTienda    = 0  OR c.IdTienda = @IdTienda)
          AND (@FechaInicio IS NULL OR CAST(c.FechaRegistro AS DATE) >= @FechaInicio)
          AND (@FechaFin    IS NULL OR CAST(c.FechaRegistro AS DATE) <= @FechaFin)
    LEFT JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
    WHERE p.Activo = 1
    GROUP BY p.IdProveedor, p.RazonSocial, p.RUC, p.Telefono, p.Correo
    HAVING
        @SoloConDeuda = 0
        OR SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1 ELSE 0 END) > 0
    ORDER BY ISNULL(SUM(c.TotalCosto), 0) DESC;
END
GO
PRINT 'OK: usp_rptProveedores — ahora solo cuenta compras Confirmadas.';
GO

-- ── Verificación: el total debe coincidir con las compras confirmadas ──────────
EXEC dbo.usp_rptProveedores @FechaInicio = NULL, @FechaFin = NULL;
GO
