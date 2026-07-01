-- ============================================================
-- Script 69: Fix IVA doble en documento de venta
-- Fecha: 2026-05-19
--
-- PROBLEMA:
--   usp_RegistrarVentaDirecta calcula ImporteTotal como:
--     Cantidad * PrecioUnidad * (1 + IvaPorcentaje/100)
--   Pero PrecioUnidad YA incluye IVA (es el precio de venta al público).
--   Resultado: se suma IVA dos veces.
--     Ej: 107.250 * 1.10 = 117.975 guardado en DETALLE_VENTA.ImporteTotal
--
--   usp_ObtenerDetalleVenta_v2 lee ese ImporteTotal y divide por 1.10
--   para obtener ImporteSinIva:
--     117.975 / 1.10 = 107.250 → aparece como "Gravado" (INCORRECTO)
--     el Total de línea muestra 117.975 (INCORRECTO)
--
-- SOLUCIÓN en dos partes:
--   A) usp_ObtenerDetalleVenta_v2: leer desde PrecioUnidad*Cantidad
--      en lugar de ImporteTotal (corrige la VISUALIZACIÓN para todos los registros)
--   B) usp_RegistrarVentaDirecta: guardar ImporteTotal = Cantidad*PrecioUnidad
--      y TotalCosto = SUM(Cantidad*PrecioUnidad) (corrige REGISTROS FUTUROS)
--
-- Resultado esperado con precio 107.250 (IVA 10% incluido, qty=1):
--   Gravado (base sin IVA) = 97.500
--   Total línea (con IVA)  = 107.250
--   IVA10                  = 9.750
--   TOTAL VENTA            = 107.250
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
-- A) usp_ObtenerDetalleVenta_v2 — corregir cálculos del RS2
-- ════════════════════════════════════════════════════════════
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
    INNER JOIN dbo.TIENDA             t  ON t.IdTienda      = v.IdTienda
    INNER JOIN dbo.USUARIO            u  ON u.IdUsuario     = v.IdUsuario
    INNER JOIN dbo.CLIENTE            c  ON c.IdCliente     = v.IdCliente
    LEFT  JOIN dbo.FORMA_COBRO        fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT  JOIN dbo.ORDEN_VENTA        ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    CROSS JOIN dbo.DATOS_TRIBUTARIOS  dt
    WHERE v.IdVenta = @IdVenta;

    -- RS2: Detalle de productos — cálculos corregidos
    -- PrecioUnidad ya incluye IVA, por eso:
    --   ImporteTotal  = Cantidad * PrecioUnidad          (total con IVA)
    --   ImporteSinIva = ImporteTotal / (1 + IVA%)        (base sin IVA)
    SELECT
        dv.IdDetalleVenta,
        dv.IdProducto,
        p.Codigo        AS CodigoProducto,
        p.Nombre        AS NombreProducto,
        dv.Cantidad,
        dv.PrecioUnidad,
        dv.IvaPorcentaje,
        dv.MontoIva,
        -- Total de línea con IVA incluido (usa PrecioUnidad que ya tiene IVA)
        dv.Cantidad * dv.PrecioUnidad                                       AS ImporteTotal,
        -- Base gravada sin IVA
        CASE
            WHEN dv.IvaPorcentaje = 10
                THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.10 AS DECIMAL(18,2))
            WHEN dv.IvaPorcentaje = 5
                THEN CAST(dv.Cantidad * dv.PrecioUnidad / 1.05 AS DECIMAL(18,2))
            ELSE dv.Cantidad * dv.PrecioUnidad
        END                                                                 AS ImporteSinIva,
        -- Alias para compatibilidad con el modelo C#
        dv.Cantidad * dv.PrecioUnidad                                       AS ImporteTotalIvaIncluido
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dv.IdProducto
    WHERE dv.IdVenta = @IdVenta AND dv.Activo = 1;
END
GO
PRINT 'OK: usp_ObtenerDetalleVenta_v2 corregido (IVA doble eliminado del RS2).';
GO

-- ════════════════════════════════════════════════════════════
-- B) usp_RegistrarVentaDirecta — corregir almacenamiento
--    (solo la parte de ImporteTotal y TotalCosto)
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarVentaDirecta]
    @IdTienda        INT,
    @IdUsuario       INT,
    @IdCliente       INT,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @DetalleXml      XML,
    @IdVentaGenerada INT           OUTPUT,
    @NumeroFactura   VARCHAR(20)   OUTPUT,
    @Resultado       BIT           OUTPUT,
    @Mensaje         NVARCHAR(400) OUTPUT
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

        -- Calcular totales desde XML
        -- PrecioUnidad YA INCLUYE IVA → no multiplicar por (1 + IVA%)
        DECLARE @TotalCosto   DECIMAL(18,2),
                @IVA10Total   DECIMAL(18,2),
                @IVA5Total    DECIMAL(18,2),
                @Exento0Total DECIMAL(18,2);

        SELECT
            -- Total = suma de (Cantidad * PrecioUnidad) — sin agregar IVA de nuevo
            @TotalCosto = SUM(
                n.value('(Cantidad)[1]',    'INT')
                * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
            ),
            -- IVA extraído del precio que ya lo incluye: Total * IVA% / (100 + IVA%)
            @IVA10Total = SUM(CASE
                WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                THEN n.value('(Cantidad)[1]','INT')
                     * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 10.0 / 110.0
                ELSE 0 END),
            @IVA5Total  = SUM(CASE
                WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                THEN n.value('(Cantidad)[1]','INT')
                     * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)') * 5.0 / 105.0
                ELSE 0 END),
            @Exento0Total = SUM(CASE
                WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                THEN n.value('(Cantidad)[1]','INT')
                     * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                ELSE 0 END)
        FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n);

        -- Validar importe recibido
        IF @ImporteRecibido < @TotalCosto
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El importe recibido es menor al total (' + CAST(@TotalCosto AS VARCHAR) + ').';
            ROLLBACK; RETURN;
        END

        -- Generar número de factura
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

        -- Validar stock antes de insertar
        IF EXISTS (
            SELECT 1
            FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
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

        -- Insertar VENTA
        INSERT INTO dbo.VENTA
            (ValorCodigo, Codigo, NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             IdTienda, IdUsuario, IdCliente, IdFormaCobro, TipoFlujo, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, Estado, FechaRegistro,
             IVA10, IVA5, Exento0)
        VALUES
            (@ValorCodigo, @Codigo, @NumeroFactura, @Timbrado, @VencTimbrado,
             @IdTienda, @IdUsuario, @IdCliente, @IdFormaCobro, 'Directa', 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, 'Activa', GETDATE(),
             @IVA10Total, @IVA5Total, @Exento0Total);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        -- Insertar DETALLE_VENTA
        -- ImporteTotal = Cantidad * PrecioUnidad (precio ya incluye IVA, no agregar de nuevo)
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva)
        SELECT
            @IdVentaGenerada,
            n.value('(IdProducto)[1]',    'INT'),
            n.value('(Cantidad)[1]',      'INT'),
            n.value('(PrecioUnidad)[1]',  'DECIMAL(18,2)'),
            -- Total de línea = Cantidad * PrecioUnidad (sin agregar IVA de nuevo)
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)'),
            1, GETDATE(),
            n.value('(IvaPorcentaje)[1]', 'DECIMAL(5,2)'),
            -- IVA extraído del precio que ya lo incluye
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
            SELECT
                n.value('(IdProducto)[1]','INT') AS IdProducto,
                n.value('(Cantidad)[1]',   'INT') AS Cantidad
            FROM @DetalleXml.nodes('/DETALLE/PRODUCTO') AS t(n)
        ) d ON d.IdProducto = pt.IdProducto AND pt.IdTienda = @IdTienda;

        -- Registrar comprobante de cobro
        EXEC dbo.usp_RegistrarComprobanteCobro
            @IdVenta      = @IdVentaGenerada,
            @IdFormaCobro = @IdFormaCobro,
            @Monto        = @TotalCosto;

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
PRINT 'OK: usp_RegistrarVentaDirecta corregido (ImporteTotal sin IVA doble).';
GO

PRINT '════ Script 69 completado ════';
GO
