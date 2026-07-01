-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 110: Ventas numeran por CAJA (punto de expedición) — ETAPA 2 final
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31  ·  Depende de scripts 108 y 109.
--
-- Conecta los SP de venta con la numeración por caja:
--   • usp_RegistrarVentaDirecta   → pasa @IdCaja al generador (cambio de 1 línea).
--   • usp_FacturarDesdeOrdenVenta → reemplaza el "MAX+1" por el generador DNIT con @IdCaja.
--
-- Ambos SP son COPIA EXACTA de su versión vigente (scripts 73 y 89), con el ÚNICO
-- cambio en la generación del número de factura. El resto queda idéntico.
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_RegistrarVentaDirecta  (= script 73 + @IdCaja en el generador)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarVentaDirecta]
    @IdTienda        INT,
    @IdUsuario       INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @DetalleXml      XML,
    @IdCaja          INT           = NULL,
    @IdVentaGenerada INT           OUTPUT,
    @NumeroFactura   VARCHAR(20)   OUTPUT,
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF @IdCliente = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE IdCliente = @IdCliente)
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Cliente inválido.'; ROLLBACK; RETURN;
        END

        DECLARE @TotalCosto   DECIMAL(18,2),
                @IVA10Total   DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2),
                @Exento0Total DECIMAL(18,2);

        SELECT
            @TotalCosto   = SUM(n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')),
            @IVA10Total   = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0/110.0
                                ELSE 0 END),
            @IVA5Total    = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0/105.0
                                ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                                ELSE 0 END)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        IF @ImporteRecibido < @TotalCosto
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El importe recibido es menor al total (' + CAST(@TotalCosto AS VARCHAR) + ').';
            ROLLBACK; RETURN;
        END

        -- ★ Número de factura por CAJA (punto de expedición propio)
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT, @IdCaja;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El timbrado fiscal está vencido. Contacte al administrador.';
            ROLLBACK; RETURN;
        END

        DECLARE @Timbrado      VARCHAR(20),
                @VencTimbrado  DATE,
                @ValorCodigo   INT,
                @Codigo        VARCHAR(20),
                @ImporteCambio DECIMAL(18,2);

        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR),
               @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        SET @ImporteCambio = @ImporteRecibido - @TotalCosto;

        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1 FROM dbo.VENTA;
        SET @Codigo = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);

        IF EXISTS (
            SELECT 1 FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
            JOIN dbo.PRODUCTO_TIENDA pt
                ON pt.IdProducto = n.value('(IdProducto)[1]','INT')
               AND pt.IdTienda   = @IdTienda
            WHERE pt.Stock < n.value('(Cantidad)[1]','DECIMAL(18,3)')
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Stock insuficiente para uno o más productos.';
            ROLLBACK; RETURN;
        END

        INSERT INTO dbo.VENTA
            (ValorCodigo, Codigo, NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             IdTienda, IdUsuario, IdCliente, IdFormaCobro, TipoFlujo, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, Estado, FechaRegistro,
             IVA10, IVA5, Exento0, IdCaja)
        VALUES
            (@ValorCodigo, @Codigo, @NumeroFactura, @Timbrado, @VencTimbrado,
             @IdTienda, @IdUsuario, @IdCliente, @IdFormaCobro, 'Directa', 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, 'Activa', GETDATE(),
             @IVA10Total, @IVA5Total, @Exento0Total, @IdCaja);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva)
        SELECT
            @IdVentaGenerada,
            n.value('(IdProducto)[1]',   'INT'),
            n.value('(Cantidad)[1]',     'DECIMAL(18,3)'),
            n.value('(PrecioUnidad)[1]', 'DECIMAL(18,2)'),
            n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)'),
            1, GETDATE(),
            n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)'),
            CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                 THEN n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0/110.0
                 WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                 THEN n.value('(Cantidad)[1]','DECIMAL(18,3)') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0/105.0
                 ELSE 0 END
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        UPDATE pt
        SET pt.Stock = pt.Stock - d.Cantidad
        FROM dbo.PRODUCTO_TIENDA pt
        JOIN (
            SELECT n.value('(IdProducto)[1]','INT') AS IdProducto,
                   n.value('(Cantidad)[1]',   'DECIMAL(18,3)') AS Cantidad
            FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
        ) d ON d.IdProducto = pt.IdProducto AND pt.IdTienda = @IdTienda;

        DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO), 0) + 1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-' + RIGHT('00000000' + CAST(@NumCC AS VARCHAR), 8);

        INSERT INTO dbo.COMPROBANTE_COBRO
            (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
             MontoTotal, MontoRecibido, MontoCambio, Estado)
        VALUES
            (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuario, @IdFormaCobro,
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Venta registrada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarVentaDirecta — numera por caja.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_FacturarDesdeOrdenVenta  (= script 89 + generador DNIT con @IdCaja)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta       INT,
    @IdUsuarioCajero    INT,
    @ImporteRecibido    DECIMAL(18,2),
    @ImporteCambio      DECIMAL(18,2),
    @IdFormaCobro       INT,
    @Condicion          VARCHAR(20)  = 'Contado',
    @PlazoCredito       INT          = 0,
    @IdCaja             INT          = NULL,
    @Resultado          BIT          OUTPUT,
    @Mensaje            NVARCHAR(500) OUTPUT,
    @IdVentaGenerada    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda        INT,
                @IdCliente       INT,
                @NumeroFactura   VARCHAR(20),
                @Timbrado        VARCHAR(20),
                @VencTimbrado    DATE,
                @Codigo          VARCHAR(20),
                @ValorCodigo     INT,
                @TotalCosto      DECIMAL(18,2),
                @IVA10Total      DECIMAL(18,2),
                @IVA5Total       DECIMAL(18,2),
                @Exento0Total    DECIMAL(18,2),
                @FechaVenc       DATE;

        SELECT @IdTienda  = IdTienda,
               @IdCliente = IdCliente
        FROM   dbo.ORDEN_VENTA
        WHERE  IdOrdenVenta = @IdOrdenVenta;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Orden de venta no encontrada.'; ROLLBACK; RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdOrdenVenta = @IdOrdenVenta AND Estado = 'Activa')
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Esta orden ya fue facturada.'; ROLLBACK; RETURN;
        END

        -- Timbrado (se conserva la validación por DATOS_TRIBUTARIOS via generador)
        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        -- ★ Número de factura por CAJA (formato DNIT EEE-PPP-NNNNNNN)
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT, @IdCaja;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'El timbrado fiscal está vencido o no hay timbrado vigente.'; ROLLBACK; RETURN;
        END
        SET @Codigo      = 'V-' + @NumeroFactura;
        SET @ValorCodigo = ISNULL((SELECT MAX(ValorCodigo) FROM dbo.VENTA), 0) + 1;

        -- Totales con descuento
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

        IF @Condicion = 'Crédito' AND @PlazoCredito > 0
            SET @FechaVenc = CAST(DATEADD(DAY, @PlazoCredito, GETDATE()) AS DATE);

        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
             IVA10, IVA5, Exento0, IdCaja,
             Condicion, PlazoCredito, FechaVencimientoCredito)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdCliente, 'Factura',
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

        UPDATE pt
           SET pt.Stock = pt.Stock - d.Cantidad
        FROM   dbo.PRODUCTO_TIENDA pt
        INNER  JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE  d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

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
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta — numera por caja con formato DNIT.';
GO

PRINT '════ Script 110 completado — ventas numeran por caja ════';
GO
