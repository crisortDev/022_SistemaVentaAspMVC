-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 90c: Parche completo del Script 89 — columnas + SPs
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- Ejecutar si el script 89 no aplicó correctamente.
-- Este script asegura todas las columnas y re-crea todos los SPs afectados.
-- Es idempotente: se puede ejecutar múltiples veces sin daño.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. CATEGORIA ─────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CATEGORIA') AND name = 'UnidadMedida')
    ALTER TABLE dbo.CATEGORIA ADD UnidadMedida VARCHAR(20) NOT NULL DEFAULT 'Unidad';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CATEGORIA') AND name = 'DescuentoMaxPermitido')
    ALTER TABLE dbo.CATEGORIA ADD DescuentoMaxPermitido DECIMAL(5,2) NOT NULL DEFAULT 0;

PRINT 'OK: CATEGORIA — columnas aseguradas.';
GO

-- ─── 2. PRODUCTO ──────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.PRODUCTO') AND name = 'UnidadMedida')
    ALTER TABLE dbo.PRODUCTO ADD UnidadMedida VARCHAR(20) NOT NULL DEFAULT 'Unidad';

PRINT 'OK: PRODUCTO — columna UnidadMedida asegurada.';
GO

-- ─── 3. DETALLE_ORDEN_VENTA ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_ORDEN_VENTA') AND name = 'PorcentajeDescuento')
    ALTER TABLE dbo.DETALLE_ORDEN_VENTA ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;

PRINT 'OK: DETALLE_ORDEN_VENTA — columna PorcentajeDescuento asegurada.';
GO

-- ─── 4. DETALLE_VENTA ─────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA') AND name = 'PorcentajeDescuento')
    ALTER TABLE dbo.DETALLE_VENTA ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;

PRINT 'OK: DETALLE_VENTA — columna PorcentajeDescuento asegurada.';
GO

-- ─── 5. Datos: categorías de cables → Metro ───────────────────────────────────
UPDATE dbo.CATEGORIA
   SET UnidadMedida = 'Metro'
WHERE  Descripcion LIKE '%CABLE%'
  AND  UnidadMedida = 'Unidad';

-- Sincronizar UnidadMedida hacia PRODUCTO
UPDATE p
   SET p.UnidadMedida = c.UnidadMedida
FROM   dbo.PRODUCTO p
INNER  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
WHERE  c.UnidadMedida <> 'Unidad'
  AND  p.UnidadMedida = 'Unidad';

PRINT 'OK: Datos de UnidadMedida sincronizados.';
GO

-- ─── 6. usp_ObtenerCategorias ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCategorias
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        IdCategoria,
        Descripcion,
        Activo,
        FechaRegistro,
        ISNULL(PorcentajeGanancia,    0)       AS PorcentajeGanancia,
        ISNULL(UnidadMedida,         'Unidad') AS UnidadMedida,
        ISNULL(DescuentoMaxPermitido, 0)        AS DescuentoMaxPermitido,
        FechaModificacion,
        UsuarioModificacion
    FROM dbo.CATEGORIA
    ORDER BY Descripcion;
END
GO
PRINT 'OK: usp_ObtenerCategorias actualizado.';
GO

-- ─── 7. usp_RegistrarCategoria ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCategoria
    @Descripcion            VARCHAR(50),
    @PorcentajeGanancia     DECIMAL(5,2)  = 0,
    @UnidadMedida           VARCHAR(20)   = 'Unidad',
    @DescuentoMaxPermitido  DECIMAL(5,2)  = 0,
    @UsuarioModificacion    VARCHAR(100)  = NULL,
    @Resultado              BIT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CATEGORIA WHERE Descripcion = @Descripcion)
    BEGIN SET @Resultado = 0; RETURN; END

    INSERT INTO dbo.CATEGORIA
        (Descripcion, PorcentajeGanancia, UnidadMedida, DescuentoMaxPermitido,
         Activo, FechaRegistro, FechaModificacion, UsuarioModificacion)
    VALUES
        (@Descripcion, @PorcentajeGanancia, @UnidadMedida, @DescuentoMaxPermitido,
         1, GETDATE(), GETDATE(), @UsuarioModificacion);

    SET @Resultado = 1;
END
GO
PRINT 'OK: usp_RegistrarCategoria actualizado.';
GO

-- ─── 8. usp_ModificarCategoria ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ModificarCategoria
    @IdCategoria            INT,
    @Descripcion            VARCHAR(50),
    @Activo                 BIT,
    @PorcentajeGanancia     DECIMAL(5,2)  = 0,
    @UnidadMedida           VARCHAR(20)   = 'Unidad',
    @DescuentoMaxPermitido  DECIMAL(5,2)  = 0,
    @UsuarioModificacion    VARCHAR(100)  = NULL,
    @Resultado              BIT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM dbo.CATEGORIA
        WHERE  Descripcion = @Descripcion AND IdCategoria <> @IdCategoria
    )
    BEGIN SET @Resultado = 0; RETURN; END

    UPDATE dbo.CATEGORIA
       SET Descripcion           = @Descripcion,
           Activo                = @Activo,
           PorcentajeGanancia    = @PorcentajeGanancia,
           UnidadMedida          = @UnidadMedida,
           DescuentoMaxPermitido = @DescuentoMaxPermitido,
           FechaModificacion     = GETDATE(),
           UsuarioModificacion   = @UsuarioModificacion
     WHERE IdCategoria = @IdCategoria;

    -- Sincronizar UnidadMedida en PRODUCTO para esta categoría
    UPDATE dbo.PRODUCTO
       SET UnidadMedida = @UnidadMedida
     WHERE IdCategoria = @IdCategoria;

    SET @Resultado = 1;
END
GO
PRINT 'OK: usp_ModificarCategoria actualizado.';
GO

-- ─── 9. usp_ObtenerProductoTienda ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductoTienda]
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pt.IdProductoTienda,
        pt.IdProducto,
        p.Codigo,
        p.ValorCodigo,
        p.Nombre,
        p.Descripcion,
        p.IdCategoria,
        p.IvaPorcentaje,
        p.StockMaximo,
        p.Activo,
        ISNULL(p.UnidadMedida, 'Unidad')          AS UnidadMedida,
        pt.PrecioUnidadCompra,
        ISNULL(pt.CostoPromedio, 0)               AS CostoPromedio,
        pt.PrecioVenta,
        pt.PrecioCompraIvaIncluido,
        pt.PrecioVentaIvaIncluido,
        ISNULL(pt.Stock, 0)                       AS Stock,
        pt.StockMinimo,
        p.IdCategoria                             AS IdCategoriaProducto,
        ISNULL(c.PorcentajeGanancia, 0)           AS PorcentajeGanancia,
        ISNULL(c.DescuentoMaxPermitido, 0)        AS DescuentoMaxPermitido,
        t.Porcentaje,
        pt.Iniciado,
        ISNULL(pt.PrecioSugerido, 0)              AS PrecioSugerido
    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = pt.IdProducto
    INNER JOIN dbo.TIENDA          ti ON ti.IdTienda   = pt.IdTienda
    LEFT  JOIN dbo.IVA             t  ON t.IdIva       = p.IdIva
    LEFT  JOIN dbo.CATEGORIA       c  ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdTienda = @IdTienda;
END
GO
PRINT 'OK: usp_ObtenerProductoTienda actualizado.';
GO

-- ─── 10. usp_ObtenerDetalleVenta_v2 (con PorcentajeDescuento) ────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera
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
PRINT 'OK: usp_ObtenerDetalleVenta_v2 actualizado (con PorcentajeDescuento).';
GO

-- ─── Verificación final ────────────────────────────────────────────────────────
SELECT
    OBJECT_NAME(object_id) AS Tabla,
    name                   AS Columna,
    TYPE_NAME(system_type_id) + '(' +
        CASE WHEN max_length = -1 THEN 'MAX'
             WHEN system_type_id IN (106,108) THEN CAST(precision AS VARCHAR)+','+CAST(scale AS VARCHAR)
             ELSE CAST(max_length AS VARCHAR) END + ')' AS Tipo
FROM sys.columns
WHERE name IN ('UnidadMedida','DescuentoMaxPermitido','PorcentajeDescuento')
  AND OBJECT_NAME(object_id) IN ('CATEGORIA','PRODUCTO','DETALLE_ORDEN_VENTA','DETALLE_VENTA')
ORDER BY Tabla, Columna;

PRINT '════ Script 90c completado ════';
GO
