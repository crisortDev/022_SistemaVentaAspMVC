-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 89: Descuentos por Categoría + Unidades de Medida
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- CAMBIOS:
--   1. CATEGORIA   → + UnidadMedida VARCHAR(20)  (default 'Unidad')
--                  → + DescuentoMaxPermitido DECIMAL(5,2) (default 0)
--   2. PRODUCTO    → + UnidadMedida VARCHAR(20)  (sincronizado desde categoría)
--   3. DETALLE_ORDEN_VENTA → + PorcentajeDescuento DECIMAL(5,2) (default 0)
--   4. DETALLE_VENTA       → + PorcentajeDescuento DECIMAL(5,2) (default 0)
--   5. Datos: categorías de cables → UnidadMedida = 'Metro'
--   6. usp_ObtenerCategorias       → incluye UnidadMedida, DescuentoMaxPermitido
--   7. usp_RegistrarCategoria      → acepta UnidadMedida, DescuentoMaxPermitido
--   8. usp_ModificarCategoria      → acepta UnidadMedida, DescuentoMaxPermitido
--   9. usp_ObtenerProductoTienda   → incluye UnidadMedida, DescuentoMaxPermitido
--  10. usp_FacturarDesdeOrdenVenta → aplica PorcentajeDescuento al precio, lo guarda
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. CATEGORIA: nuevas columnas ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CATEGORIA') AND name = 'UnidadMedida')
    ALTER TABLE dbo.CATEGORIA ADD UnidadMedida VARCHAR(20) NOT NULL DEFAULT 'Unidad';
PRINT 'OK: CATEGORIA.UnidadMedida asegurada.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CATEGORIA') AND name = 'DescuentoMaxPermitido')
    ALTER TABLE dbo.CATEGORIA ADD DescuentoMaxPermitido DECIMAL(5,2) NOT NULL DEFAULT 0;
PRINT 'OK: CATEGORIA.DescuentoMaxPermitido asegurada.';
GO

-- ─── 2. PRODUCTO: nueva columna UnidadMedida ─────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.PRODUCTO') AND name = 'UnidadMedida')
    ALTER TABLE dbo.PRODUCTO ADD UnidadMedida VARCHAR(20) NOT NULL DEFAULT 'Unidad';
PRINT 'OK: PRODUCTO.UnidadMedida asegurada.';
GO

-- ─── 3. DETALLE_ORDEN_VENTA: PorcentajeDescuento ─────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_ORDEN_VENTA') AND name = 'PorcentajeDescuento')
    ALTER TABLE dbo.DETALLE_ORDEN_VENTA ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;
PRINT 'OK: DETALLE_ORDEN_VENTA.PorcentajeDescuento asegurada.';
GO

-- ─── 4. DETALLE_VENTA: PorcentajeDescuento ───────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA') AND name = 'PorcentajeDescuento')
    ALTER TABLE dbo.DETALLE_VENTA ADD PorcentajeDescuento DECIMAL(5,2) NOT NULL DEFAULT 0;
PRINT 'OK: DETALLE_VENTA.PorcentajeDescuento asegurada.';
GO

-- ─── 5. Datos: categorías de cables → Metro ───────────────────────────────────
UPDATE dbo.CATEGORIA
   SET UnidadMedida = 'Metro'
WHERE  Descripcion LIKE '%CABLE%'
   AND UnidadMedida = 'Unidad';
PRINT 'OK: Categorías de cables actualizadas a UnidadMedida = Metro.';

-- Sincronizar UnidadMedida de categoría a producto (solo para los que aún son "Unidad")
UPDATE p
   SET p.UnidadMedida = c.UnidadMedida
FROM   dbo.PRODUCTO p
INNER  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
WHERE  c.UnidadMedida <> 'Unidad'
  AND  p.UnidadMedida = 'Unidad';
PRINT 'OK: Productos sincronizados con UnidadMedida de su categoría.';
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
    -- Verificar duplicado de descripción (otro IdCategoria con mismo nombre)
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

-- ─── 9. usp_ObtenerProductoTienda: agrega UnidadMedida + DescuentoMaxPermitido ─
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

        -- Unidad de medida del producto (sincronizada con categoría)
        ISNULL(p.UnidadMedida, 'Unidad')          AS UnidadMedida,

        pt.IdTienda,
        pt.Stock,
        pt.StockMinimo,
        pt.StockMaximo                             AS StockMaximoTienda,
        pt.PrecioVenta,
        pt.PrecioVentaIvaIncluido,
        pt.PrecioCompraIvaIncluido,
        pt.PrecioUnidadCompra,
        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra) AS CostoPromedio,
        pt.PrecioUnidadVenta,
        pt.PorcentajeIva,

        -- Margen y precio sugerido desde categoría
        ISNULL(cat.PorcentajeGanancia,    0)       AS MargenCategoria,
        ISNULL(cat.DescuentoMaxPermitido, 0)        AS DescuentoMaxPermitido,
        ISNULL(cat.UnidadMedida,         'Unidad') AS UnidadMedidaCategoria,

        -- PrecioSugerido = CPP × (1 + margen%) × (1 + IVA%)
        CASE
            WHEN ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra) > 0
                 AND ISNULL(cat.PorcentajeGanancia, 0) > 0
            THEN ROUND(
                    ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
                    * (1.0 + ISNULL(cat.PorcentajeGanancia, 0) / 100.0)
                    * (1.0 + p.IvaPorcentaje             / 100.0),
                 0)
            ELSE pt.PrecioVenta
        END                                        AS PrecioSugerido,

        -- Estado visual de stock
        CASE
            WHEN pt.Stock <= 0                  THEN 'SinStock'
            WHEN pt.Stock <= pt.StockMinimo     THEN 'Critico'
            ELSE                                     'Ok'
        END                                        AS EstadoStock,

        -- Categoría
        cat.IdCategoria                            AS IdCategoriaFK,
        cat.Descripcion                            AS NombreCategoria

    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p   ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA cat ON cat.IdCategoria = p.IdCategoria
    WHERE pt.IdTienda = @IdTienda
      AND p.Activo    = 1
    ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductoTienda actualizado — UnidadMedida + DescuentoMaxPermitido.';

-- ─── 10. usp_FacturarDesdeOrdenVenta: aplica descuento al precio ──────────────
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

        -- Datos base de la orden de venta
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

        -- Verificar que no esté ya facturada
        IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdOrdenVenta = @IdOrdenVenta AND Estado = 'Activa')
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Esta orden ya fue facturada.'; ROLLBACK; RETURN;
        END

        -- Timbrado vigente
        SELECT TOP 1
               @Timbrado     = NumeroTimbrado,
               @VencTimbrado = VencimientoTimbrado
        FROM   dbo.PARAMETROS_TRIBUTARIOS
        WHERE  IdTienda           = @IdTienda
          AND  Activo             = 1
          AND  VencimientoTimbrado >= CAST(GETDATE() AS DATE)
        ORDER BY VencimientoTimbrado DESC;

        IF @Timbrado IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'No hay timbrado vigente para esta tienda.'; ROLLBACK; RETURN;
        END

        -- Número de factura
        DECLARE @UltimoNum INT = ISNULL(
            (SELECT MAX(CAST(NumeroFactura AS INT))
             FROM   dbo.VENTA
             WHERE  IdTienda = @IdTienda
               AND  NumeroTimbrado = @Timbrado
               AND  ISNUMERIC(NumeroFactura) = 1),
            0);
        SET @NumeroFactura = CAST(@UltimoNum + 1 AS VARCHAR(20));
        SET @Codigo        = 'V-' + @NumeroFactura;
        SET @ValorCodigo   = @UltimoNum + 1;

        -- ── Calcular totales aplicando descuento ─────────────────────────────
        -- PrecioEfectivo = PrecioUnidad × (1 - PorcentajeDescuento/100)
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

        -- Fecha vencimiento crédito
        IF @Condicion = 'Crédito' AND @PlazoCredito > 0
            SET @FechaVenc = CAST(DATEADD(DAY, @PlazoCredito, GETDATE()) AS DATE);

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

        -- Detalle de venta (precio efectivo = precio con descuento aplicado)
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva, PorcentajeDescuento)
        SELECT
            @IdVentaGenerada,
            d.IdProducto,
            d.Cantidad,
            -- Precio efectivo ya con descuento
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0), 2),
            -- Importe total de línea
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
        WHERE  d.IdOrdenVenta = @IdOrdenVenta
          AND  d.Activo       = 1
          AND  pt.IdTienda    = @IdTienda;

        -- Comprobante de cobro (solo Contado)
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

        -- Marcar orden de venta como facturada
        UPDATE dbo.ORDEN_VENTA
           SET Estado = 'Facturada'
         WHERE IdOrdenVenta = @IdOrdenVenta;

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
PRINT 'OK: usp_FacturarDesdeOrdenVenta actualizado — aplica PorcentajeDescuento.';

-- ─── 11. usp_RegistrarOrdenVenta: guarda PorcentajeDescuento del XML ──────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarOrdenVenta]
    @IdTienda           INT,
    @IdCliente          INT            = NULL,
    @IdUsuarioRegistro  INT,
    @Observacion        VARCHAR(500)   = NULL,
    @FechaVencimiento   DATE,
    @DetalleXml         XML,
    @IdOVGenerada       INT            OUTPUT,
    @Resultado          BIT            OUTPUT,
    @Mensaje            NVARCHAR(400)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF @IdTienda IS NULL OR @IdTienda = 0
        BEGIN SET @Resultado=0; SET @Mensaje='Tienda no especificada.'; ROLLBACK; RETURN; END

        IF @FechaVencimiento < CAST(GETDATE() AS DATE)
        BEGIN SET @Resultado=0; SET @Mensaje='La fecha de vencimiento no puede ser anterior a hoy.'; ROLLBACK; RETURN; END

        IF (SELECT COUNT(*) FROM @DetalleXml.nodes('/Detalle/Item') AS t(n)) = 0
        BEGIN SET @Resultado=0; SET @Mensaje='Debe incluir al menos un producto.'; ROLLBACK; RETURN; END

        -- Calcular totales con descuento
        -- PrecioEfectivo = PrecioUnidad × (1 - PorcentajeDescuento/100)
        DECLARE @TotalEstimado DECIMAL(18,2),
                @IVA10Total    DECIMAL(18,2),
                @IVA5Total     DECIMAL(18,2),
                @Exento0Total  DECIMAL(18,2);

        SELECT
            @TotalEstimado = SUM(
                n.value('(Cantidad)[1]','INT') *
                ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                      * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
            ),
            @IVA10Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                THEN n.value('(Cantidad)[1]','INT')
                     * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                             * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                     * 10.0/110.0 ELSE 0 END),
            @IVA5Total  = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                THEN n.value('(Cantidad)[1]','INT')
                     * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                             * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                     * 5.0/105.0 ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                THEN n.value('(Cantidad)[1]','INT')
                     * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                             * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                ELSE 0 END)
        FROM @DetalleXml.nodes('/Detalle/Item') AS t(n);

        DECLARE @Correlativo INT = ISNULL((SELECT MAX(IdOrdenVenta) FROM dbo.ORDEN_VENTA),0)+1;
        DECLARE @NumeroOV VARCHAR(20) = 'OV-'+RIGHT('00000000'+CAST(@Correlativo AS VARCHAR),8);

        INSERT INTO dbo.ORDEN_VENTA
            (NumeroOV, IdTienda, IdCliente, IdUsuarioRegistro, TotalEstimado,
             IVA10, IVA5, Exento0, Estado, Observacion, FechaVencimiento, Activo)
        VALUES
            (@NumeroOV, @IdTienda, NULLIF(@IdCliente,0), @IdUsuarioRegistro,
             ISNULL(@TotalEstimado,0), ISNULL(@IVA10Total,0),
             ISNULL(@IVA5Total,0), ISNULL(@Exento0Total,0),
             'Pendiente', @Observacion, @FechaVencimiento, 1);

        SET @IdOVGenerada = SCOPE_IDENTITY();

        -- Insertar detalle con PorcentajeDescuento
        INSERT INTO dbo.DETALLE_ORDEN_VENTA
            (IdOrdenVenta, IdProducto, Cantidad, PrecioUnidad, IvaPorcentaje,
             TotalLinea, TotalLineaIva, PorcentajeDescuento)
        SELECT
            @IdOVGenerada,
            n.value('(IdProducto)[1]',    'INT'),
            n.value('(Cantidad)[1]',      'INT'),
            -- Guardamos precio original (el descuento se aplica en TotalLinea y al facturar)
            n.value('(PrecioUnidad)[1]',  'DECIMAL(18,2)'),
            n.value('(IvaPorcentaje)[1]', 'DECIMAL(5,2)'),
            -- TotalLinea = cantidad × precio con descuento
            n.value('(Cantidad)[1]','INT')
                * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                        * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2),
            n.value('(Cantidad)[1]','INT')
                * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                        * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                * (1.0 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100.0),
            ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'), 0)
        FROM @DetalleXml.nodes('/Detalle/Item') AS t(n);

        SET @Resultado = 1;
        SET @Mensaje   = 'Pre-venta registrada: ' + @NumeroOV;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado    = 0;
        SET @Mensaje      = ERROR_MESSAGE();
        SET @IdOVGenerada = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarOrdenVenta actualizado — guarda PorcentajeDescuento.';

-- ─── Verificación ────────────────────────────────────────────────────────────
SELECT c.IdCategoria, c.Descripcion, c.PorcentajeGanancia, c.UnidadMedida, c.DescuentoMaxPermitido
FROM   dbo.CATEGORIA c
ORDER  BY c.Descripcion;
GO

PRINT '════ Script 89 completado ════';
GO
