-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 116: Controles de facturación de pre-venta + caja por usuario
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03
--
-- Agrega 3 controles (validados en BD = no se pueden saltar desde el front):
--   A) usp_FacturarDesdeOrdenVenta:
--        - Requiere caja abierta (IdCaja válido y Estado='Abierta').
--        - Segregación: quien factura ≠ quien registró la pre-venta,
--          salvo Administrador (IdRol 1) o SuperAdmin (IdRol 14).
--   B) usp_ObtenerCajaActiva: nuevo parámetro @IdUsuario opcional para que cada
--        cajero vea SOLO la caja que él abrió (si se pasa > 0).
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- A. usp_FacturarDesdeOrdenVenta — caja obligatoria + segregación
--    (firma alineada con la capa C#, + @IdRolUsuario para la segregación)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT          = NULL,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdCaja          INT          = NULL,
    @Condicion       VARCHAR(20)  = 'Contado',
    @PlazoCredito    INT          = NULL,
    @IdRolUsuario    INT          = 0,        -- rol del que factura (para segregación)
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
        -- Quien registró la pre-venta no puede facturarla, salvo Admin(1)/SuperAdmin(14).
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

        -- Número de factura por CAJA (formato DNIT EEE-PPP-NNNNNNN)
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

        IF @ImporteRecibido < @TotalCosto
        BEGIN
            SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END
        SET @ImporteCambio = @ImporteRecibido - @TotalCosto;

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
        SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta — caja obligatoria + segregación de funciones.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- B. usp_ObtenerCajaActiva — cada cajero ve SOLO la caja que él abrió
--    @IdUsuario = 0  → comportamiento anterior (cualquier caja de la tienda)
--    @IdUsuario > 0  → solo la caja abierta por ese usuario
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda INT,
    @IdUsuario INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.IdCaja, c.IdTienda, t.Nombre AS NombreTienda, c.IdUsuario,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        c.FechaApertura, c.MontoApertura, c.Estado,
        ISNULL(SUM(v.TotalCosto), 0)   AS TotalVentas,
        COUNT(v.IdVenta)               AS CantidadVentas
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    LEFT  JOIN dbo.VENTA   v ON v.IdCaja = c.IdCaja AND v.Estado = 'Activa'
    WHERE (@IdTienda  = 0 OR c.IdTienda  = @IdTienda)
      AND (@IdUsuario = 0 OR c.IdUsuario = @IdUsuario)   -- ← cada cajero ve su caja
      AND c.Estado = 'Abierta'
    GROUP BY c.IdCaja, c.IdTienda, t.Nombre, c.IdUsuario,
             u.Nombres, u.Apellidos, c.FechaApertura, c.MontoApertura, c.Estado;
END
GO
PRINT 'OK: usp_ObtenerCajaActiva — filtra por usuario cuando @IdUsuario > 0.';
GO

PRINT '════ Script 116 completado ════';
GO
