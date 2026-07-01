-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 48: Dos correcciones
--   A) usp_ObtenerDetalleVenta_v2 — agregar IdProducto e ImporteTotalIvaIncluido
--      al RS2 (el C# los lee y fallaba con IndexOutOfRangeException → null →
--      "No se encontró la venta solicitada.")
--   B) usp_FacturarDesdeOrdenVenta — agregar validación de stock insuficiente
--      antes de insertar la venta
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- A) usp_ObtenerDetalleVenta_v2
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: Cabecera de la venta (KuDE)
    SELECT
        v.IdVenta, v.Codigo, v.NumeroFactura, v.NumeroTimbrado,
        CONVERT(VARCHAR(10), v.VencimientoTimbrado, 103)  AS VencimientoTimbrado,
        CONVERT(VARCHAR(10), v.FechaRegistro, 103)        AS FechaRegistro,
        v.TipoDocumento, v.TipoFlujo, v.Estado,
        v.TotalCosto, v.ImporteRecibido, v.ImporteCambio,
        v.IVA10, v.IVA5, v.Exento0,
        v.TotalCosto - v.IVA10 - v.IVA5 - v.Exento0      AS Gravado10,
        v.IVA5                                             AS Gravado5Base,
        -- Emisor
        t.Nombre    AS NombreEmisor,
        t.RUC       AS RUCEmisor,
        t.Direccion AS DireccionEmisor,
        t.Telefono  AS TelefonoEmisor,
        -- Timbrado
        dt.Establecimiento,
        dt.PuntoExpedicion,
        -- Cajero
        u.Nombres + ' ' + u.Apellidos                     AS NombreCajero,
        -- Cliente
        c.Nombre           AS NombreCliente,
        c.NumeroDocumento  AS DocumentoCliente,
        c.TipoDocumento    AS TipoDocumentoCliente,
        c.Direccion        AS DireccionCliente,
        c.Telefono         AS TelefonoCliente,
        -- Forma de cobro
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        -- OV origen (si aplica)
        ISNULL(ov.NumeroOV, '')                           AS NumeroOV
    FROM dbo.VENTA v
    INNER JOIN dbo.TIENDA             t  ON t.IdTienda    = v.IdTienda
    INNER JOIN dbo.USUARIO            u  ON u.IdUsuario   = v.IdUsuario
    INNER JOIN dbo.CLIENTE            c  ON c.IdCliente   = v.IdCliente
    LEFT  JOIN dbo.FORMA_COBRO        fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT  JOIN dbo.ORDEN_VENTA        ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    CROSS JOIN dbo.DATOS_TRIBUTARIOS  dt
    WHERE v.IdVenta = @IdVenta;

    -- RS2: Detalle de productos
    SELECT
        dv.IdDetalleVenta,
        dv.IdProducto,                                   -- ← faltaba
        p.Codigo     AS CodigoProducto,
        p.Nombre     AS NombreProducto,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        dv.ImporteTotal,
        -- Base imponible (sin IVA)
        CASE WHEN dv.IvaPorcentaje = 10
             THEN CAST(dv.ImporteTotal / 1.10 AS DECIMAL(18,2))
             WHEN dv.IvaPorcentaje = 5
             THEN CAST(dv.ImporteTotal / 1.05 AS DECIMAL(18,2))
             ELSE dv.ImporteTotal
        END AS ImporteSinIva,
        dv.ImporteTotal AS ImporteTotalIvaIncluido        -- ← faltaba (alias del mismo campo)
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2 corregido.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- B) usp_FacturarDesdeOrdenVenta — agregar validación de stock antes del INSERT
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdVentaGenerada INT           OUTPUT,
    @NumeroFactura   VARCHAR(20)   OUTPUT,
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Validar estado OV
        DECLARE @EstadoOV VARCHAR(20), @IdTienda INT;
        SELECT @EstadoOV = Estado, @IdTienda = IdTienda
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @EstadoOV IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Pre-venta no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoOV <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden facturar pre-ventas en estado Pendiente (estado actual: '+@EstadoOV+').'; ROLLBACK; RETURN; END

        -- Validar cliente
        IF @IdCliente = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE IdCliente = @IdCliente)
        BEGIN SET @Resultado=0; SET @Mensaje='Debe seleccionar un cliente válido.'; ROLLBACK; RETURN; END

        -- Obtener totales de la OV
        DECLARE @TotalCosto DECIMAL(18,2), @IVA10Total DECIMAL(18,2),
                @IVA5Total  DECIMAL(18,2), @Exento0Total DECIMAL(18,2);
        SELECT @TotalCosto=TotalEstimado, @IVA10Total=IVA10, @IVA5Total=IVA5, @Exento0Total=Exento0
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @ImporteRecibido < @TotalCosto
        BEGIN SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente.'; ROLLBACK; RETURN; END

        -- ── VALIDACIÓN DE STOCK ──────────────────────────────────────────────
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
            SET @Resultado = 0;
            SET @Mensaje = 'Stock insuficiente: ' + @ProductoSinStock;
            ROLLBACK; RETURN;
        END
        -- ────────────────────────────────────────────────────────────────────

        -- Generar número de factura
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT;
        IF @NumeroFactura IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Timbrado fiscal vencido.'; ROLLBACK; RETURN; END

        DECLARE @Timbrado VARCHAR(20), @VencTimbrado DATE;
        SELECT @Timbrado=CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado=VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        DECLARE @ValorCodigo INT, @Codigo VARCHAR(20), @ImporteCambio DECIMAL(18,2);
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo),0)+1 FROM dbo.VENTA;
        SET @Codigo = RIGHT('000000'+CAST(@ValorCodigo AS VARCHAR),6);
        SET @ImporteCambio = @ImporteRecibido - @TotalCosto;

        -- Insertar VENTA
        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
             IVA10, IVA5, Exento0)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdCliente, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'PreVenta', @IdOrdenVenta, @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        -- Insertar DETALLE_VENTA
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal, Activo, FechaRegistro, IvaPorcentaje, MontoIva)
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
        INNER JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        -- Marcar OV como Facturada
        UPDATE dbo.ORDEN_VENTA
        SET Estado='Facturada', FechaFacturado=GETDATE(),
            IdUsuarioFactura=@IdUsuarioCajero, IdVenta=@IdVentaGenerada, IdCliente=@IdCliente
        WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado = 1;
        SET @Mensaje = 'Venta facturada correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje = 'Error inesperado: ' + ERROR_MESSAGE();
        SET @IdVentaGenerada = 0;
        SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta con validacion de stock.';
GO
