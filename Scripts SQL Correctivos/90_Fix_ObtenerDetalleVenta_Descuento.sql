-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 90: Actualizar usp_ObtenerDetalleVenta_v2 — incluir PorcentajeDescuento
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- Contexto:
--   El script 89 agregó la columna PorcentajeDescuento a DETALLE_VENTA y la llena
--   correctamente al facturar desde una pre-venta (usp_FacturarDesdeOrdenVenta).
--   Sin embargo, el SP de lectura usp_ObtenerDetalleVenta_v2 (creado/actualizado
--   en script 80) no devuelve esa columna.
--
-- Este script actualiza el RS2 (detalle de productos) para incluir PorcentajeDescuento.
-- Nota: PrecioUnidad en DETALLE_VENTA ya es el precio efectivo (post-descuento).
--       PorcentajeDescuento indica qué % se aplicó, para mostrarlo en el documento.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── RS1: Cabecera de la venta ─────────────────────────────────────────────
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
        -- Emisor
        t.Nombre    AS NombreEmisor,
        t.RUC       AS RUCEmisor,
        t.Direccion AS DireccionEmisor,
        t.Telefono  AS TelefonoEmisor,
        -- Timbrado
        dt.Establecimiento,
        dt.PuntoExpedicion,
        -- Cajero
        u.Nombres + ' ' + u.Apellidos                               AS NombreCajero,
        -- Cliente
        c.Nombre          AS NombreCliente,
        c.NumeroDocumento AS DocumentoCliente,
        -- Forma de cobro
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))       AS FormaCobro,
        -- OV origen
        ISNULL(ov.NumeroOV, '')                                     AS NumeroOV
    FROM dbo.VENTA v
    INNER JOIN dbo.TIENDA             t  ON t.IdTienda      = v.IdTienda
    INNER JOIN dbo.USUARIO            u  ON u.IdUsuario     = v.IdUsuario
    INNER JOIN dbo.CLIENTE            c  ON c.IdCliente     = v.IdCliente
    LEFT  JOIN dbo.FORMA_COBRO        fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT  JOIN dbo.ORDEN_VENTA        ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    CROSS JOIN dbo.DATOS_TRIBUTARIOS  dt
    WHERE v.IdVenta = @IdVenta;

    -- ── RS2: Detalle de productos (PrecioUnidad ya es el precio con descuento) ──
    SELECT
        dv.IdDetalleVenta,
        dv.IdProducto,
        p.Codigo  AS CodigoProducto,
        p.Nombre  AS NombreProducto,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        -- ImporteTotal = precio efectivo × cantidad
        dv.Cantidad * dv.PrecioUnidad                               AS ImporteTotal,
        -- ImporteSinIva = base imponible
        CASE
            WHEN dv.IvaPorcentaje = 10 THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.10 AS DECIMAL(18,2))
            WHEN dv.IvaPorcentaje = 5  THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.05 AS DECIMAL(18,2))
            ELSE dv.Cantidad * dv.PrecioUnidad
        END                                                         AS ImporteSinIva,
        dv.Cantidad * dv.PrecioUnidad                               AS ImporteTotalIvaIncluido,
        -- Descuento aplicado (0 si no hubo)
        ISNULL(dv.PorcentajeDescuento, 0)                           AS PorcentajeDescuento
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2 actualizado — incluye PorcentajeDescuento en RS2.';
GO

PRINT '════ Script 90 completado ════';
GO
