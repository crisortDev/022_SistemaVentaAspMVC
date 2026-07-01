-- ============================================================
-- Script 73: Vincular VENTA a CAJA (IdCaja en tabla VENTA)
-- Fecha: 2026-05-19
--
-- PROBLEMA:
--   Si dos cajeros abren caja al mismo tiempo en la misma
--   sucursal, ambos ven TODAS las ventas del turno porque
--   usp_ObtenerOperacionesCaja filtra por IdTienda+fechas.
--
-- SOLUCIÓN:
--   1. Agregar columna IdCaja INT NULL a VENTA
--   2. usp_RegistrarVentaDirecta acepta @IdCaja y lo graba
--   3. usp_FacturarDesdeOrdenVenta ídem
--   4. usp_ObtenerOperacionesCaja filtra por v.IdCaja = @IdCaja
--      (fallback a tienda+fecha para ventas históricas sin IdCaja)
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
-- 1. COLUMNA IdCaja en VENTA
-- ════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IdCaja'
)
BEGIN
    ALTER TABLE dbo.VENTA ADD IdCaja INT NULL;
    PRINT 'OK: Columna IdCaja agregada a VENTA.';
END
ELSE
    PRINT 'INFO: Columna IdCaja ya existe en VENTA.';
GO

-- FK opcional (con NOCHECK para no romper filas históricas sin caja)
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_VENTA_CAJA' AND parent_object_id = OBJECT_ID('dbo.VENTA')
)
BEGIN
    ALTER TABLE dbo.VENTA
    ADD CONSTRAINT FK_VENTA_CAJA FOREIGN KEY (IdCaja)
        REFERENCES dbo.CAJA (IdCaja)
        WITH NOCHECK;
    PRINT 'OK: FK FK_VENTA_CAJA creada (NOCHECK para datos históricos).';
END
GO

-- ════════════════════════════════════════════════════════════
-- 2. usp_RegistrarVentaDirecta — agrega @IdCaja
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarVentaDirecta]
    @IdTienda        INT,
    @IdUsuario       INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @DetalleXml      XML,
    @IdCaja          INT           = NULL,   -- caja del cajero (puede ser NULL)
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

        -- Calcular totales (PrecioUnidad ya incluye IVA)
        DECLARE @TotalCosto   DECIMAL(18,2),
                @IVA10Total   DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2),
                @Exento0Total DECIMAL(18,2);

        SELECT
            @TotalCosto   = SUM(n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')),
            @IVA10Total   = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0/110.0
                                ELSE 0 END),
            @IVA5Total    = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0/105.0
                                ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                                ELSE 0 END)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        IF @ImporteRecibido < @TotalCosto
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El importe recibido es menor al total (' + CAST(@TotalCosto AS VARCHAR) + ').';
            ROLLBACK; RETURN;
        END

        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT;
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
            WHERE pt.Stock < n.value('(Cantidad)[1]','INT')
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
            n.value('(Cantidad)[1]',     'INT'),
            n.value('(PrecioUnidad)[1]', 'DECIMAL(18,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)'),
            1, GETDATE(),
            n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)'),
            CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                 THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0/110.0
                 WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                 THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0/105.0
                 ELSE 0 END
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        -- Descontar stock
        UPDATE pt
        SET pt.Stock = pt.Stock - d.Cantidad
        FROM dbo.PRODUCTO_TIENDA pt
        JOIN (
            SELECT n.value('(IdProducto)[1]','INT') AS IdProducto,
                   n.value('(Cantidad)[1]',   'INT') AS Cantidad
            FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
        ) d ON d.IdProducto = pt.IdProducto AND pt.IdTienda = @IdTienda;

        -- Comprobante de cobro
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
PRINT 'OK: usp_RegistrarVentaDirecta — IdCaja incluido.';
GO

-- ════════════════════════════════════════════════════════════
-- 3. usp_FacturarDesdeOrdenVenta — agrega @IdCaja
--    y el INSERT faltante a COMPROBANTE_COBRO
--    (las ventas desde pre-venta tampoco tenían MontoRecibido/Cambio)
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdCaja          INT           = NULL,   -- caja del cajero
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
        DECLARE @TotalCosto   DECIMAL(18,2), @IVA10Total  DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2), @Exento0Total DECIMAL(18,2);
        SELECT @TotalCosto=TotalEstimado, @IVA10Total=IVA10, @IVA5Total=IVA5, @Exento0Total=Exento0
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @ImporteRecibido < @TotalCosto
        BEGIN SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente.'; ROLLBACK; RETURN; END

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
            SET @Resultado = 0;
            SET @Mensaje = 'Stock insuficiente: ' + @ProductoSinStock;
            ROLLBACK; RETURN;
        END

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

        -- Insertar VENTA (con IdCaja para aislamiento por cajero)
        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
             IVA10, IVA5, Exento0, IdCaja)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdCliente, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'PreVenta', @IdOrdenVenta, @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total, @IdCaja);

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
        INNER JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        -- Comprobante de cobro (faltaba en versión anterior)
        DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO), 0) + 1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-' + RIGHT('00000000' + CAST(@NumCC AS VARCHAR), 8);

        INSERT INTO dbo.COMPROBANTE_COBRO
            (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
             MontoTotal, MontoRecibido, MontoCambio, Estado)
        VALUES
            (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');

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
PRINT 'OK: usp_FacturarDesdeOrdenVenta — IdCaja + COMPROBANTE_COBRO incluidos.';
GO

-- ════════════════════════════════════════════════════════════
-- 4. usp_ObtenerOperacionesCaja — filtra por IdCaja exacta
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerOperacionesCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda      INT;
    DECLARE @FechaApertura DATETIME;
    DECLARE @FechaCierre   DATETIME;

    SELECT @IdTienda      = IdTienda,
           @FechaApertura = FechaApertura,
           @FechaCierre   = ISNULL(FechaCierre, GETDATE())
    FROM   dbo.CAJA
    WHERE  IdCaja = @IdCaja;

    -- ── RS1: Detalle operación por operación ─────────────────────
    -- Prioridad: ventas con IdCaja exacto (cajero que abrió esta caja)
    -- Fallback: ventas sin IdCaja del mismo turno (compatibilidad histórica)
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        CONVERT(VARCHAR(19), v.FechaRegistro, 120)              AS FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')                    AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))   AS FormaCobro,
        v.TotalCosto                                            AS Monto,
        ISNULL(cc.MontoRecibido, 0)                             AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                             AS MontoCambio,
        u.Nombres + ' ' + u.Apellidos                           AS NombreCajero,
        v.Estado
    FROM   dbo.VENTA             v
    INNER  JOIN dbo.USUARIO      u  ON u.IdUsuario    = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE      c  ON c.IdCliente    = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  (
               -- Ventas directamente vinculadas a esta caja (nueva lógica)
               v.IdCaja = @IdCaja
               OR
               -- Ventas históricas sin IdCaja: filtrar por tienda+período (lógica vieja)
               (v.IdCaja IS NULL
                AND v.IdTienda       = @IdTienda
                AND v.FechaRegistro >= @FechaApertura
                AND v.FechaRegistro <= @FechaCierre)
           )
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- ── RS2: Resumen por forma de cobro ───────────────────────────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))   AS FormaCobro,
        COUNT(v.IdVenta)  AS Cantidad,
        SUM(v.TotalCosto) AS TotalMonto
    FROM   dbo.VENTA             v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta    = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro    = cc.IdFormaCobro
    WHERE  (
               v.IdCaja = @IdCaja
               OR
               (v.IdCaja IS NULL
                AND v.IdTienda       = @IdTienda
                AND v.FechaRegistro >= @FechaApertura
                AND v.FechaRegistro <= @FechaCierre)
           )
      AND  v.Estado = 'Activa'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja — ahora filtra por IdCaja exacta.';
GO

PRINT '════ Script 73 completado ════';
PRINT '';
PRINT 'ACCION PENDIENTE: Agregar @IdCaja a usp_FacturarDesdeOrdenVenta manualmente';
PRINT 'si se quiere que las ventas desde pre-venta también queden vinculadas a la caja.';
GO
