-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 90b: Parche — asegurar columnas PorcentajeDescuento en tablas de detalle
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- Ejecutar si el script 89 no agregó las columnas correctamente, o si el script 90
-- dio "Invalid column name 'PorcentajeDescuento'" al crear usp_ObtenerDetalleVenta_v2.
--
-- Diagnóstico previo (ejecutar primero para ver qué columnas faltan):
--   SELECT OBJECT_NAME(object_id) AS Tabla, name AS Columna
--   FROM sys.columns
--   WHERE name = 'PorcentajeDescuento'
--     AND OBJECT_NAME(object_id) IN ('DETALLE_ORDEN_VENTA','DETALLE_VENTA');
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Asegurar DETALLE_ORDEN_VENTA.PorcentajeDescuento ─────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.DETALLE_ORDEN_VENTA')
      AND name = 'PorcentajeDescuento'
)
BEGIN
    ALTER TABLE dbo.DETALLE_ORDEN_VENTA
        ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;
    PRINT 'OK: DETALLE_ORDEN_VENTA.PorcentajeDescuento agregada.';
END
ELSE
    PRINT 'INFO: DETALLE_ORDEN_VENTA.PorcentajeDescuento ya existía.';
GO

-- ─── 2. Asegurar DETALLE_VENTA.PorcentajeDescuento ───────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA')
      AND name = 'PorcentajeDescuento'
)
BEGIN
    ALTER TABLE dbo.DETALLE_VENTA
        ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;
    PRINT 'OK: DETALLE_VENTA.PorcentajeDescuento agregada.';
END
ELSE
    PRINT 'INFO: DETALLE_VENTA.PorcentajeDescuento ya existía.';
GO

-- ─── 3. Forzar recompilación de usp_ObtenerDetalleVenta_v2 ───────────────────
-- Ahora que la columna existe, volver a crear el SP para que compile sin warnings.
-- (Mismo cuerpo que script 90, solo se re-ejecuta.)
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── RS1: Cabecera ─────────────────────────────────────────────────────────
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

    -- ── RS2: Detalle de productos ─────────────────────────────────────────────
    SELECT
        dv.IdDetalleVenta,
        dv.IdProducto,
        p.Codigo  AS CodigoProducto,
        p.Nombre  AS NombreProducto,
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
PRINT 'OK: usp_ObtenerDetalleVenta_v2 recompilado sin warnings.';
GO

-- ─── 4. Verificación ─────────────────────────────────────────────────────────
SELECT
    OBJECT_NAME(object_id) AS Tabla,
    name                   AS Columna,
    TYPE_NAME(system_type_id) AS Tipo,
    is_nullable
FROM sys.columns
WHERE name = 'PorcentajeDescuento'
  AND OBJECT_NAME(object_id) IN ('DETALLE_ORDEN_VENTA', 'DETALLE_VENTA')
ORDER BY Tabla;

PRINT '════ Script 90b completado ════';
GO
