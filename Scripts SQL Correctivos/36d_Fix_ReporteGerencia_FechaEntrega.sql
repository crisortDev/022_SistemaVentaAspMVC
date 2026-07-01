-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 36d: Corrige usp_ReporteGerenciaCompras
-- Fix: FechaTopeEntrega no existe → columna real es FechaEntregaEstimada
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ReporteGerenciaCompras]
    @FechaInicio DATE,
    @FechaFin    DATE,
    @IdTienda    INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FechaFinDia DATETIME = DATEADD(MILLISECOND, -3,
                                    DATEADD(DAY, 1, CAST(@FechaFin AS DATETIME)));

    -- ══════════════════════════════════════════════════════════════
    -- RS1: KPIs generales de COMPRAS del período
    -- ══════════════════════════════════════════════════════════════
    SELECT
        COUNT(*)                                                             AS TotalCompras,
        ISNULL(SUM(c.TotalCosto),        0)                                  AS MontoTotalCompras,
        ISNULL(SUM(c.TotalCosto * 1.10), 0)                                  AS MontoTotalConIVA,
        COUNT(CASE WHEN c.Estado = 'Confirmada'                  THEN 1 END) AS Confirmadas,
        COUNT(CASE WHEN c.Estado IN ('Pendiente','EnRecepcion')  THEN 1 END) AS EnProceso,
        COUNT(CASE WHEN c.Estado = 'Anulada'                     THEN 1 END) AS Anuladas,
        ISNULL(SUM(ISNULL(c.MontoNotaCredito, 0)), 0)                        AS MontoTotalNC,
        (SELECT COUNT(*) FROM dbo.OrdenCompra oc2
          WHERE oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Activo = 1)                                              AS TotalOC,
        (SELECT COUNT(*) FROM dbo.OrdenCompra oc2
          WHERE oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Estado = 'Pendiente' AND oc2.Activo = 1)                 AS OCPendientes,
        (SELECT COUNT(*) FROM dbo.OrdenCompra oc2
          WHERE oc2.FechaEntregaEstimada < CAST(GETDATE() AS DATE)
            AND oc2.Estado NOT IN ('Facturada','Cerrada','Anulada')
            AND oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Activo = 1)                                              AS OCFueraPlazo
      FROM dbo.COMPRA c
     WHERE c.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda);

    -- ══════════════════════════════════════════════════════════════
    -- RS2: Órdenes de Compra por estado
    -- ══════════════════════════════════════════════════════════════
    SELECT
        ISNULL(oc.Estado, 'Sin estado')    AS Estado,
        COUNT(*)                           AS Cantidad,
        ISNULL(SUM(oc.TotalEstimado), 0)   AS MontoTotal
      FROM dbo.OrdenCompra oc
     WHERE oc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR oc.IdTienda = @IdTienda)
       AND oc.Activo = 1
     GROUP BY oc.Estado
     ORDER BY Cantidad DESC;

    -- ══════════════════════════════════════════════════════════════
    -- RS3: Compras por mes (tendencia)
    -- ══════════════════════════════════════════════════════════════
    SELECT
        YEAR(c.FechaRegistro)        AS Anio,
        MONTH(c.FechaRegistro)       AS Mes,
        CASE MONTH(c.FechaRegistro)
            WHEN 1  THEN 'Ene' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
            WHEN 4  THEN 'Abr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
            WHEN 7  THEN 'Jul' WHEN 8  THEN 'Ago' WHEN 9  THEN 'Sep'
            WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dic'
        END                          AS MesNombre,
        COUNT(*)                     AS Cantidad,
        ISNULL(SUM(c.TotalCosto), 0) AS Monto
      FROM dbo.COMPRA c
     WHERE c.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda)
     GROUP BY YEAR(c.FechaRegistro), MONTH(c.FechaRegistro)
     ORDER BY Anio, Mes;

    -- ══════════════════════════════════════════════════════════════
    -- RS4: Top 5 proveedores por monto comprado
    -- ══════════════════════════════════════════════════════════════
    SELECT TOP 5
        p.RazonSocial                   AS Proveedor,
        COUNT(c.IdCompra)               AS TotalCompras,
        ISNULL(SUM(c.TotalCosto), 0)    AS MontoTotal
      FROM dbo.COMPRA    c
      JOIN dbo.PROVEEDOR p ON p.IdProveedor = c.IdProveedor
     WHERE c.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda)
     GROUP BY p.RazonSocial
     ORDER BY MontoTotal DESC;

    -- ══════════════════════════════════════════════════════════════
    -- RS5: Resumen de Notas de Crédito del período
    -- ══════════════════════════════════════════════════════════════
    SELECT
        COUNT(*)                                                                    AS TotalNC,
        SUM(CASE WHEN nc.Estado = 'Pendiente'                                  THEN 1 ELSE 0 END) AS Pendientes,
        SUM(CASE WHEN nc.Estado = 'Recibida'                                   THEN 1 ELSE 0 END) AS Recibidas,
        SUM(CASE WHEN nc.Estado = 'Rechazada'                                  THEN 1 ELSE 0 END) AS Rechazadas,
        SUM(CASE WHEN nc.Estado = 'Pendiente'
                  AND c.FechaFactura IS NOT NULL
                  AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30            THEN 1 ELSE 0 END) AS Morosas,
        ISNULL(SUM(nc.Monto), 0)                                                   AS MontoTotal
      FROM dbo.NOTA_CREDITO nc
      JOIN dbo.COMPRA c ON c.IdCompra = nc.IdCompra
     WHERE nc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda);

    -- ══════════════════════════════════════════════════════════════
    -- RS6: OCs fuera del plazo de entrega (TOP 10)
    -- ══════════════════════════════════════════════════════════════
    SELECT TOP 10
        oc.NumeroOrden,
        p.RazonSocial                                                    AS Proveedor,
        t.Nombre                                                         AS Tienda,
        CONVERT(VARCHAR(10), oc.FechaEntregaEstimada, 103)               AS FechaTopeEntrega,
        ISNULL(oc.TotalEstimado, 0)                                      AS MontoEstimado,
        oc.Estado,
        DATEDIFF(DAY, oc.FechaEntregaEstimada, CAST(GETDATE() AS DATE))  AS DiasVencida
      FROM dbo.OrdenCompra oc
      JOIN dbo.PROVEEDOR   p ON p.IdProveedor = oc.IdProveedor
      JOIN dbo.TIENDA      t ON t.IdTienda    = oc.IdTienda
     WHERE oc.FechaEntregaEstimada IS NOT NULL
       AND oc.FechaEntregaEstimada < CAST(GETDATE() AS DATE)
       AND oc.Estado NOT IN ('Facturada','Cerrada','Anulada')
       AND oc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR oc.IdTienda = @IdTienda)
       AND oc.Activo = 1
     ORDER BY DiasVencida DESC;

END
GO
PRINT 'OK: usp_ReporteGerenciaCompras corregida (FechaEntregaEstimada).';
GO
