-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 125: Fix usp_FacturarDesdeOrdenVenta — Crédito no valida importe
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- PROBLEMA:
--   Cuando @Condicion = 'Crédito', @ImporteRecibido llega en 0 porque el
--   cliente no paga en el momento. El SP rechazaba con "Importe recibido
--   insuficiente." sin distinguir condición de pago.
--
-- FIX:
--   - Si @Condicion = 'Crédito': forzar @ImporteRecibido = 0, @ImporteCambio = 0
--     y omitir la validación de importe insuficiente.
--   - Si @Condicion = 'Contado': mantener validación existente.
--   - Para Crédito NO se genera COMPROBANTE_COBRO (eso ocurre cuando el
--     cliente venga a pagar desde Cuentas por Cobrar).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
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
        FROM   dbo.ORDEN_VENTA
        WHERE  IdOrdenVenta = @IdOrdenVenta;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='Orden de venta no encontrada.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        -- ── CONTROL 1: caja abierta obligatoria ───────────────────────────────
        IF @IdCaja IS NULL OR @IdCaja = 0
           OR NOT EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdCaja = @IdCaja AND Estado = 'Abierta')
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Debe tener una caja ABIERTA para facturar. Abra una caja e intente de nuevo.';
            SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        -- ── CONTROL 2: segregación de funciones ───────────────────────────────
        IF @IdUsuarioReg = @IdUsuarioCajero
           AND @IdRolUsuario NOT IN (1, 14)
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='El usuario que cargó la pre-venta no puede facturarla (segregación de funciones). Debe facturar otro cajero o un administrador.';
            SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        DECLARE @IdClienteFinal INT = ISNULL(NULLIF(@IdCliente,0), @IdClienteOV);

        IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdOrdenVenta = @IdOrdenVenta AND Estado = 'Activa')
        BEGIN
            SET @Resultado=0; SET @Mensaje='Esta orden ya fue facturada.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT, @IdCaja;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='El timbrado fiscal está vencido o no hay timbrado vigente.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END
        SET @Codigo      = 'V-' + @NumeroFactura;
        SET @ValorCodigo = ISNULL((SELECT MAX(ValorCodigo) FROM dbo.VENTA), 0) + 1;

        SELECT
            @TotalCosto  = SUM(ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)),
            @IVA10Total  = SUM(CASE WHEN d.IvaPorcentaje = 10
                                    THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0)
                                    ELSE 0 END),
            @IVA5Total   = SUM(CASE WHEN d.IvaPorcentaje = 5
                                    THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0, 0)
                                    ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN d.IvaPorcentaje = 0
                                    THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)
                                    ELSE 0 END)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- ── Validación de importe (solo para Contado) ─────────────────────────
        IF @Condicion = 'Crédito'
        BEGIN
            -- Para crédito no hay cobro inmediato; el cliente paga después.
            SET @ImporteRecibido = 0;
            SET @ImporteCambio   = 0;
        END
        ELSE
        BEGIN
            -- Contado: validar que el importe cubra el total
            IF @ImporteRecibido < @TotalCosto
            BEGIN
                SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
                ROLLBACK; RETURN;
            END
            SET @ImporteCambio = @ImporteRecibido - @TotalCosto;
        END

        IF @Condicion = 'Crédito' AND ISNULL(@PlazoCredito,0) > 0
            SET @FechaVenc = CAST(DATEADD(DAY, @PlazoCredito, GETDATE()) AS DATE);

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
            @IdVentaGenerada,
            d.IdProducto,
            d.Cantidad,
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0), 2),
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0),
            1, GETDATE(), d.IvaPorcentaje,
            CASE WHEN d.IvaPorcentaje = 10
                 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0)
                 WHEN d.IvaPorcentaje = 5
                 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0, 0)
                 ELSE 0 END,
            ISNULL(d.PorcentajeDescuento, 0)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- Descontar stock
        UPDATE pt
           SET pt.Stock = pt.Stock - d.Cantidad
        FROM   dbo.PRODUCTO_TIENDA pt
        INNER  JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE  d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        -- COMPROBANTE_COBRO solo para Contado (Crédito se cobra después desde CXC)
        IF @Condicion = 'Contado'
        BEGIN
            DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO),0)+1;
            DECLARE @NumeroCobro VARCHAR(20) = 'CC-'+RIGHT('00000000'+CAST(@NumCC AS VARCHAR),8);
            INSERT INTO dbo.COMPROBANTE_COBRO
                (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
                 MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES
                (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
                 @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');
        END
        -- Para Crédito: se crea entrada en COBRO_CXC al pagar (usp_RegistrarCobroCXC)

        UPDATE dbo.ORDEN_VENTA SET Estado = 'Facturada' WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado = 1;
        SET @Mensaje   = 'Venta registrada correctamente. Factura N° ' + @NumeroFactura + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
        SET @IdVentaGenerada = 0;
        SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta — Crédito no valida importe (cliente paga después en CXC).';
GO

PRINT '════ Script 125 completado ════';
GO
