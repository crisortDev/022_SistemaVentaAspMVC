-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 95: Completar IdTienda en usp_ObtenerDetalleCompra y usp_ObtenerReciboCobro
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-30
--
-- Completa los 2 PENDIENTE MANUAL del script 94 (aislamiento por sucursal / IDOR).
-- Estos SP son COPIA EXACTA de su versión vigente (script 22 y script 85),
-- con UN solo cambio cada uno: se agrega la columna IdTienda.
-- No se tocó ningún otro campo ni la estructura del XML/SELECT → no rompe el mapeo C#.
--
-- Idempotente (CREATE OR ALTER). No borra datos.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_ObtenerDetalleCompra  (= script 22 + t.IdTienda en DETALLE_TIENDA)
-- ════════════════════════════════════════════════════════════════════════════════
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

        -- ── Tienda destino (ahora con IdTienda para aislamiento por sucursal) ──
        (SELECT
            t.IdTienda                                         AS [IdTienda],     -- ← ÚNICO CAMBIO
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
PRINT 'OK: usp_ObtenerDetalleCompra — DETALLE_TIENDA ahora incluye IdTienda.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_ObtenerReciboCobro  (= script 85 + cc.IdTienda)
--    Se conserva intacta la lógica contado/crédito (COBRO_CXC).
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerReciboCobro
    @IdCompCobro INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        -- Identificación
        cc.IdComprobanteCobro,
        cc.NumeroCobro,
        cc.IdTienda,                                            -- ← ÚNICO CAMBIO
        v.NumeroFactura,
        ISNULL(v.Condicion, 'Contado')                          AS Condicion,

        -- Cliente
        c.Nombre                                                AS NombreCliente,
        c.NumeroDocumento,
        ISNULL(c.Telefono, '')                                  AS TelefonoCliente,
        ISNULL(c.Direccion,'')                                  AS DireccionCliente,

        -- Montos
        cc.MontoTotal,
        ISNULL(cx.MontoRecibido, cc.MontoRecibido)              AS MontoRecibido,
        ISNULL(cx.MontoCambio,   cc.MontoCambio)                AS MontoCambio,

        -- Forma de cobro: la del cobro CXC si existe, sino la original de la venta
        ISNULL(fcCX.Nombre, fcCC.Nombre)                        AS FormaCobro,

        -- Fechas
        FORMAT(cc.FechaRegistro,  'dd/MM/yyyy HH:mm')           AS FechaEmision,
        FORMAT(ISNULL(cx.FechaCobro, cc.FechaRegistro), 'dd/MM/yyyy HH:mm') AS FechaCobro,

        -- Plazo crédito
        v.PlazoCredito,
        CONVERT(VARCHAR(10), v.FechaVencimientoCredito, 103)    AS FechaVencimiento,

        -- Usuario que cobró
        ISNULL(uCX.Nombres + ' ' + uCX.Apellidos,
               uCC.Nombres + ' ' + uCC.Apellidos)               AS NombreCobrador,

        -- Observación del cobro (solo CXC)
        ISNULL(cx.Observacion, '')                              AS Observacion,

        -- Tienda
        t.Nombre                                                AS NombreTienda,
        ISNULL(t.Direccion, '')                                 AS DireccionTienda,
        ISNULL(t.Telefono,  '')                                 AS TelefonoTienda

    FROM dbo.COMPROBANTE_COBRO cc
    INNER JOIN dbo.VENTA          v    ON v.IdVenta       = cc.IdVenta
    INNER JOIN dbo.CLIENTE        c    ON c.IdCliente     = v.IdCliente
    INNER JOIN dbo.TIENDA         t    ON t.IdTienda      = cc.IdTienda
    INNER JOIN dbo.USUARIO        uCC  ON uCC.IdUsuario   = cc.IdUsuario
    LEFT  JOIN dbo.FORMA_COBRO    fcCC ON fcCC.IdFormaCobro = cc.IdFormaCobro
    LEFT  JOIN dbo.COBRO_CXC      cx   ON cx.IdCompCobro  = cc.IdComprobanteCobro
    LEFT  JOIN dbo.FORMA_COBRO    fcCX ON fcCX.IdFormaCobro = cx.IdFormaCobro
    LEFT  JOIN dbo.USUARIO        uCX  ON uCX.IdUsuario   = cx.IdUsuario
    WHERE cc.IdComprobanteCobro = @IdCompCobro;
END
GO
PRINT 'OK: usp_ObtenerReciboCobro — SELECT incluye IdTienda.';
GO

PRINT '════ Script 95 completado — IDOR cerrado en Compra y Recibo de Cobro ════';
GO
