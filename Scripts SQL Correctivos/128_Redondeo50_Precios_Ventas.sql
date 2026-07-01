-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 128: Redondeo a múltiplos de 50 Gs — Precios y Totales de Venta
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- La moneda mínima en Paraguay es 50 Gs. Sin este ajuste, los vueltos
-- de 25 Gs son imposibles (no existen billetes/monedas de esa denominación).
--
-- Fórmula: CEILING(monto / 50.0) * 50
--   471.075  →  471.100  ✓
--   471.050  →  471.050  ✓
--   471.001  →  471.050  ✓
--
-- Cambios:
--   1. usp_ObtenerProductoTienda → PrecioVenta y PrecioSugerido redondeados a 50
--   2. usp_FacturarDesdeOrdenVenta → TotalCosto redondeado a 50
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── Helper: función inline de redondeo a 50 ─────────────────────────────────
-- Equivalente a: CEILING(x / 50.0) * 50
-- Se usa como macro en los SPs abajo.

-- ─── 1. usp_ObtenerProductoTienda — PrecioVenta y PrecioSugerido a múltiplo 50 ─
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductoTienda]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pt.IdProductoTienda,
        p.IdProducto,
        p.Codigo                                        AS CodigoProducto,
        p.Nombre                                        AS NombreProducto,
        p.Descripcion                                   AS DescripcionProducto,
        t.IdTienda,
        t.RUC,
        t.Nombre                                        AS NombreTienda,
        t.Direccion                                     AS DireccionTienda,

        -- Costos
        pt.PrecioUnidadCompra,
        ISNULL(pt.CostoPromedio, 0)                     AS CostoPromedio,

        -- Precio compra con IVA (redondeado a 50)
        CAST(CEILING(
            pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje / 100.0)
        / 50.0) * 50 AS INT)                            AS PrecioCompraIvaIncluido,

        -- Precio sugerido (CPP × margen × IVA, redondeado a 50)
        CAST(CEILING(
            CASE
                WHEN ISNULL(pt.CostoPromedio, 0) > 0
                     AND ISNULL(c.PorcentajeGanancia, 0) > 0
                THEN pt.CostoPromedio
                     * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
                     * (1.0 + p.IvaPorcentaje / 100.0)
                ELSE
                    pt.PrecioUnidadCompra
                    * (1.0 + p.IvaPorcentaje / 100.0)
                    * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            END
        / 50.0) * 50 AS INT)                            AS PrecioSugerido,

        ISNULL(c.PorcentajeGanancia, 0)                 AS PorcentajeGanancia,
        ISNULL(c.DescuentoMaxPermitido, 0)              AS DescuentoMaxPermitido,
        ISNULL(p.UnidadMedida, 'Unidad')                AS UnidadMedida,

        -- Precio de venta efectivo (manual > calculado, redondeado a 50)
        CAST(CEILING(
            ISNULL(
                (
                    SELECT TOP 1 pv.PrecioVenta
                    FROM   dbo.PRECIO_VENTA pv
                    WHERE  pv.IdProducto   = p.IdProducto
                      AND  pv.FechaInicio <= GETDATE()
                      AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                    ORDER  BY pv.FechaInicio DESC
                ),
                pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        / 50.0) * 50 AS INT)                            AS PrecioVenta,

        -- PrecioVentaIvaIncluido = igual que PrecioVenta (ya incluye IVA)
        CAST(CEILING(
            ISNULL(
                (
                    SELECT TOP 1 pv.PrecioVenta
                    FROM   dbo.PRECIO_VENTA pv
                    WHERE  pv.IdProducto   = p.IdProducto
                      AND  pv.FechaInicio <= GETDATE()
                      AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                    ORDER  BY pv.FechaInicio DESC
                ),
                pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        / 50.0) * 50 AS INT)                            AS PrecioVentaIvaIncluido,

        pt.Stock,
        p.IvaPorcentaje                                 AS Porcentaje,
        pt.Iniciado

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = pt.IdProducto
    INNER JOIN dbo.TIENDA          t  ON t.IdTienda    = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       c  ON c.IdCategoria = p.IdCategoria

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1

    ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductoTienda — PrecioVenta y PrecioSugerido redondeados a múltiplos de 50 Gs.';
GO

-- ─── 2. usp_FacturarDesdeOrdenVenta — TotalCosto redondeado a 50 ──────────────
-- Reemplaza script 126 con el mismo SP pero aplicando redondeo al TotalCosto.
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT          = NULL,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdCaja          INT          = NULL,
    @Condicion       VARCHAR(20)  = 'Contado',
    @PlazoCredito    INT          = NULL,
    @IdRolUsuario    INT          = 0,
    @IdVentaGenerada INT          OUTPUT,
    @NumeroFactura   VARCHAR(20)  OUTPUT,
    @Resultado       BIT          OUTPUT,
    @Mensaje         NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda      INT,
                @IdClienteOV    INT,
                @IdUsuarioReg   INT,
                @Timbrado       VARCHAR(20),
                @VencTimbrado   DATE,
                @Codigo         VARCHAR(20),
                @ValorCodigo    INT,
                @TotalCosto     DECIMAL(18,2),
                @IVA10Total     DECIMAL(18,2),
                @IVA5Total      DECIMAL(18,2),
                @Exento0Total   DECIMAL(18,2),
                @ImporteCambio  DECIMAL(18,2),
                @FechaVenc      DATE;

        SELECT @IdTienda = IdTienda, @IdClienteOV = IdCliente, @IdUsuarioReg = IdUsuarioRegistro
        FROM   dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='Orden de venta no encontrada.'; SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
        END

        IF @IdCaja IS NULL OR @IdCaja = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdCaja = @IdCaja AND Estado = 'Abierta')
        BEGIN
            SET @Resultado=0; SET @Mensaje='Debe tener una caja ABIERTA para facturar.'; SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
        END

        IF @IdUsuarioReg = @IdUsuarioCajero AND @IdRolUsuario NOT IN (1, 14)
        BEGIN
            SET @Resultado=0; SET @Mensaje='El usuario que cargó la pre-venta no puede facturarla (segregación de funciones).'; SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
        END

        DECLARE @IdClienteFinal INT = ISNULL(NULLIF(@IdCliente,0), @IdClienteOV);

        IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdOrdenVenta = @IdOrdenVenta AND Estado = 'Activa')
        BEGIN
            SET @Resultado=0; SET @Mensaje='Esta orden ya fue facturada.'; SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
        END

        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT, @IdCaja;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='El timbrado fiscal está vencido o no hay timbrado vigente.'; SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
        END
        SET @Codigo      = 'V-' + @NumeroFactura;
        SET @ValorCodigo = ISNULL((SELECT MAX(ValorCodigo) FROM dbo.VENTA), 0) + 1;

        -- ── Calcular totales y redondear a múltiplos de 50 Gs ────────────────
        DECLARE @TotalSinRedondear DECIMAL(18,2);

        SELECT
            @TotalSinRedondear = SUM(ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)),
            @IVA10Total  = SUM(CASE WHEN d.IvaPorcentaje = 10 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0) ELSE 0 END),
            @IVA5Total   = SUM(CASE WHEN d.IvaPorcentaje = 5  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0,  0) ELSE 0 END),
            @Exento0Total= SUM(CASE WHEN d.IvaPorcentaje = 0  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0) ELSE 0 END)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- Redondear total al múltiplo de 50 superior
        SET @TotalCosto = CAST(CEILING(@TotalSinRedondear / 50.0) * 50 AS DECIMAL(18,2));

        -- ── Importe y cambio según condición ─────────────────────────────────
        IF @Condicion = 'Crédito'
        BEGIN
            SET @ImporteRecibido = 0;
            SET @ImporteCambio   = 0;
            IF ISNULL(@PlazoCredito, 0) > 0
                SET @FechaVenc = CAST(DATEADD(DAY, @PlazoCredito, GETDATE()) AS DATE);
        END
        ELSE
        BEGIN
            IF @ImporteRecibido < @TotalCosto
            BEGIN
                SET @Resultado=0;
                SET @Mensaje='Importe recibido (Gs. ' + FORMAT(@ImporteRecibido,'N0') + ') insuficiente. Total: Gs. ' + FORMAT(@TotalCosto,'N0') + '.';
                SET @IdVentaGenerada=0; SET @NumeroFactura=''; ROLLBACK; RETURN;
            END
            SET @ImporteCambio = @ImporteRecibido - @TotalCosto;
        END

        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
             IVA10, IVA5, Exento0, IdCaja,
             Condicion, PlazoCredito, FechaVencimientoCredito)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdClienteFinal, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'PreVenta', @IdOrdenVenta, @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total, @IdCaja,
             @Condicion, @PlazoCredito, @FechaVenc);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva, PorcentajeDescuento)
        SELECT
            @IdVentaGenerada, d.IdProducto, d.Cantidad,
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0), 2),
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0),
            1, GETDATE(), d.IvaPorcentaje,
            CASE WHEN d.IvaPorcentaje = 10 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0)
                 WHEN d.IvaPorcentaje = 5  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0,  0)
                 ELSE 0 END,
            ISNULL(d.PorcentajeDescuento, 0)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        UPDATE pt SET pt.Stock = pt.Stock - d.Cantidad
        FROM   dbo.PRODUCTO_TIENDA pt
        INNER  JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE  d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO),0)+1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-'+RIGHT('00000000'+CAST(@NumCC AS VARCHAR),8);

        IF @Condicion = 'Contado'
            INSERT INTO dbo.COMPROBANTE_COBRO (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro, MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro, @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');
        ELSE
            INSERT INTO dbo.COMPROBANTE_COBRO (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro, MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro, @TotalCosto, 0, 0, 'Pendiente');

        UPDATE dbo.ORDEN_VENTA SET Estado = 'Facturada' WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado = 1;
        SET @Mensaje   = 'Venta registrada correctamente. Factura N° ' + @NumeroFactura + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE(); SET @IdVentaGenerada=0; SET @NumeroFactura='';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta — TotalCosto redondeado a múltiplos de 50 Gs.';
GO

-- ─── Verificación ─────────────────────────────────────────────────────────────
-- Muestra cómo quedarían precios de ejemplo con redondeo a 50
SELECT
    'Ejemplo' AS Tipo,
    471075    AS Monto_Original,
    CAST(CEILING(471075 / 50.0) * 50 AS INT) AS Monto_Redondeado_50
UNION ALL SELECT '', 471001, CAST(CEILING(471001 / 50.0) * 50 AS INT)
UNION ALL SELECT '', 471050, CAST(CEILING(471050 / 50.0) * 50 AS INT)
UNION ALL SELECT '', 471100, CAST(CEILING(471100 / 50.0) * 50 AS INT);

PRINT '════ Script 128 completado ════';
GO
