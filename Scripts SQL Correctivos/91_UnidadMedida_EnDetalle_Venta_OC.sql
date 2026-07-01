-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 91: Agregar UnidadMedida en detalle de Venta y Orden de Compra
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- Cambios:
--   1. usp_ObtenerDetalleVenta_v2  → RS2 agrega UnidadMedida desde PRODUCTO
--   2. usp_ObtenerDetalleOrdenCompra → XML agrega UnidadMedida en cada PRODUCTO
--
-- Motivo: mostrar "15 mts" / "2 und." en factura impresa y en recepción de OC.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. usp_ObtenerDetalleVenta_v2 ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera de la venta
    SELECT
        v.IdVenta, v.Codigo, v.NumeroFactura, v.NumeroTimbrado,
        CONVERT(VARCHAR(10), v.VencimientoTimbrado, 103)            AS VencimientoTimbrado,
        FORMAT(v.FechaRegistro, 'dd/MM/yyyy HH:mm')                 AS FechaRegistro,
        v.TipoDocumento, v.TipoFlujo, v.Estado,
        v.TotalCosto, v.ImporteRecibido, v.ImporteCambio,
        v.IVA10, v.IVA5, v.Exento0,
        v.TotalCosto - v.IVA10 - v.IVA5 - v.Exento0                AS Gravado10,
        v.IVA5                                                      AS Gravado5Base,
        ISNULL(v.Condicion, 'Contado')                              AS Condicion,
        v.PlazoCredito,
        CONVERT(VARCHAR(10), v.FechaVencimientoCredito, 103)        AS FechaVencimientoCredito,
        t.Nombre    AS NombreEmisor,
        t.RUC       AS RUCEmisor,
        t.Direccion AS DireccionEmisor,
        t.Telefono  AS TelefonoEmisor,
        dt.Establecimiento,
        dt.PuntoExpedicion,
        u.Nombres + ' ' + u.Apellidos                               AS NombreCajero,
        c.Nombre          AS NombreCliente,
        c.NumeroDocumento AS DocumentoCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))       AS FormaCobro,
        ISNULL(ov.NumeroOV, '')                                     AS NumeroOV
    FROM dbo.VENTA v
    INNER JOIN dbo.TIENDA             t  ON t.IdTienda      = v.IdTienda
    INNER JOIN dbo.USUARIO            u  ON u.IdUsuario     = v.IdUsuario
    INNER JOIN dbo.CLIENTE            c  ON c.IdCliente     = v.IdCliente
    LEFT  JOIN dbo.FORMA_COBRO        fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT  JOIN dbo.ORDEN_VENTA        ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    CROSS JOIN dbo.DATOS_TRIBUTARIOS  dt
    WHERE v.IdVenta = @IdVenta;

    -- RS2: Detalle de productos
    SELECT
        dv.IdDetalleVenta,
        dv.IdProducto,
        p.Codigo  AS CodigoProducto,
        p.Nombre  AS NombreProducto,
        ISNULL(p.UnidadMedida, 'Unidad')                            AS UnidadMedida,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        dv.Cantidad * dv.PrecioUnidad                               AS ImporteTotal,
        CASE
            WHEN dv.IvaPorcentaje = 10 THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.10 AS DECIMAL(18,2))
            WHEN dv.IvaPorcentaje = 5  THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.05 AS DECIMAL(18,2))
            ELSE dv.Cantidad * dv.PrecioUnidad
        END                                                         AS ImporteSinIva,
        dv.Cantidad * dv.PrecioUnidad                               AS ImporteTotalIvaIncluido,
        ISNULL(dv.PorcentajeDescuento, 0)                           AS PorcentajeDescuento
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2 — RS2 incluye UnidadMedida.';
GO

-- ─── 2. usp_ObtenerDetalleOrdenCompra ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleOrdenCompra]
    @IdOrdenCompra INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        oc.IdOrdenCompra,
        oc.NumeroOrden,
        CONVERT(VARCHAR(10), oc.FechaOrden,           103)     AS FechaOrden,
        CONVERT(VARCHAR(10), oc.FechaEntregaEstimada,  103)    AS FechaEntregaEstimada,
        CONVERT(VARCHAR(10), oc.FechaTopeEntrega,      103)    AS FechaTopeEntrega,
        ISNULL(oc.Observacion, '')                              AS Observacion,
        oc.TotalEstimado,
        oc.TotalEstimadoIva,
        oc.Estado,
        CONVERT(VARCHAR(10), oc.FechaAprobacion, 103)          AS FechaAprobacion,
        ISNULL(oc.MotivoRechazo, '')                            AS MotivoRechazo,

        -- ── Proveedor ──────────────────────────────────────────────────
        (SELECT
            pr.IdProveedor                                      AS [IdProveedor],
            pr.RUC                                              AS [RUC],
            pr.RazonSocial                                      AS [RazonSocial],
            ISNULL(pr.Telefono,  '')                            AS [Telefono],
            ISNULL(pr.Correo,    '')                            AS [Correo],
            ISNULL(pr.Direccion, '')                            AS [Direccion]
         FROM dbo.PROVEEDOR pr
         WHERE pr.IdProveedor = oc.IdProveedor
         FOR XML PATH('DETALLE_PROVEEDOR'), TYPE),

        -- ── Tienda ─────────────────────────────────────────────────────
        (SELECT
            t.IdTienda                                          AS [IdTienda],
            t.RUC                                              AS [RUC],
            t.Nombre                                           AS [Nombre],
            ISNULL(t.Direccion, '')                            AS [Direccion]
         FROM dbo.TIENDA t
         WHERE t.IdTienda = oc.IdTienda
         FOR XML PATH('DETALLE_TIENDA'), TYPE),

        -- ── Usuario que registró ────────────────────────────────────────
        (SELECT
            u.IdUsuario                                         AS [IdUsuario],
            u.Nombres                                           AS [Nombres],
            u.Apellidos                                         AS [Apellidos]
         FROM dbo.USUARIO u
         WHERE u.IdUsuario = oc.IdUsuarioRegistro
         FOR XML PATH('DETALLE_USUARIO'), TYPE),

        -- ── Líneas de producto ─────────────────────────────────────────
        (SELECT
            doc.IdDetalleOrdenCompra                           AS [IdDetalleOrdenCompra],
            doc.IdProducto                                     AS [IdProducto],
            p.Codigo                                           AS [CodigoProducto],
            p.Nombre                                           AS [NombreProducto],
            ISNULL(p.UnidadMedida, 'Unidad')                   AS [UnidadMedida],
            doc.Cantidad                                       AS [Cantidad],
            ISNULL(doc.CantidadFacturada, 0)                   AS [CantidadFacturada],
            doc.PrecioUnitario                                 AS [PrecioUnitario],
            doc.IvaPorcentaje                                  AS [IvaPorcentaje],
            doc.TotalLinea                                     AS [TotalLinea],
            doc.TotalLineaIva                                  AS [TotalLineaIva]
         FROM dbo.DetalleOrdenCompra doc
         INNER JOIN dbo.PRODUCTO p ON p.IdProducto = doc.IdProducto
         WHERE doc.IdOrdenCompra = oc.IdOrdenCompra
           AND doc.Activo = 1
         ORDER BY doc.IdDetalleOrdenCompra
         FOR XML PATH('PRODUCTO'), ROOT('DETALLE_PRODUCTO'), TYPE)

    FROM dbo.OrdenCompra oc
    WHERE oc.IdOrdenCompra = @IdOrdenCompra
    FOR XML PATH('DETALLE_ORDEN_COMPRA');
END
GO
PRINT 'OK: usp_ObtenerDetalleOrdenCompra — XML incluye UnidadMedida en cada PRODUCTO.';
GO

PRINT '════ Script 91 completado ════';
GO
