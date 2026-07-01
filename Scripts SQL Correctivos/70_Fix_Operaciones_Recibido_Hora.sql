-- ============================================================
-- Script 70: Fix MontoRecibido/MontoCambio = 0 y formato Hora
-- Fecha: 2026-05-19
--
-- PROBLEMA 1 — MontoRecibido y MontoCambio en 0:
--   Script 69 reemplazó el INSERT directo a COMPROBANTE_COBRO
--   por EXEC usp_RegistrarComprobanteCobro que solo recibía @Monto.
--   Fix: volver al INSERT directo con todos los campos.
--
-- PROBLEMA 2 — "ed:ed" en columna Hora:
--   usp_ObtenerOperacionesCaja devuelve FechaRegistro como DATETIME.
--   El serializador JSON de .NET lo convierte a /Date(ticks)/ y la
--   función JS formatFechaHora falla al parsear ese formato.
--   Fix: formatear FechaRegistro como VARCHAR en el SP.
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
-- 1. usp_RegistrarVentaDirecta — INSERT correcto a COMPROBANTE_COBRO
--    (incluye MontoRecibido y MontoCambio)
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
             IVA10, IVA5, Exento0)
        VALUES
            (@ValorCodigo, @Codigo, @NumeroFactura, @Timbrado, @VencTimbrado,
             @IdTienda, @IdUsuario, @IdCliente, @IdFormaCobro, 'Directa', 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, 'Activa', GETDATE(),
             @IVA10Total, @IVA5Total, @Exento0Total);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        -- DETALLE (PrecioUnidad ya incluye IVA, no multiplicar por 1+IVA%)
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

        -- COMPROBANTE_COBRO con MontoRecibido y MontoCambio correctos
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
PRINT 'OK: usp_RegistrarVentaDirecta — MontoRecibido y MontoCambio corregidos.';
GO

-- ════════════════════════════════════════════════════════════
-- 2. usp_ObtenerOperacionesCaja — FechaRegistro como VARCHAR
--    para evitar el formato /Date(ticks)/ que rompe el JS
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

    -- RS1: Detalle operación por operación
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        -- Formato ISO para que el JS lo parsee correctamente (evita /Date(ticks)/)
        CONVERT(VARCHAR(19), v.FechaRegistro, 120)    AS FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')           AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        v.TotalCosto                                   AS Monto,
        ISNULL(cc.MontoRecibido, 0)                    AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                    AS MontoCambio,
        u.Nombres + ' ' + u.Apellidos                  AS NombreCajero,
        v.Estado
    FROM   dbo.VENTA             v
    INNER  JOIN dbo.USUARIO      u  ON u.IdUsuario    = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE      c  ON c.IdCliente    = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- RS2: Resumen por forma de cobro
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo')) AS FormaCobro,
        COUNT(v.IdVenta)  AS Cantidad,
        SUM(v.TotalCosto) AS TotalMonto
    FROM   dbo.VENTA             v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta    = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro    = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado = 'Activa'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja — FechaRegistro en formato ISO yyyy-MM-dd HH:mm:ss.';
GO

PRINT '════ Script 70 completado ════';
GO
