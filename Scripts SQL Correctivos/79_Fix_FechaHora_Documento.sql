-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 79: Agregar hora a FechaRegistro en usp_ObtenerDetalleVenta_v2
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- Punto s) La factura debe mostrar fecha Y hora de emisión.
-- Cambia: CONVERT(VARCHAR(10), v.FechaRegistro, 103)
--   por:  FORMAT(v.FechaRegistro, 'dd/MM/yyyy HH:mm')
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera de la venta (KuDE)
    SELECT
        v.IdVenta, v.Codigo, v.NumeroFactura, v.NumeroTimbrado,
        CONVERT(VARCHAR(10), v.VencimientoTimbrado, 103)           AS VencimientoTimbrado,
        -- fecha + hora de emisión (punto s)
        FORMAT(v.FechaRegistro, 'dd/MM/yyyy HH:mm')                AS FechaRegistro,
        v.TipoDocumento, v.TipoFlujo, v.Estado,
        v.TotalCosto, v.ImporteRecibido, v.ImporteCambio,
        v.IVA10, v.IVA5, v.Exento0,
        v.TotalCosto - v.IVA10 - v.IVA5 - v.Exento0               AS Gravado10,
        v.IVA5                                                     AS Gravado5Base,
        -- Emisor
        t.Nombre    AS NombreEmisor,
        t.RUC       AS RUCEmisor,
        t.Direccion AS DireccionEmisor,
        t.Telefono  AS TelefonoEmisor,
        -- Timbrado
        dt.Establecimiento,
        dt.PuntoExpedicion,
        -- Cajero
        u.Nombres + ' ' + u.Apellidos                              AS NombreCajero,
        -- Cliente
        c.Nombre           AS NombreCliente,
        c.NumeroDocumento  AS DocumentoCliente,
        c.TipoDocumento    AS TipoDocumentoCliente,
        c.Direccion        AS DireccionCliente,
        c.Telefono         AS TelefonoCliente,
        -- Forma de cobro
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))      AS FormaCobro,
        -- OV origen (si aplica)
        ISNULL(ov.NumeroOV, '')                                    AS NumeroOV
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
        p.Codigo        AS CodigoProducto,
        p.Nombre        AS NombreProducto,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        dv.Cantidad * dv.PrecioUnidad                              AS ImporteTotal,
        CASE
            WHEN dv.IvaPorcentaje = 10
                THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.10 AS DECIMAL(18,2))
            WHEN dv.IvaPorcentaje = 5
                THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.05 AS DECIMAL(18,2))
            ELSE dv.Cantidad * dv.PrecioUnidad
        END                                                        AS ImporteSinIva,
        dv.Cantidad * dv.PrecioUnidad                              AS ImporteTotalIvaIncluido
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO

PRINT 'OK: usp_ObtenerDetalleVenta_v2 actualizado (FechaRegistro incluye hora).';
GO
