-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 36: SP Reporte de Gerencia — Módulo Compras
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- Retorna 6 result sets en una sola llamada:
--   RS1: KPIs generales de compras
--   RS2: Órdenes de Compra por estado
--   RS3: Compras por mes (tendencia)
--   RS4: Top 5 proveedores por monto
--   RS5: Resumen de Notas de Crédito
--   RS6: OCs fuera de plazo de entrega
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ReporteGerenciaCompras]
    @FechaInicio DATE,
    @FechaFin    DATE,
    @IdTienda    INT = 0      -- 0 = todas las tiendas (SuperAdmin)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FechaFinDia DATETIME = DATEADD(MILLISECOND, -3, DATEADD(DAY, 1, @FechaFin));

    -- ══════════════════════════════════════════════════════════════
    -- RS1: KPIs generales de COMPRAS del período
    -- ══════════════════════════════════════════════════════════════
    SELECT
        COUNT(*)                                                         AS TotalCompras,
        ISNULL(SUM(c.TotalCosto),            0)                          AS MontoTotalCompras,
        ISNULL(SUM(c.TotalCostoIvaIncluido), 0)                          AS MontoTotalConIVA,
        COUNT(CASE WHEN c.Estado = 'Confirmada'                  THEN 1 END) AS Confirmadas,
        COUNT(CASE WHEN c.Estado IN ('Pendiente','EnRecepcion')  THEN 1 END) AS EnProceso,
        COUNT(CASE WHEN c.Estado = 'Anulada'                     THEN 1 END) AS Anuladas,
        ISNULL(SUM(ISNULL(c.MontoNotaCredito, 0)), 0)                    AS MontoTotalNC,
        -- OCs del período (para contexto)
        (SELECT COUNT(*) FROM dbo.ORDEN_COMPRA oc2
          WHERE oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Activo = 1)                                          AS TotalOC,
        (SELECT COUNT(*) FROM dbo.ORDEN_COMPRA oc2
          WHERE oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Estado = 'Pendiente' AND oc2.Activo = 1)             AS OCPendientes,
        (SELECT COUNT(*) FROM dbo.ORDEN_COMPRA oc2
          WHERE oc2.FechaTopeEntrega < CAST(GETDATE() AS DATE)
            AND oc2.Estado NOT IN ('Facturada','Cerrada','Anulada')
            AND oc2.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
            AND (@IdTienda = 0 OR oc2.IdTienda = @IdTienda)
            AND oc2.Activo = 1)                                          AS OCFueraPlazo
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
      FROM dbo.ORDEN_COMPRA oc
     WHERE oc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR oc.IdTienda = @IdTienda)
       AND oc.Activo = 1
     GROUP BY oc.Estado
     ORDER BY Cantidad DESC;

    -- ══════════════════════════════════════════════════════════════
    -- RS3: Compras por mes (tendencia)
    -- ══════════════════════════════════════════════════════════════
    SELECT
        YEAR(c.FechaRegistro)                                AS Anio,
        MONTH(c.FechaRegistro)                               AS Mes,
        -- Nombre del mes en español
        CASE MONTH(c.FechaRegistro)
            WHEN 1  THEN 'Ene' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
            WHEN 4  THEN 'Abr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
            WHEN 7  THEN 'Jul' WHEN 8  THEN 'Ago' WHEN 9  THEN 'Sep'
            WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dic'
        END                                                  AS MesNombre,
        COUNT(*)                                             AS Cantidad,
        ISNULL(SUM(c.TotalCosto), 0)                         AS Monto
      FROM dbo.COMPRA c
     WHERE c.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda)
     GROUP BY YEAR(c.FechaRegistro), MONTH(c.FechaRegistro)
     ORDER BY Anio, Mes;

    -- ══════════════════════════════════════════════════════════════
    -- RS4: Top 5 proveedores por monto comprado
    -- ══════════════════════════════════════════════════════════════
    SELECT TOP 5
        p.RazonSocial                      AS Proveedor,
        COUNT(c.IdCompra)                  AS TotalCompras,
        ISNULL(SUM(c.TotalCosto), 0)       AS MontoTotal
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
        COUNT(*)                                                                AS TotalNC,
        SUM(CASE WHEN nc.Estado='Pendiente'                                THEN 1 ELSE 0 END) AS Pendientes,
        SUM(CASE WHEN nc.Estado='Recibida'                                 THEN 1 ELSE 0 END) AS Recibidas,
        SUM(CASE WHEN nc.Estado='Rechazada'                                THEN 1 ELSE 0 END) AS Rechazadas,
        SUM(CASE WHEN nc.Estado='Pendiente'
                  AND c.FechaFactura IS NOT NULL
                  AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30        THEN 1 ELSE 0 END) AS Morosas,
        ISNULL(SUM(nc.Monto), 0)                                               AS MontoTotal
      FROM dbo.NOTA_CREDITO nc
      JOIN dbo.COMPRA c ON c.IdCompra = nc.IdCompra
     WHERE nc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR c.IdTienda = @IdTienda);

    -- ══════════════════════════════════════════════════════════════
    -- RS6: OCs fuera del plazo de entrega (hasta TOP 10)
    -- ══════════════════════════════════════════════════════════════
    SELECT TOP 10
        oc.NumeroOrden,
        p.RazonSocial                                                  AS Proveedor,
        t.Nombre                                                       AS Tienda,
        CONVERT(VARCHAR(10), oc.FechaTopeEntrega, 103)                 AS FechaTopeEntrega,
        ISNULL(oc.TotalEstimado, 0)                                    AS MontoEstimado,
        oc.Estado,
        DATEDIFF(DAY, oc.FechaTopeEntrega, CAST(GETDATE() AS DATE))    AS DiasVencida
      FROM dbo.ORDEN_COMPRA oc
      JOIN dbo.PROVEEDOR    p ON p.IdProveedor = oc.IdProveedor
      JOIN dbo.TIENDA       t ON t.IdTienda    = oc.IdTienda
     WHERE oc.FechaTopeEntrega IS NOT NULL
       AND oc.FechaTopeEntrega < CAST(GETDATE() AS DATE)
       AND oc.Estado NOT IN ('Facturada','Cerrada','Anulada')
       AND oc.FechaRegistro BETWEEN @FechaInicio AND @FechaFinDia
       AND (@IdTienda = 0 OR oc.IdTienda = @IdTienda)
       AND oc.Activo = 1
     ORDER BY DiasVencida DESC;

END
GO
PRINT 'OK: usp_ReporteGerenciaCompras creado (6 result sets).';
GO

-- ── Registrar submenú en Reportes o Compras ──────────────────────────────────
DECLARE @IdMenuReporte INT;
SELECT TOP 1 @IdMenuReporte = IdMenu FROM dbo.MENU
 WHERE Nombre LIKE '%Reporte%' OR Nombre LIKE '%reporte%'
 ORDER BY IdMenu;

IF @IdMenuReporte IS NULL
    SELECT TOP 1 @IdMenuReporte = IdMenu FROM dbo.MENU
     WHERE Nombre LIKE '%Compra%' ORDER BY IdMenu;

IF @IdMenuReporte IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='ReporteGerencia' AND Vista='Index')
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Activo)
    VALUES (@IdMenuReporte, 'Reporte Gerencia Compras', 'ReporteGerencia', 'Index',
            'fas fa-chart-bar', 1);

    -- Permisos a todos los roles que tienen acceso al menú padre
    DECLARE @IdSub INT = SCOPE_IDENTITY();
    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT DISTINCT p.IdRol, @IdSub, 1, GETDATE()
      FROM dbo.PERMISOS p
      JOIN dbo.SUBMENU  s ON s.IdSubMenu = p.IdSubMenu
     WHERE s.IdMenu = @IdMenuReporte AND p.Activo = 1
       AND NOT EXISTS (SELECT 1 FROM dbo.PERMISOS x WHERE x.IdRol=p.IdRol AND x.IdSubMenu=@IdSub);

    PRINT 'OK: Submenú "Reporte Gerencia Compras" registrado.';
END
GO

PRINT 'Script 36 completado.';
GO
