-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 22: Actualizar usp_ObtenerDetalleCompra
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Agrega al XML de detalle de compra:
--   - Estado, FechaFactura, FechaEntrega, MontoNotaCredito, NumeroOrden
--   - En productos: CantidadRecibida, EstadoLinea
--
-- Esto permite que el documento Razor muestre información completa:
-- estado de la factura, NC aplicada, OC de origen, y cantidades reales recibidas.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleCompra]
    @IdCompra INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        -- ── Cabecera compra ────────────────────────────────────────────
        c.IdCompra,
        RIGHT('000000' + CONVERT(VARCHAR, c.IdCompra), 6)    AS Codigo,
        c.NumeroFactura,
        c.NumeroTimbrado,
        CONVERT(CHAR(10), c.VencimientoTimbrado, 103)          AS FechaVencimientoTimbrado,
        CONVERT(CHAR(10), c.FechaRegistro,       103)          AS FechaCompra,
        CONVERT(CHAR(10), c.FechaFactura,        103)          AS FechaFactura,
        CONVERT(CHAR(10), c.FechaEntrega,        103)          AS FechaEntrega,
        c.TotalCosto,
        ISNULL(c.TotalCosto * 1.10, 0)                         AS TotalCostoIvaIncluido,
        c.Estado,
        c.EstadoRecepcion,
        ISNULL(c.MontoNotaCredito, 0)                          AS MontoNotaCredito,

        -- ── Proveedor ─────────────────────────────────────────────────
        (SELECT
            p.RUC                                              AS [RUC],
            p.RazonSocial                                      AS [RazonSocial],
            ISNULL(p.Telefono, '')                             AS [Telefono],
            ISNULL(p.Correo,   '')                             AS [Correo],
            ISNULL(p.Direccion,'')                             AS [Direccion]
         FROM dbo.PROVEEDOR p
         WHERE p.IdProveedor = c.IdProveedor
         FOR XML PATH('DETALLE_PROVEEDOR'), TYPE),

        -- ── Tienda destino ────────────────────────────────────────────
        (SELECT
            t.RUC                                              AS [RUC],
            t.Nombre                                           AS [Nombre],
            ISNULL(t.Direccion,'')                             AS [Direccion]
         FROM dbo.TIENDA t
         WHERE t.IdTienda = c.IdTienda
         FOR XML PATH('DETALLE_TIENDA'), TYPE),

        -- ── OC vinculada (si existe) ──────────────────────────────────
        (SELECT TOP 1
            oc.IdOrdenCompra                                   AS [IdOrdenCompra],
            oc.NumeroOrden                                     AS [NumeroOrden]
         FROM dbo.CompraOrdenCompra coc
         INNER JOIN dbo.OrdenCompra oc ON oc.IdOrdenCompra = coc.IdOrdenCompra
         WHERE coc.IdCompra = c.IdCompra
         FOR XML PATH('DETALLE_OC'), TYPE),

        -- ── Líneas de producto ────────────────────────────────────────
        (SELECT
            dc.IdDetalleCompra,
            pr.Codigo                                          AS [CodigoProducto],
            pr.Nombre                                          AS [NombreProducto],
            dc.Cantidad,
            ISNULL(dc.CantidadRecibida, dc.Cantidad)           AS [CantidadRecibida],
            dc.PrecioUnitarioCompra,
            dc.TotalCosto,
            ISNULL(dc.TotalCosto * 1.10, 0)                    AS [TotalCostoIvaIncluido],
            ISNULL(dc.EstadoLinea, 'Pendiente')                AS [EstadoLinea]
         FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO pr ON pr.IdProducto = dc.IdProducto
         WHERE dc.IdCompra = c.IdCompra
           AND dc.Activo   = 1
         ORDER BY dc.IdDetalleCompra
         FOR XML PATH('PRODUCTO'), ROOT('DETALLE_PRODUCTO'), TYPE)

    FROM dbo.COMPRA c
    WHERE c.IdCompra = @IdCompra
    FOR XML PATH('DETALLE_COMPRA');
END
GO

PRINT 'OK: usp_ObtenerDetalleCompra actualizado — incluye Estado, FechaFactura, MontoNC, OC, CantidadRecibida, EstadoLinea'
