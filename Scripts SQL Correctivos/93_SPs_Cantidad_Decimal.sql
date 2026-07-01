-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 93: Procedimientos almacenados — Cantidad como DECIMAL en el parseo XML
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-29
--
-- DEPENDE DE: script 92 (las columnas Cantidad/Stock ya deben ser DECIMAL(18,3)).
--
-- MOTIVO:
--   Varios SP leen la cantidad del XML con value('(Cantidad)[1]','INT'), lo que
--   trunca decimales aunque la columna ya sea DECIMAL. Este script re-crea esos
--   SP cambiando el parseo a DECIMAL(18,3). Sólo se tocan las líneas de Cantidad;
--   el resto de la lógica (IVA, descuento, totales) queda idéntica.
--
-- SPs actualizados:
--   1. usp_RegistrarOrdenVenta        (versión vigente = la del script 89)
--   2. usp_RegistrarOrdenCompra       (versión vigente = la del script 91b)
--
-- NOTA: usp_FacturarDesdeOrdenVenta (script 89) ya opera sobre d.Cantidad de la
--       tabla (no parsea XML), así que con el script 92 ya soporta decimales: no
--       requiere cambios. Lo mismo aplica a usp_ConfirmarCompraEImpactarStock y
--       usp_RegistrarRecepcionDesdeOC, que suman columnas, no parsean 'INT'.
--
-- ⚠️ Ejecutar DESPUÉS del 92 y con BACKUP hecho.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_RegistrarOrdenVenta  — Cantidad: INT -> DECIMAL(18,3)
--    (basado en la versión del script 89, que aplica PorcentajeDescuento)
-- ════════════════════════════════════════════════════════════════════════════════
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

        -- Totales con descuento. Cantidad ahora DECIMAL(18,3).
        DECLARE @TotalEstimado DECIMAL(18,2),
                @IVA10Total    DECIMAL(18,2),
                @IVA5Total     DECIMAL(18,2),
                @Exento0Total  DECIMAL(18,2);

        SELECT
            @TotalEstimado = SUM(
                n.value('(Cantidad)[1]','DECIMAL(18,3)') *
                ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                      * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
            ),
            @IVA10Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 10
                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)')
                     * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                             * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                     * 10.0/110.0 ELSE 0 END),
            @IVA5Total  = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 5
                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)')
                     * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                             * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2)
                     * 5.0/105.0 ELSE 0 END),
            @Exento0Total = SUM(CASE WHEN n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') = 0
                THEN n.value('(Cantidad)[1]','DECIMAL(18,3)')
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

        INSERT INTO dbo.DETALLE_ORDEN_VENTA
            (IdOrdenVenta, IdProducto, Cantidad, PrecioUnidad, IvaPorcentaje,
             TotalLinea, TotalLineaIva, PorcentajeDescuento)
        SELECT
            @IdOVGenerada,
            n.value('(IdProducto)[1]',    'INT'),
            n.value('(Cantidad)[1]',      'DECIMAL(18,3)'),
            n.value('(PrecioUnidad)[1]',  'DECIMAL(18,2)'),
            n.value('(IvaPorcentaje)[1]', 'DECIMAL(5,2)'),
            n.value('(Cantidad)[1]','DECIMAL(18,3)')
                * ROUND(n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                        * (1.0 - ISNULL(n.value('(PorcentajeDescuento)[1]','DECIMAL(5,2)'),0)/100.0), 2),
            n.value('(Cantidad)[1]','DECIMAL(18,3)')
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
PRINT 'OK: usp_RegistrarOrdenVenta — Cantidad ahora DECIMAL(18,3).';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_RegistrarOrdenCompra  — Cantidad: INT -> DECIMAL(18,3)
--    (basado en la versión del script 91b, que persiste FechaTopeEntrega)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarOrdenCompra]
    @Detalle    XML,
    @Resultado  BIT           OUTPUT,
    @Mensaje    NVARCHAR(500) OUTPUT,
    @IdGenerado INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT DMY;

    BEGIN TRY
        DECLARE
            @IdProveedor        INT,
            @IdTienda           INT,
            @IdUsuario          INT,
            @NumeroOrden        NVARCHAR(50),
            @FechaOrden         DATE,
            @FechaEntregaEst    DATE,
            @FechaTopeEntrega   DATE,
            @Observacion        NVARCHAR(500),
            @TotalEstimado      DECIMAL(18,2),
            @TotalEstimadoIva   DECIMAL(18,2),
            @IdCategoriaOC      INT;

        SELECT
            @IdProveedor      = cab.value('(IdProveedor)[1]',           'INT'),
            @IdTienda         = cab.value('(IdTienda)[1]',              'INT'),
            @IdUsuario        = cab.value('(IdUsuario)[1]',             'INT'),
            @NumeroOrden      = cab.value('(NumeroOrden)[1]',           'NVARCHAR(50)'),
            @FechaOrden       = TRY_CAST(cab.value('(FechaOrden)[1]',           'NVARCHAR(20)') AS DATE),
            @FechaEntregaEst  = TRY_CAST(cab.value('(FechaEntregaEstimada)[1]', 'NVARCHAR(20)') AS DATE),
            @FechaTopeEntrega = TRY_CAST(cab.value('(FechaTopeEntrega)[1]',     'NVARCHAR(20)') AS DATE),
            @Observacion      = cab.value('(Observacion)[1]',           'NVARCHAR(500)'),
            @TotalEstimado    = cab.value('(TotalEstimado)[1]',         'DECIMAL(18,2)'),
            @TotalEstimadoIva = cab.value('(TotalEstimadoIva)[1]',     'DECIMAL(18,2)'),
            @IdCategoriaOC    = cab.value('(IdCategoriaOC)[1]',        'INT')
        FROM @Detalle.nodes('/OrdenCompra') AS T(cab);

        IF @IdProveedor IS NULL OR @IdTienda IS NULL OR @IdUsuario IS NULL
        BEGIN
            SET @Resultado = 0; SET @IdGenerado = 0;
            SET @Mensaje = 'Datos incompletos: Proveedor, Tienda o Usuario requeridos.';
            RETURN;
        END

        IF @NumeroOrden IS NULL OR LTRIM(RTRIM(@NumeroOrden)) = ''
        BEGIN
            DECLARE @Siguiente INT;
            SELECT @Siguiente = ISNULL(MAX(IdOrdenCompra), 0) + 1 FROM dbo.OrdenCompra;
            SET @NumeroOrden = 'OC-' + FORMAT(GETDATE(), 'yyyyMM') + '-'
                + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)), 4);
        END

        -- Control de tope diario global
        DECLARE @TopeDiario DECIMAL(18,2), @AcumuladoHoy DECIMAL(18,2);
        SELECT @TopeDiario = TRY_CAST(Valor AS DECIMAL(18,2))
          FROM dbo.PARAMETRO_SISTEMA WHERE Clave = 'TopeDiarioCompras';
        IF @TopeDiario IS NULL OR @TopeDiario <= 0 SET @TopeDiario = 2000000;

        SELECT @AcumuladoHoy = ISNULL(SUM(TotalEstimado), 0)
          FROM dbo.OrdenCompra
         WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
           AND Estado NOT IN ('Anulada', 'Rechazada');

        IF (@AcumuladoHoy + @TotalEstimado) > @TopeDiario
        BEGIN
            SET @Resultado  = 0; SET @IdGenerado = 0;
            SET @Mensaje    = 'Tope diario de compras superado. '
                + 'Límite: Gs. '        + FORMAT(@TopeDiario,   'N0', 'es-PY') + ' | '
                + 'Acumulado hoy: Gs. ' + FORMAT(@AcumuladoHoy, 'N0', 'es-PY') + ' | '
                + 'Esta OC: Gs. '       + FORMAT(@TotalEstimado,'N0', 'es-PY') + '.';
            RETURN;
        END

        BEGIN TRAN;

        INSERT INTO dbo.OrdenCompra
            (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
             FechaOrden, FechaEntregaEstimada, FechaTopeEntrega, Observacion,
             TotalEstimado, TotalEstimadoIva,
             Estado, MotivoRechazo, Activo, FechaRegistro)
        VALUES
            (@NumeroOrden, @IdProveedor, @IdTienda, @IdUsuario, NULL,
             ISNULL(@FechaOrden, GETDATE()), @FechaEntregaEst, @FechaTopeEntrega, @Observacion,
             @TotalEstimado, @TotalEstimadoIva,
             'Pendiente', NULL, 1, GETDATE());

        SET @IdGenerado = SCOPE_IDENTITY();

        -- Detalle: Cantidad ahora DECIMAL(18,3)
        INSERT INTO dbo.DetalleOrdenCompra
            (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
             PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
             Activo, FechaRegistro)
        SELECT
            @IdGenerado,
            item.value('(IdProducto)[1]',    'INT'),
            item.value('(Cantidad)[1]',       'DECIMAL(18,3)'),
            0,
            item.value('(PrecioUnitario)[1]', 'DECIMAL(18,2)'),
            item.value('(IvaPorcentaje)[1]',  'DECIMAL(5,2)'),
            item.value('(TotalLinea)[1]',     'DECIMAL(18,2)'),
            item.value('(TotalLineaIva)[1]',  'DECIMAL(18,2)'),
            1,
            GETDATE()
        FROM @Detalle.nodes('/OrdenCompra/Detalle/Item') AS T(item);

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Orden de Compra registrada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado  = 0; SET @IdGenerado = 0;
        SET @Mensaje    = 'Error al registrar la Orden de Compra: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarOrdenCompra — Cantidad ahora DECIMAL(18,3).';
GO

-- ─── Verificación opcional ───────────────────────────────────────────────────
-- Buscar SP que TODAVÍA parseen Cantidad como INT (revisar si quedó alguno activo):
SELECT o.name AS Procedimiento
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
WHERE m.definition LIKE '%(Cantidad)[1]%INT%'
ORDER BY o.name;
GO

PRINT '════ Script 93 completado ════';
GO
