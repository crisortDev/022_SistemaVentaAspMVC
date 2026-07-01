-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 80: Implementar Factura a Crédito — Condición + Plazo
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- Agrega a la tabla VENTA:
--   Condicion              VARCHAR(10)  DEFAULT 'Contado'  (Contado | Crédito)
--   PlazoCredito           INT          NULL               (días: 30 | 60)
--   FechaVencimientoCredito DATE         NULL               (FechaRegistro + PlazoCredito)
--
-- Actualiza:
--   usp_FacturarDesdeOrdenVenta: acepta @Condicion y @PlazoCredito;
--     si Crédito omite la validación de importeRecibido.
--   usp_ObtenerDetalleVenta_v2: devuelve Condicion y FechaVencimientoCredito.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Columnas nuevas en VENTA ─────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'Condicion')
    ALTER TABLE dbo.VENTA ADD Condicion VARCHAR(10) NOT NULL DEFAULT 'Contado';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'PlazoCredito')
    ALTER TABLE dbo.VENTA ADD PlazoCredito INT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'FechaVencimientoCredito')
    ALTER TABLE dbo.VENTA ADD FechaVencimientoCredito DATE NULL;

PRINT 'OK: Columnas Condicion, PlazoCredito, FechaVencimientoCredito agregadas a VENTA.';
GO

-- ─── 2. usp_FacturarDesdeOrdenVenta ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdCaja          INT           = NULL,
    @Condicion       VARCHAR(10)   = 'Contado',   -- NUEVO: Contado | Crédito
    @PlazoCredito    INT           = NULL,          -- NUEVO: días 30 | 60
    @IdVentaGenerada INT           OUTPUT,
    @NumeroFactura   VARCHAR(20)   OUTPUT,
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Validar condición
        IF @Condicion NOT IN ('Contado', 'Crédito')
            SET @Condicion = 'Contado';

        -- Si Crédito, plazo debe ser 30 o 60
        IF @Condicion = 'Crédito' AND @PlazoCredito NOT IN (30, 60)
            SET @PlazoCredito = 30;

        -- Validar estado OV
        DECLARE @EstadoOV VARCHAR(20), @IdTienda INT;
        SELECT @EstadoOV = Estado, @IdTienda = IdTienda
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @EstadoOV IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Pre-venta no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoOV <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden facturar pre-ventas Pendiente (estado actual: '+@EstadoOV+').'; ROLLBACK; RETURN; END

        -- Validar cliente
        IF @IdCliente = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE IdCliente = @IdCliente)
        BEGIN SET @Resultado=0; SET @Mensaje='Debe seleccionar un cliente válido.'; ROLLBACK; RETURN; END

        -- Obtener totales de la OV
        DECLARE @TotalCosto DECIMAL(18,2), @IVA10Total DECIMAL(18,2),
                @IVA5Total  DECIMAL(18,2), @Exento0Total DECIMAL(18,2);
        SELECT @TotalCosto=TotalEstimado, @IVA10Total=IVA10, @IVA5Total=IVA5, @Exento0Total=Exento0
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        -- Validar importe recibido SOLO si es Contado
        IF @Condicion = 'Contado' AND @ImporteRecibido < @TotalCosto
        BEGIN SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente para venta al Contado.'; ROLLBACK; RETURN; END

        -- Para Crédito, importe recibido = 0 (se paga después)
        IF @Condicion = 'Crédito'
        BEGIN
            SET @ImporteRecibido = 0;
        END

        -- Validación de stock
        DECLARE @ProductoSinStock NVARCHAR(200);
        SELECT TOP 1 @ProductoSinStock = p.Nombre + ' (necesita ' + CAST(d.Cantidad AS VARCHAR) +
               ', disponible ' + CAST(ISNULL(pt.Stock,0) AS VARCHAR) + ')'
        FROM dbo.DETALLE_ORDEN_VENTA d
        INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = d.IdProducto
        LEFT  JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = d.IdProducto
                                         AND pt.IdTienda   = @IdTienda
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1
          AND ISNULL(pt.Stock, 0) < d.Cantidad;

        IF @ProductoSinStock IS NOT NULL
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Stock insuficiente: ' + @ProductoSinStock;
            ROLLBACK; RETURN;
        END

        -- Generar número de factura
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT;
        IF @NumeroFactura IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Timbrado fiscal vencido.'; ROLLBACK; RETURN; END

        DECLARE @Timbrado VARCHAR(20), @VencTimbrado DATE;
        SELECT @Timbrado=CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado=VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        DECLARE @ValorCodigo INT, @Codigo VARCHAR(20), @ImporteCambio DECIMAL(18,2),
                @FechaVenc   DATE;
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo),0)+1 FROM dbo.VENTA;
        SET @Codigo        = RIGHT('000000'+CAST(@ValorCodigo AS VARCHAR),6);
        SET @ImporteCambio = CASE WHEN @Condicion='Contado' THEN @ImporteRecibido - @TotalCosto ELSE 0 END;
        SET @FechaVenc     = CASE WHEN @Condicion='Crédito' AND @PlazoCredito IS NOT NULL
                                  THEN DATEADD(DAY, @PlazoCredito, CAST(GETDATE() AS DATE))
                                  ELSE NULL END;

        -- Insertar VENTA
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

        -- Detalle de venta
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva)
        SELECT
            @IdVentaGenerada, d.IdProducto, d.Cantidad, d.PrecioUnidad,
            d.TotalLineaIva, 1, GETDATE(), d.IvaPorcentaje,
            CASE WHEN d.IvaPorcentaje=10 THEN d.TotalLinea*10.0/110.0
                 WHEN d.IvaPorcentaje=5  THEN d.TotalLinea*5.0/105.0
                 ELSE 0 END
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- Descontar stock
        UPDATE pt
        SET pt.Stock = pt.Stock - d.Cantidad
        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto=pt.IdProducto
        WHERE d.IdOrdenVenta=@IdOrdenVenta AND d.Activo=1 AND pt.IdTienda=@IdTienda;

        -- Comprobante de cobro (solo Contado tiene pago inmediato)
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
        ELSE
        BEGIN
            -- Crédito: comprobante en estado Pendiente
            DECLARE @NumCCCred   INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO),0)+1;
            DECLARE @NumeroCred  VARCHAR(20) = 'CC-'+RIGHT('00000000'+CAST(@NumCCCred AS VARCHAR),8);
            INSERT INTO dbo.COMPROBANTE_COBRO
                (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
                 MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES
                (@NumeroCred, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
                 @TotalCosto, 0, 0, 'Pendiente');
        END

        -- Marcar OV como Facturada
        UPDATE dbo.ORDEN_VENTA
        SET Estado='Facturada', FechaFacturado=GETDATE(),
            IdUsuarioFactura=@IdUsuarioCajero, IdVenta=@IdVentaGenerada, IdCliente=@IdCliente
        WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado=1;
        SET @Mensaje='Factura ' + @Condicion + ' emitida correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado=0;
        SET @Mensaje='Error: ' + ERROR_MESSAGE();
        SET @IdVentaGenerada=0; SET @NumeroFactura='';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta actualizado (Condicion + PlazoCredito).';
GO

-- ─── 3. usp_ObtenerDetalleVenta_v2 — devolver Condicion + FechaVencimientoCredito ──
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

    -- RS2: Detalle de productos
    SELECT
        dv.IdDetalleVenta, dv.IdProducto,
        p.Codigo  AS CodigoProducto,
        p.Nombre  AS NombreProducto,
        dv.Cantidad, dv.PrecioUnidad, dv.IvaPorcentaje, dv.MontoIva,
        dv.Cantidad * dv.PrecioUnidad AS ImporteTotal,
        CASE
            WHEN dv.IvaPorcentaje=10 THEN CAST(dv.Cantidad*dv.PrecioUnidad/1.10 AS DECIMAL(18,2))
            WHEN dv.IvaPorcentaje=5  THEN CAST(dv.Cantidad*dv.PrecioUnidad/1.05 AS DECIMAL(18,2))
            ELSE dv.Cantidad*dv.PrecioUnidad
        END AS ImporteSinIva,
        dv.Cantidad * dv.PrecioUnidad AS ImporteTotalIvaIncluido
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2 actualizado (Condicion + FechaVencimientoCredito).';
GO

PRINT '════ Script 80 completado ════';
GO
