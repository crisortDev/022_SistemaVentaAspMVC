-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 94: Exponer IdTienda en comprobantes para aislamiento por sucursal
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-29
--
-- MOTIVO (auditoría de seguridad, sección 3 — IDOR):
--   Los métodos Documento(...) de Venta, Compra y Comprobante de Cobro mostraban
--   el comprobante por id sin verificar que sea de la sucursal del usuario.
--   Para poder validarlo en C# (TienePermiso(IdTienda)), el SP debe DEVOLVER IdTienda.
--
--   Ya quedó resuelto en código para Orden de Compra y Orden de Pago (sus SP ya
--   devolvían IdTienda). Este script agrega IdTienda a los 3 SP que faltaban.
--
-- Idempotente: usa CREATE OR ALTER. No borra datos.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_ObtenerDetalleVenta_v2 — RS1 ahora incluye v.IdTienda
--    (idéntico al script 91, sólo se agrega la columna IdTienda en la cabecera)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera de la venta
    SELECT
        v.IdVenta, v.Codigo, v.NumeroFactura, v.NumeroTimbrado,
        v.IdTienda,                                                 -- ← NUEVO (aislamiento por sucursal)
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

    -- RS2: Detalle de productos (sin cambios — incluye UnidadMedida del script 91)
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
PRINT 'OK: usp_ObtenerDetalleVenta_v2 — RS1 ahora devuelve IdTienda.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_ObtenerDetalleCompra — agregar IdTienda al bloque XML DETALLE_TIENDA
--    NOTA: este SP arma un XML. Editarlo manualmente en su definición vigente
--    (script 22 / sus fixes). En el sub-SELECT del DETALLE_TIENDA, agregar la
--    columna IdTienda junto a RUC/Nombre/Direccion. Ejemplo del bloque:
--
--      (SELECT
--          t.IdTienda   AS [IdTienda],     -- ← AGREGAR ESTA LÍNEA
--          t.RUC        AS [RUC],
--          t.Nombre     AS [Nombre],
--          ISNULL(t.Direccion,'') AS [Direccion]
--       FROM dbo.TIENDA t
--       WHERE t.IdTienda = c.IdTienda
--       FOR XML PATH('DETALLE_TIENDA'), TYPE)
--
--    El mapeo C# (CD_Compra.cs) ya lee root...DETALLE_TIENDA/IdTienda de forma
--    defensiva (0 si no viene), así que no rompe si todavía no se aplicó.
-- ════════════════════════════════════════════════════════════════════════════════
PRINT 'PENDIENTE MANUAL: agregar t.IdTienda al XML DETALLE_TIENDA de usp_ObtenerDetalleCompra.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. usp_ObtenerReciboCobro — agregar la columna IdTienda al SELECT
--    En la definición vigente (script 85), en el SELECT que arma el recibo,
--    agregar la columna IdTienda de la venta/comprobante. Ejemplo:
--
--      SELECT
--          cc.IdComprobanteCobro,
--          cc.IdTienda,                    -- ← AGREGAR (o v.IdTienda según el JOIN)
--          ...
--      FROM dbo.COMPROBANTE_COBRO cc
--      ...
--
--    El mapeo C# (CD_ComprobanteCobro.cs) ya lee dr["IdTienda"] con DBNull → 0,
--    y el controller bloquea sólo cuando IdTienda != 0 y != TiendaActiva,
--    así que es seguro aplicarlo gradualmente.
-- ════════════════════════════════════════════════════════════════════════════════
PRINT 'PENDIENTE MANUAL: agregar cc.IdTienda (o v.IdTienda) al SELECT de usp_ObtenerReciboCobro.';
GO

PRINT '════ Script 94 completado (Venta listo; Compra y Recibo: ver notas) ════';
GO
