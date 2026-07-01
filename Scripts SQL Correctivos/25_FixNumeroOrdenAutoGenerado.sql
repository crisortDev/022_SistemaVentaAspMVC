-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 25: Corregir usp_RegistrarOrdenCompra — NumeroOrden auto-generado
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Problema: el SP intentaba insertar @NumeroOrden NULL cuando el controller
--           no la envía en el XML.
-- Solución: si NumeroOrden no viene en el XML, el SP la genera como
--           OC-YYYYMM-NNNN (año-mes + correlativo basado en IdOrdenCompra).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

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

        -- ── Extraer cabecera del XML ──────────────────────────────────────────
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
            @IdProveedor      = cab.value('(IdProveedor)[1]',             'INT'),
            @IdTienda         = cab.value('(IdTienda)[1]',                'INT'),
            @IdUsuario        = cab.value('(IdUsuario)[1]',               'INT'),
            @NumeroOrden      = cab.value('(NumeroOrden)[1]',             'NVARCHAR(50)'),
            @FechaOrden       = TRY_CAST(cab.value('(FechaOrden)[1]',               'NVARCHAR(20)') AS DATE),
            @FechaEntregaEst  = TRY_CAST(cab.value('(FechaEntregaEstimada)[1]',     'NVARCHAR(20)') AS DATE),
            @FechaTopeEntrega = TRY_CAST(cab.value('(FechaTopeEntrega)[1]',         'NVARCHAR(20)') AS DATE),
            @Observacion      = cab.value('(Observacion)[1]',             'NVARCHAR(500)'),
            @TotalEstimado    = cab.value('(TotalEstimado)[1]',           'DECIMAL(18,2)'),
            @TotalEstimadoIva = cab.value('(TotalEstimadoIva)[1]',       'DECIMAL(18,2)'),
            @IdCategoriaOC    = cab.value('(IdCategoriaOC)[1]',          'INT')
        FROM @Detalle.nodes('/OrdenCompra') AS T(cab);

        -- ── Validaciones básicas ──────────────────────────────────────────────
        IF @IdProveedor IS NULL OR @IdTienda IS NULL OR @IdUsuario IS NULL
        BEGIN
            SET @Resultado = 0; SET @IdGenerado = 0;
            SET @Mensaje = 'Datos incompletos: Proveedor, Tienda o Usuario requeridos.';
            RETURN;
        END

        -- ── Auto-generar NumeroOrden si no viene en el XML ────────────────────
        IF @NumeroOrden IS NULL OR LTRIM(RTRIM(@NumeroOrden)) = ''
        BEGIN
            DECLARE @Siguiente INT;
            SELECT @Siguiente = ISNULL(MAX(IdOrdenCompra), 0) + 1
              FROM dbo.OrdenCompra;

            SET @NumeroOrden = 'OC-'
                + FORMAT(GETDATE(), 'yyyyMM')
                + '-'
                + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)), 4);
        END

        -- ── Control de tope diario global ─────────────────────────────────────
        DECLARE @TopeDiario    DECIMAL(18,2),
                @AcumuladoHoy  DECIMAL(18,2);

        SELECT @TopeDiario = TRY_CAST(Valor AS DECIMAL(18,2))
          FROM dbo.PARAMETRO_SISTEMA
         WHERE Clave = 'TopeDiarioCompras';

        IF @TopeDiario IS NULL OR @TopeDiario <= 0 SET @TopeDiario = 2000000;

        SELECT @AcumuladoHoy = ISNULL(SUM(TotalEstimado), 0)
          FROM dbo.OrdenCompra
         WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
           AND Estado NOT IN ('Anulada', 'Rechazada');

        IF (@AcumuladoHoy + @TotalEstimado) > @TopeDiario
        BEGIN
            SET @Resultado  = 0;
            SET @IdGenerado = 0;
            SET @Mensaje    = 'Tope diario de compras superado. '
                + 'Límite: Gs. '        + FORMAT(@TopeDiario,   'N0', 'es-PY') + ' | '
                + 'Acumulado hoy: Gs. ' + FORMAT(@AcumuladoHoy, 'N0', 'es-PY') + ' | '
                + 'Esta OC: Gs. '       + FORMAT(@TotalEstimado,'N0', 'es-PY') + '. '
                + 'Para modificar el límite actualice PARAMETRO_SISTEMA (TopeDiarioCompras).';
            RETURN;
        END

        -- ── Insertar OrdenCompra ──────────────────────────────────────────────
        BEGIN TRAN;

        INSERT INTO dbo.OrdenCompra
            (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
             FechaOrden, FechaEntregaEstimada, Observacion,
             TotalEstimado, TotalEstimadoIva,
             Estado, MotivoRechazo, Activo, FechaRegistro)
        VALUES
            (@NumeroOrden, @IdProveedor, @IdTienda, @IdUsuario, NULL,
             ISNULL(@FechaOrden, GETDATE()), @FechaEntregaEst, @Observacion,
             @TotalEstimado, @TotalEstimadoIva,
             'Pendiente', NULL, 1, GETDATE());

        SET @IdGenerado = SCOPE_IDENTITY();

        -- ── Insertar detalle ──────────────────────────────────────────────────
        INSERT INTO dbo.DetalleOrdenCompra
            (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
             PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
             Activo, FechaRegistro)
        SELECT
            @IdGenerado,
            item.value('(IdProducto)[1]',    'INT'),
            item.value('(Cantidad)[1]',       'INT'),
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
        SET @Resultado  = 0;
        SET @IdGenerado = 0;
        SET @Mensaje    = 'Error al registrar la Orden de Compra: ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT 'OK: usp_RegistrarOrdenCompra corregido — NumeroOrden se auto-genera si no viene en el XML (OC-YYYYMM-NNNN)'
