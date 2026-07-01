-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 45: Corregir usp_ObtenerDetalleOrdenVenta_V — agregar NombreUsuario
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
--
-- El SP original no incluía NombreUsuario en el SELECT del primer resultset,
-- pero CD_OrdenVenta.cs lee dr["NombreUsuario"], lo que lanzaba una
-- IndexOutOfRangeException silenciada por el catch → devolvía null →
-- VentaController.Facturar redirigía al listado sin mostrar la pantalla.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleOrdenVenta_V]
    @IdOrdenVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera de la pre-venta
    SELECT
        ov.IdOrdenVenta,
        ov.NumeroOV,
        ov.Estado,
        ov.TotalEstimado,
        ov.IVA10,
        ov.IVA5,
        ov.Exento0,
        CONVERT(VARCHAR(10), ov.FechaRegistro,   103) AS FechaRegistro,
        CONVERT(VARCHAR(10), ov.FechaVencimiento, 103) AS FechaVencimiento,
        ov.Observacion,
        ov.IdTienda,
        ov.IdCliente,
        ISNULL(c.Nombre,          '')        AS NombreCliente,
        ISNULL(c.NumeroDocumento, '')        AS DocumentoCliente,
        ISNULL(c.Direccion,       '')        AS DireccionCliente,
        ISNULL(c.Telefono,        '')        AS TelefonoCliente,
        ISNULL(c.TipoDocumento,   'CI')      AS TipoDocumentoCliente,
        t.Nombre                             AS NombreTienda,
        t.RUC                                AS RUCTienda,
        u.Nombres + ' ' + u.Apellidos        AS NombreUsuario        -- ← columna faltante
    FROM dbo.ORDEN_VENTA ov
    LEFT  JOIN dbo.CLIENTE  c ON c.IdCliente  = ov.IdCliente
    INNER JOIN dbo.TIENDA   t ON t.IdTienda   = ov.IdTienda
    INNER JOIN dbo.USUARIO  u ON u.IdUsuario  = ov.IdUsuarioRegistro
    WHERE ov.IdOrdenVenta = @IdOrdenVenta;

    -- RS2: Detalle de productos
    SELECT
        d.IdDetalleOV,
        d.IdProducto,
        p.Codigo,
        p.Nombre                     AS NombreProducto,
        d.Cantidad,
        d.PrecioUnidad,
        d.IvaPorcentaje,
        d.TotalLinea,
        d.TotalLineaIva,
        ISNULL(pt.Stock, 0)          AS StockDisponible
    FROM dbo.DETALLE_ORDEN_VENTA d
    INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = d.IdProducto
    LEFT  JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = d.IdProducto
              AND pt.IdTienda = (SELECT IdTienda FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta)
    WHERE d.IdOrdenVenta = @IdOrdenVenta
      AND d.Activo = 1;
END
GO

PRINT 'OK: usp_ObtenerDetalleOrdenVenta_V corregido (NombreUsuario agregado).';
GO
