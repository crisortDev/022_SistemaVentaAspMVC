-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 38b: Stored Procedures — Módulo de Ventas completo
-- ─────────────────────────────────────────────────────────────────────────────
-- SPs creados:
--   usp_ObtenerDatosTributarios      → timbrado vigente + próximo Nro factura
--   usp_RegistrarOrdenVenta          → registrar pre-venta (presupuesto)
--   usp_ObtenerListaOrdenVenta       → listar pre-ventas por filtros
--   usp_ObtenerDetalleOrdenVenta_V   → detalle de pre-venta para facturar
--   usp_AnularOrdenVenta             → anular pre-venta pendiente
--   usp_RegistrarVentaDirecta        → venta directa en un paso (cajero)
--   usp_FacturarDesdeOrdenVenta      → convertir pre-venta a factura
--   usp_ObtenerListaVenta_v2         → listar ventas con estado y tipo flujo
--   usp_ObtenerDetalleVenta_v2       → detalle completo para KuDE
--   usp_AnularVenta                  → anular venta (Encargado/Admin)
--   usp_RegistrarComprobanteCobro    → comprobante de cobro (auto por venta)
--   usp_ObtenerListaComprobanteCobro → listar comprobantes de cobro
--   usp_RegistrarNotaCreditoVenta    → registrar NC de venta
--   usp_AprobarRechazarNCV           → aprobar o rechazar NC de venta
--   usp_ObtenerListaNotaCreditoVenta → listar NCs de venta
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. usp_ObtenerDatosTributarios
--    Devuelve el timbrado vigente y genera el próximo número de factura
--    Formato Paraguay SET: 001-001-0000001 (Estab-PuntoExp-Secuencia)
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDatosTributarios]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        NumeroTimbrado,
        CONVERT(VARCHAR(10), VencimientoTimbrado, 103) AS VencimientoTimbrado,
        Establecimiento,
        PuntoExpedicion,
        SecuenciaActual,
        -- Próximo número de factura formateado
        Establecimiento + '-' + PuntoExpedicion + '-'
            + RIGHT('0000000' + CAST(SecuenciaActual + 1 AS VARCHAR), 7) AS ProximoNumeroFactura
    FROM dbo.DATOS_TRIBUTARIOS;
END
GO
PRINT 'OK: usp_ObtenerDatosTributarios';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. usp_RegistrarOrdenVenta
--    Registra una pre-venta (presupuesto). Descuenta stock preventivo NO.
--    El stock se descuenta recién al facturar.
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarOrdenVenta]
    @IdTienda           INT,
    @IdCliente          INT,
    @IdUsuarioRegistro  INT,
    @Observacion        VARCHAR(500),
    @FechaVencimiento   DATE,
    @Detalle            NVARCHAR(MAX),   -- JSON-like: se pasa como XML
    @DetalleXml         XML,
    @IdOVGenerada       INT           OUTPUT,
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Validar fecha vencimiento
        IF @FechaVencimiento < CAST(GETDATE() AS DATE)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'La fecha de vencimiento no puede ser anterior a hoy.';
            ROLLBACK; RETURN;
        END

        -- Validar que hay al menos un producto
        IF (SELECT COUNT(*) FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)) = 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Debe incluir al menos un producto.';
            ROLLBACK; RETURN;
        END

        -- Calcular totales desde el XML
        DECLARE @TotalEstimado DECIMAL(18,2) = 0,
                @IVA10Total    DECIMAL(18,2) = 0,
                @IVA5Total     DECIMAL(18,2) = 0,
                @Exento0Total  DECIMAL(18,2) = 0;

        SELECT
            @TotalEstimado = SUM(
                n.value('(Cantidad)[1]',  'INT') *
                n.value('(PrecioUnidad)[1]', 'DECIMAL(18,2)')
                * (1 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100)
            ),
            @IVA10Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                     * 10.0/110.0 ELSE 0 END),
            @IVA5Total  = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                     * 5.0/105.0 ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                ELSE 0 END)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        -- Generar número correlativo
        DECLARE @Correlativo INT = ISNULL((SELECT MAX(IdOrdenVenta) FROM dbo.ORDEN_VENTA), 0) + 1;
        DECLARE @NumeroOV VARCHAR(20) = 'OV-' + RIGHT('00000000' + CAST(@Correlativo AS VARCHAR), 8);

        INSERT INTO dbo.ORDEN_VENTA
            (NumeroOV, IdTienda, IdCliente, IdUsuarioRegistro, TotalEstimado,
             IVA10, IVA5, Exento0, Estado, Observacion, FechaVencimiento, Activo)
        VALUES
            (@NumeroOV, @IdTienda, NULLIF(@IdCliente, 0), @IdUsuarioRegistro,
             @TotalEstimado, @IVA10Total, @IVA5Total, @Exento0Total,
             'Pendiente', @Observacion, @FechaVencimiento, 1);

        SET @IdOVGenerada = SCOPE_IDENTITY();

        -- Insertar detalle
        INSERT INTO dbo.DETALLE_ORDEN_VENTA
            (IdOrdenVenta, IdProducto, Cantidad, PrecioUnidad, IvaPorcentaje, TotalLinea, TotalLineaIva)
        SELECT
            @IdOVGenerada,
            n.value('(IdProducto)[1]',   'INT'),
            n.value('(Cantidad)[1]',     'INT'),
            n.value('(PrecioUnidad)[1]', 'DECIMAL(18,2)'),
            n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                * (1 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        SET @Resultado = 1;
        SET @Mensaje   = 'Pre-venta registrada: ' + @NumeroOV;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
        SET @IdOVGenerada = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarOrdenVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. usp_ObtenerListaOrdenVenta
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaOrdenVenta]
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = '',
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL,
    @NumeroOV    VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        ov.IdOrdenVenta,
        ov.NumeroOV,
        ov.Estado,
        ov.TotalEstimado,
        ov.IVA10,
        ov.IVA5,
        CONVERT(VARCHAR(10), ov.FechaRegistro, 103)   AS FechaRegistro,
        CONVERT(VARCHAR(10), ov.FechaVencimiento, 103) AS FechaVencimiento,
        ov.Observacion,
        t.Nombre    AS NombreTienda,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        ISNULL(c.Nombre, 'Sin asignar') AS NombreCliente,
        ISNULL(c.NumeroDocumento, '')   AS DocumentoCliente,
        -- Alerta de vencimiento
        CASE
            WHEN ov.Estado = 'Pendiente' AND ov.FechaVencimiento < CAST(GETDATE() AS DATE) THEN 'VENCIDA'
            WHEN ov.Estado = 'Pendiente' AND ov.FechaVencimiento = CAST(GETDATE() AS DATE) THEN 'VENCE HOY'
            ELSE ''
        END AS AlertaVencimiento
    FROM dbo.ORDEN_VENTA ov
    INNER JOIN dbo.TIENDA   t ON t.IdTienda  = ov.IdTienda
    INNER JOIN dbo.USUARIO  u ON u.IdUsuario = ov.IdUsuarioRegistro
    LEFT  JOIN dbo.CLIENTE  c ON c.IdCliente = ov.IdCliente
    WHERE ov.Activo = 1
      AND (@IdTienda = 0 OR ov.IdTienda = @IdTienda)
      AND (@Estado = '' OR ov.Estado = @Estado)
      AND (@NumeroOV = '' OR ov.NumeroOV LIKE '%' + @NumeroOV + '%')
      AND CAST(ov.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY ov.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerListaOrdenVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. usp_ObtenerDetalleOrdenVenta_V (para pantalla de facturar)
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleOrdenVenta_V]
    @IdOrdenVenta INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Cabecera
    SELECT
        ov.IdOrdenVenta, ov.NumeroOV, ov.Estado,
        ov.TotalEstimado, ov.IVA10, ov.IVA5, ov.Exento0,
        CONVERT(VARCHAR(10), ov.FechaRegistro, 103)    AS FechaRegistro,
        CONVERT(VARCHAR(10), ov.FechaVencimiento, 103) AS FechaVencimiento,
        ov.Observacion, ov.IdTienda, ov.IdCliente,
        ISNULL(c.Nombre, '')           AS NombreCliente,
        ISNULL(c.NumeroDocumento, '')  AS DocumentoCliente,
        ISNULL(c.Direccion, '')        AS DireccionCliente,
        ISNULL(c.Telefono, '')         AS TelefonoCliente,
        ISNULL(c.TipoDocumento, 'CI')  AS TipoDocumentoCliente,
        t.Nombre AS NombreTienda, t.RUC AS RUCTienda
    FROM dbo.ORDEN_VENTA ov
    LEFT  JOIN dbo.CLIENTE c ON c.IdCliente = ov.IdCliente
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = ov.IdTienda
    WHERE ov.IdOrdenVenta = @IdOrdenVenta;

    -- Detalle productos
    SELECT
        d.IdDetalleOV,
        d.IdProducto,
        p.Codigo,
        p.Nombre        AS NombreProducto,
        d.Cantidad,
        d.PrecioUnidad,
        d.IvaPorcentaje,
        d.TotalLinea,
        d.TotalLineaIva,
        ISNULL(pt.Stock, 0) AS StockDisponible
    FROM dbo.DETALLE_ORDEN_VENTA d
    INNER JOIN dbo.PRODUCTO       p  ON p.IdProducto  = d.IdProducto
    LEFT  JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = d.IdProducto
              AND pt.IdTienda = (SELECT IdTienda FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta)
    WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleOrdenVenta_V';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. usp_AnularOrdenVenta
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_AnularOrdenVenta]
    @IdOrdenVenta   INT,
    @IdUsuario      INT,
    @MotivoAnulacion VARCHAR(500),
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual VARCHAR(20);
        SELECT @EstadoActual = Estado FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @EstadoActual IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Pre-venta no encontrada.'; RETURN; END

        IF @EstadoActual NOT IN ('Pendiente')
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Solo se pueden anular pre-ventas en estado Pendiente.'; RETURN; END

        IF ISNULL(@MotivoAnulacion, '') = ''
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Debe ingresar el motivo de anulación.'; RETURN; END

        UPDATE dbo.ORDEN_VENTA
        SET Estado = 'Anulada', MotivoAnulacion = @MotivoAnulacion,
            FechaAnulacion = GETDATE()
        WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado = 1; SET @Mensaje = 'Pre-venta anulada correctamente.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AnularOrdenVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- Función auxiliar interna: generar próximo número de factura (atómico)
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_GenerarNumeroFactura]
    @NumeroFactura VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Nueva INT, @Estab VARCHAR(3), @Punto VARCHAR(3);

    UPDATE dbo.DATOS_TRIBUTARIOS
    SET SecuenciaActual = SecuenciaActual + 1;

    SELECT @Nueva = SecuenciaActual, @Estab = Establecimiento, @Punto = PuntoExpedicion
    FROM dbo.DATOS_TRIBUTARIOS;

    -- Validar que timbrado no esté vencido
    IF EXISTS (SELECT 1 FROM dbo.DATOS_TRIBUTARIOS WHERE VencimientoTimbrado < CAST(GETDATE() AS DATE))
    BEGIN
        -- revertir
        UPDATE dbo.DATOS_TRIBUTARIOS SET SecuenciaActual = SecuenciaActual - 1;
        SET @NumeroFactura = NULL;
        RETURN;
    END

    SET @NumeroFactura = @Estab + '-' + @Punto + '-' + RIGHT('0000000' + CAST(@Nueva AS VARCHAR), 7);
END
GO
PRINT 'OK: usp_GenerarNumeroFactura (auxiliar)';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. usp_RegistrarVentaDirecta
--    Venta directa del cajero: registra VENTA + DETALLE + COMPROBANTE_COBRO
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarVentaDirecta]
    @IdTienda       INT,
    @IdUsuario      INT,
    @IdCliente      INT,
    @IdFormaCobro   INT,
    @ImporteRecibido DECIMAL(18,2),
    @DetalleXml     XML,
    @IdVentaGenerada INT          OUTPUT,
    @NumeroFactura  VARCHAR(20)   OUTPUT,
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Validar cliente
        IF @IdCliente = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE IdCliente = @IdCliente)
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Cliente inválido.'; ROLLBACK; RETURN;
        END

        -- Validar que hay productos
        IF (SELECT COUNT(*) FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)) = 0
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Debe incluir al menos un producto.'; ROLLBACK; RETURN;
        END

        -- Calcular totales con IVA
        DECLARE @TotalCosto   DECIMAL(18,2),
                @IVA10Total   DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2),
                @Exento0Total DECIMAL(18,2);

        SELECT
            @TotalCosto = SUM(
                n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                * (1 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100)
            ),
            @IVA10Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0/110.0
                ELSE 0 END),
            @IVA5Total  = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0/105.0
                ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                THEN n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                ELSE 0 END)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        -- Validar importe recibido
        IF @ImporteRecibido < @TotalCosto
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El importe recibido (' + CAST(@ImporteRecibido AS VARCHAR) + ') es menor al total (' + CAST(@TotalCosto AS VARCHAR) + ').';
            ROLLBACK; RETURN;
        END

        -- Generar número de factura
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'El timbrado fiscal está vencido. Contacte al administrador.';
            ROLLBACK; RETURN;
        END

        DECLARE @Timbrado       VARCHAR(20),
                @VencTimbrado   DATE,
                @ValorCodigo    INT,
                @Codigo         VARCHAR(20),
                @ImporteCambio  DECIMAL(18,2);

        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        SET @ImporteCambio = @ImporteRecibido - @TotalCosto;

        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1 FROM dbo.VENTA;
        SET @Codigo = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);

        -- Insertar VENTA
        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdFormaCobro,
             IVA10, IVA5, Exento0)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuario, @IdCliente, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'Directa', @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        -- Insertar DETALLE_VENTA y descontar stock
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal, Activo, FechaRegistro, IvaPorcentaje, MontoIva)
        SELECT
            @IdVentaGenerada,
            n.value('(IdProducto)[1]',   'INT'),
            n.value('(Cantidad)[1]',     'INT'),
            n.value('(PrecioUnidad)[1]', 'DECIMAL(18,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                * (1 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100),
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
        INNER JOIN (
            SELECT n.value('(IdProducto)[1]','INT') AS IdProducto,
                   n.value('(Cantidad)[1]','INT')    AS Cantidad
            FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
        ) d ON d.IdProducto = pt.IdProducto AND pt.IdTienda = @IdTienda;

        -- Registrar COMPROBANTE_COBRO automáticamente
        DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO), 0) + 1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-' + RIGHT('00000000' + CAST(@NumCC AS VARCHAR), 8);

        INSERT INTO dbo.COMPROBANTE_COBRO
            (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro, MontoTotal, MontoRecibido, MontoCambio, Estado)
        VALUES
            (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuario, @IdFormaCobro,
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');

        SET @Resultado = 1;
        SET @Mensaje   = 'Venta registrada: ' + @Codigo + ' — Factura: ' + @NumeroFactura;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
        SET @IdVentaGenerada = 0; SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarVentaDirecta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. usp_FacturarDesdeOrdenVenta
--    Convierte una pre-venta en factura + comprobante de cobro
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdVentaGenerada INT          OUTPUT,
    @NumeroFactura   VARCHAR(20)  OUTPUT,
    @Resultado       BIT          OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Validar estado
        DECLARE @EstadoOV VARCHAR(20), @IdTienda INT;
        SELECT @EstadoOV = Estado, @IdTienda = IdTienda
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @EstadoOV IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Pre-venta no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoOV <> 'Pendiente'
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Solo se pueden facturar pre-ventas en estado Pendiente (estado actual: ' + @EstadoOV + ').'; ROLLBACK; RETURN; END

        -- Validar cliente
        IF @IdCliente = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE IdCliente = @IdCliente)
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Debe seleccionar un cliente válido.'; ROLLBACK; RETURN; END

        -- Obtener detalle de la OV
        DECLARE @TotalCosto   DECIMAL(18,2),
                @IVA10Total   DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2),
                @Exento0Total DECIMAL(18,2);

        SELECT @TotalCosto = TotalEstimado, @IVA10Total = IVA10,
               @IVA5Total = IVA5, @Exento0Total = Exento0
        FROM dbo.ORDEN_VENTA WHERE IdOrdenVenta = @IdOrdenVenta;

        IF @ImporteRecibido < @TotalCosto
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Importe recibido insuficiente.'; ROLLBACK; RETURN; END

        -- Generar número de factura
        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT;
        IF @NumeroFactura IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Timbrado fiscal vencido.'; ROLLBACK; RETURN; END

        DECLARE @Timbrado     VARCHAR(20), @VencTimbrado DATE;
        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        DECLARE @ValorCodigo  INT, @Codigo VARCHAR(20), @ImporteCambio DECIMAL(18,2);
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1 FROM dbo.VENTA;
        SET @Codigo = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);
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

        -- Insertar DETALLE_VENTA desde DETALLE_ORDEN_VENTA + descontar stock
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal, Activo, FechaRegistro, IvaPorcentaje, MontoIva)
        SELECT
            @IdVentaGenerada, d.IdProducto, d.Cantidad, d.PrecioUnidad,
            d.TotalLineaIva, 1, GETDATE(), d.IvaPorcentaje,
            CASE WHEN d.IvaPorcentaje = 10 THEN d.TotalLinea * 10.0/110.0
                 WHEN d.IvaPorcentaje = 5  THEN d.TotalLinea * 5.0/105.0
                 ELSE 0 END
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- Descontar stock
        UPDATE pt
        SET pt.Stock = pt.Stock - d.Cantidad
        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        -- Actualizar OrdenVenta a Facturada
        UPDATE dbo.ORDEN_VENTA
        SET Estado = 'Facturada', FechaFacturado = GETDATE(),
            IdUsuarioFactura = @IdUsuarioCajero, IdVenta = @IdVentaGenerada,
            IdCliente = @IdCliente
        WHERE IdOrdenVenta = @IdOrdenVenta;

        -- Registrar COMPROBANTE_COBRO
        DECLARE @NumCC INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO), 0) + 1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-' + RIGHT('00000000' + CAST(@NumCC AS VARCHAR), 8);

        INSERT INTO dbo.COMPROBANTE_COBRO
            (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro, MontoTotal, MontoRecibido, MontoCambio, Estado)
        VALUES
            (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');

        SET @Resultado = 1;
        SET @Mensaje   = 'Facturado: ' + @Codigo + ' — ' + @NumeroFactura;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
        SET @IdVentaGenerada = 0; SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. usp_ObtenerListaVenta_v2
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaVenta_v2]
    @IdTienda        INT = 0,
    @FechaInicio     DATE = NULL,
    @FechaFin        DATE = NULL,
    @NumeroFactura   VARCHAR(30) = '',
    @NumeroDocumento VARCHAR(50) = '',
    @NombreCliente   VARCHAR(100) = '',
    @TipoFlujo       VARCHAR(20) = '',
    @Estado          VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        v.IdVenta,
        v.Codigo,
        v.NumeroFactura,
        v.NumeroTimbrado,
        v.TipoFlujo,
        v.Estado,
        CONVERT(VARCHAR(10), v.FechaRegistro, 103) AS FechaRegistro,
        v.TotalCosto,
        v.IVA10,
        v.IVA5,
        c.Nombre           AS NombreCliente,
        c.NumeroDocumento  AS DocumentoCliente,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        t.Nombre           AS NombreTienda,
        ISNULL(ov.NumeroOV, '') AS NumeroOV,
        ISNULL(fc.Descripcion, '') AS FormaCobro
    FROM dbo.VENTA v
    INNER JOIN dbo.CLIENTE  c  ON c.IdCliente  = v.IdCliente
    INNER JOIN dbo.USUARIO  u  ON u.IdUsuario  = v.IdUsuario
    INNER JOIN dbo.TIENDA   t  ON t.IdTienda   = v.IdTienda
    LEFT  JOIN dbo.ORDEN_VENTA ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    LEFT  JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    WHERE v.Activo = 1
      AND (@IdTienda = 0 OR v.IdTienda = @IdTienda)
      AND CAST(v.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (@NumeroFactura   = '' OR v.NumeroFactura LIKE '%' + @NumeroFactura + '%')
      AND (@NumeroDocumento = '' OR c.NumeroDocumento LIKE '%' + @NumeroDocumento + '%')
      AND (@NombreCliente   = '' OR c.Nombre LIKE '%' + @NombreCliente + '%')
      AND (@TipoFlujo = '' OR v.TipoFlujo = @TipoFlujo)
      AND (@Estado    = '' OR v.Estado    = @Estado)
    ORDER BY v.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerListaVenta_v2';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 9. usp_ObtenerDetalleVenta_v2  (formato KuDE)
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleVenta_v2]
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;
    -- RS1: Cabecera de la venta
    SELECT
        v.IdVenta, v.Codigo, v.NumeroFactura, v.NumeroTimbrado,
        CONVERT(VARCHAR(10), v.VencimientoTimbrado, 103)  AS VencimientoTimbrado,
        CONVERT(VARCHAR(10), v.FechaRegistro, 103)        AS FechaRegistro,
        v.TipoDocumento, v.TipoFlujo, v.Estado,
        v.TotalCosto, v.ImporteRecibido, v.ImporteCambio,
        v.IVA10, v.IVA5, v.Exento0,
        -- Gravado 10% = TotalLinea sin IVA
        v.TotalCosto - v.IVA10 - v.IVA5 - v.Exento0  AS Gravado10,
        v.IVA5                                         AS Gravado5Base,
        -- Emisor
        t.Nombre AS NombreEmisor, t.RUC AS RUCEmisor, t.Direccion AS DireccionEmisor,
        t.Telefono AS TelefonoEmisor,
        -- Timbrado SET
        dt.Establecimiento, dt.PuntoExpedicion,
        -- Cajero
        u.Nombres + ' ' + u.Apellidos AS NombreCajero,
        -- Cliente
        c.Nombre AS NombreCliente, c.NumeroDocumento AS DocumentoCliente,
        c.TipoDocumento AS TipoDocumentoCliente,
        c.Direccion AS DireccionCliente, c.Telefono AS TelefonoCliente,
        -- Forma de cobro
        ISNULL(fc.Descripcion, 'Efectivo') AS FormaCobro
    FROM dbo.VENTA v
    INNER JOIN dbo.TIENDA       t  ON t.IdTienda   = v.IdTienda
    INNER JOIN dbo.USUARIO      u  ON u.IdUsuario  = v.IdUsuario
    INNER JOIN dbo.CLIENTE      c  ON c.IdCliente  = v.IdCliente
    LEFT  JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro = v.IdFormaCobro
    CROSS JOIN dbo.DATOS_TRIBUTARIOS dt
    WHERE v.IdVenta = @IdVenta;

    -- RS2: Detalle de productos
    SELECT
        dv.IdDetalleVenta,
        p.Codigo      AS CodigoProducto,
        p.Nombre      AS NombreProducto,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        dv.ImporteTotal,
        -- Precio sin IVA (base imponible)
        CASE WHEN dv.IvaPorcentaje = 10
             THEN CAST(dv.ImporteTotal / 1.10 AS DECIMAL(18,2))
             WHEN dv.IvaPorcentaje = 5
             THEN CAST(dv.ImporteTotal / 1.05 AS DECIMAL(18,2))
             ELSE dv.ImporteTotal
        END AS ImporteSinIva
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 10. usp_AnularVenta
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_AnularVenta]
    @IdVenta         INT,
    @IdUsuario       INT,
    @MotivoAnulacion VARCHAR(500),
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @EstadoActual VARCHAR(20), @IdTienda INT;
        SELECT @EstadoActual = Estado, @IdTienda = IdTienda FROM dbo.VENTA WHERE IdVenta = @IdVenta;

        IF @EstadoActual IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Venta no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoActual = 'Anulada'
        BEGIN SET @Resultado=0; SET @Mensaje='La venta ya está anulada.'; ROLLBACK; RETURN; END

        IF ISNULL(@MotivoAnulacion,'') = ''
        BEGIN SET @Resultado=0; SET @Mensaje='Debe ingresar el motivo de anulación.'; ROLLBACK; RETURN; END

        -- Revertir stock
        UPDATE pt
        SET pt.Stock = pt.Stock + dv.Cantidad
        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN dbo.DETALLE_VENTA dv ON dv.IdProducto = pt.IdProducto
        WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1 AND pt.IdTienda = @IdTienda;

        UPDATE dbo.VENTA
        SET Estado = 'Anulada', MotivoAnulacion = @MotivoAnulacion,
            FechaAnulacion = GETDATE(), IdUsuarioAnula = @IdUsuario
        WHERE IdVenta = @IdVenta;

        SET @Resultado=1; SET @Mensaje='Venta anulada. Stock revertido.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje=ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AnularVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 11. usp_ObtenerListaComprobanteCobro
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaComprobanteCobro]
    @IdTienda    INT = 0,
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY,-7, CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        cc.IdComprobanteCobro,
        cc.NumeroCobro,
        cc.Estado,
        cc.MontoTotal,
        cc.MontoRecibido,
        cc.MontoCambio,
        CONVERT(VARCHAR(10), cc.FechaRegistro, 103) AS FechaRegistro,
        fc.Descripcion AS FormaCobro,
        v.NumeroFactura,
        v.Codigo       AS CodigoVenta,
        c.Nombre       AS NombreCliente,
        c.NumeroDocumento,
        u.Nombres + ' ' + u.Apellidos AS NombreCajero,
        t.Nombre AS NombreTienda
    FROM dbo.COMPROBANTE_COBRO cc
    INNER JOIN dbo.VENTA       v  ON v.IdVenta       = cc.IdVenta
    INNER JOIN dbo.CLIENTE     c  ON c.IdCliente     = v.IdCliente
    INNER JOIN dbo.USUARIO     u  ON u.IdUsuario     = cc.IdUsuario
    INNER JOIN dbo.TIENDA      t  ON t.IdTienda      = cc.IdTienda
    LEFT  JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE cc.Activo = 1
      AND (@IdTienda = 0 OR cc.IdTienda = @IdTienda)
      AND CAST(cc.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY cc.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerListaComprobanteCobro';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 12. usp_RegistrarNotaCreditoVenta
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarNotaCreditoVenta]
    @IdVenta            INT,
    @IdMotivoNC         INT,
    @Monto              DECIMAL(18,2),
    @Observacion        VARCHAR(500),
    @IdUsuarioRegistro  INT,
    @IdNCGenerada       INT           OUTPUT,
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar venta activa
        IF NOT EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdVenta = @IdVenta AND Estado = 'Activa')
        BEGIN SET @Resultado=0; SET @Mensaje='La venta no existe o ya está anulada.'; RETURN; END

        -- Solo una NC por venta
        IF EXISTS (SELECT 1 FROM dbo.NOTA_CREDITO_VENTA WHERE IdVenta = @IdVenta AND Activo = 1)
        BEGIN SET @Resultado=0; SET @Mensaje='Ya existe una Nota de Crédito para esta venta.'; RETURN; END

        DECLARE @TotalVenta DECIMAL(18,2);
        SELECT @TotalVenta = TotalCosto FROM dbo.VENTA WHERE IdVenta = @IdVenta;

        IF @Monto <= 0 OR @Monto > @TotalVenta
        BEGIN SET @Resultado=0; SET @Mensaje='El monto debe ser mayor a 0 y no exceder el total de la venta (' + CAST(@TotalVenta AS VARCHAR) + ').'; RETURN; END

        DECLARE @NumNCV INT = ISNULL((SELECT MAX(IdNCVenta) FROM dbo.NOTA_CREDITO_VENTA),0)+1;
        DECLARE @Numero VARCHAR(20) = 'NCV-' + RIGHT('00000000'+CAST(@NumNCV AS VARCHAR),8);

        INSERT INTO dbo.NOTA_CREDITO_VENTA
            (NumeroNCV, IdVenta, IdMotivoNC, Monto, Estado, Observacion, IdUsuarioRegistro)
        VALUES (@Numero, @IdVenta, @IdMotivoNC, @Monto, 'Pendiente', @Observacion, @IdUsuarioRegistro);

        SET @IdNCGenerada = SCOPE_IDENTITY();
        SET @Resultado=1; SET @Mensaje='NC registrada: ' + @Numero;
    END TRY
    BEGIN CATCH
        SET @Resultado=0; SET @Mensaje=ERROR_MESSAGE(); SET @IdNCGenerada=0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarNotaCreditoVenta';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 13. usp_AprobarRechazarNCV
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_AprobarRechazarNCV]
    @IdNCVenta       INT,
    @IdUsuario       INT,
    @Accion          VARCHAR(10),   -- 'Aprobar' | 'Rechazar'
    @MotivoRechazo   VARCHAR(500),
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @EstadoActual VARCHAR(20), @IdVenta INT, @IdTienda INT, @Monto DECIMAL(18,2);
        SELECT @EstadoActual = Estado, @IdVenta = IdVenta, @Monto = Monto
        FROM dbo.NOTA_CREDITO_VENTA WHERE IdNCVenta = @IdNCVenta;

        IF @EstadoActual IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='NC no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoActual <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='La NC ya fue procesada (estado: '+@EstadoActual+').'; ROLLBACK; RETURN; END

        IF @Accion = 'Aprobar'
        BEGIN
            -- Revertir stock proporcional (simplificado: revierte todo si monto = total)
            SELECT @IdTienda = IdTienda FROM dbo.VENTA WHERE IdVenta = @IdVenta;
            DECLARE @TotalVenta DECIMAL(18,2);
            SELECT @TotalVenta = TotalCosto FROM dbo.VENTA WHERE IdVenta = @IdVenta;

            IF @Monto = @TotalVenta
            BEGIN
                UPDATE pt SET pt.Stock = pt.Stock + dv.Cantidad
                FROM dbo.PRODUCTO_TIENDA pt
                INNER JOIN dbo.DETALLE_VENTA dv ON dv.IdProducto = pt.IdProducto
                WHERE dv.IdVenta = @IdVenta AND dv.Activo=1 AND pt.IdTienda=@IdTienda;
            END

            UPDATE dbo.NOTA_CREDITO_VENTA
            SET Estado='Aprobada', IdUsuarioAprueba=@IdUsuario, FechaAprobacion=GETDATE()
            WHERE IdNCVenta=@IdNCVenta;

            SET @Resultado=1; SET @Mensaje='NC aprobada. Stock revertido.';
        END
        ELSE IF @Accion = 'Rechazar'
        BEGIN
            IF ISNULL(@MotivoRechazo,'') = ''
            BEGIN SET @Resultado=0; SET @Mensaje='Debe ingresar el motivo de rechazo.'; ROLLBACK; RETURN; END

            UPDATE dbo.NOTA_CREDITO_VENTA
            SET Estado='Rechazada', IdUsuarioAprueba=@IdUsuario,
                FechaAprobacion=GETDATE(), MotivoRechazo=@MotivoRechazo
            WHERE IdNCVenta=@IdNCVenta;

            SET @Resultado=1; SET @Mensaje='NC rechazada.';
        END
        ELSE
        BEGIN SET @Resultado=0; SET @Mensaje='Acción inválida (usar Aprobar o Rechazar).'; ROLLBACK; RETURN; END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje=ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AprobarRechazarNCV';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 14. usp_ObtenerListaNotaCreditoVenta
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaNotaCreditoVenta]
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = '',
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY,-30,CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        nc.IdNCVenta, nc.NumeroNCV, nc.Estado, nc.Monto, nc.Observacion,
        CONVERT(VARCHAR(10), nc.FechaRegistro, 103) AS FechaRegistro,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaAprobacion, 103),'') AS FechaAprobacion,
        v.NumeroFactura, v.Codigo AS CodigoVenta,
        c.Nombre AS NombreCliente, c.NumeroDocumento,
        m.Descripcion AS MotivoNC,
        u.Nombres+' '+u.Apellidos AS NombreRegistro,
        t.Nombre AS NombreTienda,
        ISNULL(nc.MotivoRechazo,'') AS MotivoRechazo
    FROM dbo.NOTA_CREDITO_VENTA nc
    INNER JOIN dbo.VENTA   v ON v.IdVenta    = nc.IdVenta
    INNER JOIN dbo.CLIENTE c ON c.IdCliente  = v.IdCliente
    INNER JOIN dbo.TIENDA  t ON t.IdTienda   = v.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario  = nc.IdUsuarioRegistro
    INNER JOIN dbo.MOTIVO_NOTA_CREDITO m ON m.IdMotivoNotaCredito = nc.IdMotivoNC
    WHERE nc.Activo = 1
      AND (@IdTienda = 0 OR v.IdTienda = @IdTienda)
      AND (@Estado = '' OR nc.Estado = @Estado)
      AND CAST(nc.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY nc.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerListaNotaCreditoVenta';
GO

PRINT '';
PRINT '════════════════════════════════════════════════════════════';
PRINT 'Script 38b completado — SPs módulo ventas listos.';
PRINT 'Ejecutar a continuación: 38c_Menu_Permisos_DatosPrueba.sql';
PRINT '════════════════════════════════════════════════════════════';
GO
