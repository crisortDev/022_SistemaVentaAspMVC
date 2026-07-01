-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 134: Poblar Exento10 / Exento5 en VENTA (desglose fiscal paraguayo)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-11
--
-- PROBLEMA:
--   Los campos VENTA.Exento10 y VENTA.Exento5 nunca fueron calculados ni
--   guardados por ninguna versión del SP. Solo se guardaban IVA10, IVA5, Exento0.
--   Esto deja incompleto el desglose fiscal paraguayo:
--     TotalCosto = Exento10 + IVA10 + Exento5 + IVA5 + Exento0
--     (donde Exento10 = base gravada al 10%, Exento5 = base gravada al 5%)
--
-- CAMBIOS:
--   1. UPDATE retroactivo: pobla Exento10/Exento5 en ventas existentes
--      derivándolos de IVA10/IVA5 ya guardados:
--        Exento10 = IVA10 * 10   (porque IVA10 = TotalLineas10% / 11)
--        Exento5  = IVA5  * 20   (porque IVA5  = TotalLineas5%  / 21)
--   2. usp_FacturarDesdeOrdenVenta: agrega cálculo y guardado de Exento10/Exento5
--      (basado en la versión vigente del script 128)
--
-- ⚠️ BACKUP antes de ejecutar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PARTE 1: UPDATE retroactivo en ventas existentes
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '── PARTE 1: Actualizando Exento10/Exento5 en ventas existentes...';

-- Exento10 = base gravada al 10% = IVA10 * 10  (IVA10 = base/11, base = IVA10*10)
-- Exento5  = base gravada al 5%  = IVA5  * 20  (IVA5  = base/21, base = IVA5 *20)
UPDATE dbo.VENTA
SET
    Exento10 = ROUND(IVA10 * 10.0, 0),
    Exento5  = ROUND(IVA5  * 20.0, 0)
WHERE
    Estado <> 'Anulada'
    AND (Exento10 = 0 OR Exento10 IS NULL OR Exento5 = 0 OR Exento5 IS NULL)
    AND (IVA10 > 0 OR IVA5 > 0);

PRINT 'OK: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' ventas actualizadas.';
GO

-- Verificar que la suma ahora cuadra (tolerancia 2 Gs por redondeo a múltiplos de 50)
PRINT '── Verificación post-UPDATE (deben ser 0 filas o diferencia <= 2):';
SELECT v.IdVenta, v.FechaRegistro, v.TotalCosto,
       v.Exento10, v.IVA10, v.Exento5, v.IVA5, v.Exento0,
       (v.Exento10 + v.IVA10 + v.Exento5 + v.IVA5 + v.Exento0) AS SumaPartes,
       v.TotalCosto - (v.Exento10 + v.IVA10 + v.Exento5 + v.IVA5 + v.Exento0) AS Diferencia
FROM dbo.VENTA v
WHERE v.Estado <> 'Anulada'
  AND ABS(v.TotalCosto - (v.Exento10 + v.IVA10 + v.Exento5 + v.IVA5 + v.Exento0)) > 2
ORDER BY ABS(v.TotalCosto - (v.Exento10 + v.IVA10 + v.Exento5 + v.IVA5 + v.Exento0)) DESC;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PARTE 2: usp_FacturarDesdeOrdenVenta — agrega Exento10 / Exento5
-- (copia exacta del script 128 + las dos variables nuevas)
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '── PARTE 2: Actualizando usp_FacturarDesdeOrdenVenta...';
GO

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

        DECLARE @IdTienda       INT,
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
                @Exento10Total  DECIMAL(18,2),   -- ← NUEVO: base gravada 10%
                @Exento5Total   DECIMAL(18,2),   -- ← NUEVO: base gravada 5%
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

        -- ── Calcular totales (con descuento) y redondear a múltiplos de 50 Gs ──
        DECLARE @TotalSinRedondear DECIMAL(18,2);

        SELECT
            @TotalSinRedondear = SUM(ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)),
            @IVA10Total   = SUM(CASE WHEN d.IvaPorcentaje = 10
                                THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0)
                                ELSE 0 END),
            @IVA5Total    = SUM(CASE WHEN d.IvaPorcentaje = 5
                                THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0, 0)
                                ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN d.IvaPorcentaje = 0
                                THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)
                                ELSE 0 END),
            -- ← NUEVO: base gravada (precio sin IVA)
            @Exento10Total= SUM(CASE WHEN d.IvaPorcentaje = 10
                                THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 100.0/110.0, 0)
                                ELSE 0 END),
            @Exento5Total = SUM(CASE WHEN d.IvaPorcentaje = 5
                                THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 100.0/105.0, 0)
                                ELSE 0 END)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- Redondear total al múltiplo de 50 superior
        SET @TotalCosto = CAST(CEILING(@TotalSinRedondear / 50.0) * 50 AS DECIMAL(18,2));

        -- ── Importe y cambio según condición ──────────────────────────────────
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
             IVA10, IVA5, Exento0, Exento10, Exento5,   -- ← Exento10/Exento5 añadidos
             IdCaja, Condicion, PlazoCredito, FechaVencimientoCredito)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdClienteFinal, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'PreVenta', @IdOrdenVenta, @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total, @Exento10Total, @Exento5Total,
             @IdCaja, @Condicion, @PlazoCredito, @FechaVenc);

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
PRINT 'OK: usp_FacturarDesdeOrdenVenta — Exento10/Exento5 incluidos.';
GO

PRINT '════ Script 134 completado ════';
GO
