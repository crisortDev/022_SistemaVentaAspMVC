-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 42: Corregir usp_RegistrarOrdenVenta
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-12
--
-- Problemas detectados:
--   1. Parámetro @Detalle (NVARCHAR) declarado pero nunca enviado por C#
--      → SQL Server falla: "expects parameter '@Detalle', which was not supplied"
--   2. XPath '/DETALLE/PRODUCTO' no coincide con el XML enviado por JS:
--      <Detalle><Item>...</Item></Detalle>
--      XML es case-sensitive → los nodos nunca se encuentran
--
-- Solución: Eliminar @Detalle, cambiar XPath a /Detalle/Item
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

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

        -- ── Validaciones básicas ──────────────────────────────────────────────
        IF @IdTienda IS NULL OR @IdTienda = 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Tienda no especificada.';
            ROLLBACK; RETURN;
        END

        IF @FechaVencimiento < CAST(GETDATE() AS DATE)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'La fecha de vencimiento no puede ser anterior a hoy.';
            ROLLBACK; RETURN;
        END

        -- ── Validar que el XML tiene al menos un Item ─────────────────────────
        -- JS genera: <Detalle><Item><IdProducto>...<Cantidad>...<PrecioUnidad>...<IvaPorcentaje>...</Item></Detalle>
        IF (SELECT COUNT(*) FROM @DetalleXml.nodes('/Detalle/Item') AS t(n)) = 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Debe incluir al menos un producto.';
            ROLLBACK; RETURN;
        END

        -- ── Calcular totales desde el XML ─────────────────────────────────────
        DECLARE @TotalEstimado DECIMAL(18,2) = 0,
                @IVA10Total    DECIMAL(18,2) = 0,
                @IVA5Total     DECIMAL(18,2) = 0,
                @Exento0Total  DECIMAL(18,2) = 0;

        SELECT
            @TotalEstimado = SUM(
                n.value('(Cantidad)[1]',       'INT') *
                n.value('(PrecioUnidad)[1]',   'DECIMAL(18,2)')
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
        FROM @DetalleXml.nodes('/Detalle/Item') AS t(n);

        -- ── Número correlativo OV ─────────────────────────────────────────────
        DECLARE @Correlativo INT = ISNULL((SELECT MAX(IdOrdenVenta) FROM dbo.ORDEN_VENTA), 0) + 1;
        DECLARE @NumeroOV VARCHAR(20) = 'OV-' + RIGHT('00000000' + CAST(@Correlativo AS VARCHAR), 8);

        -- ── Insertar cabecera ─────────────────────────────────────────────────
        INSERT INTO dbo.ORDEN_VENTA
            (NumeroOV, IdTienda, IdCliente, IdUsuarioRegistro, TotalEstimado,
             IVA10, IVA5, Exento0, Estado, Observacion, FechaVencimiento, Activo)
        VALUES
            (@NumeroOV, @IdTienda, NULLIF(@IdCliente, 0), @IdUsuarioRegistro,
             ISNULL(@TotalEstimado, 0), ISNULL(@IVA10Total, 0),
             ISNULL(@IVA5Total, 0), ISNULL(@Exento0Total, 0),
             'Pendiente', @Observacion, @FechaVencimiento, 1);

        SET @IdOVGenerada = SCOPE_IDENTITY();

        -- ── Insertar detalle ──────────────────────────────────────────────────
        INSERT INTO dbo.DETALLE_ORDEN_VENTA
            (IdOrdenVenta, IdProducto, Cantidad, PrecioUnidad, IvaPorcentaje, TotalLinea, TotalLineaIva)
        SELECT
            @IdOVGenerada,
            n.value('(IdProducto)[1]',    'INT'),
            n.value('(Cantidad)[1]',      'INT'),
            n.value('(PrecioUnidad)[1]',  'DECIMAL(18,2)'),
            n.value('(IvaPorcentaje)[1]', 'DECIMAL(5,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)'),
            n.value('(Cantidad)[1]','INT') * n.value('(PrecioUnidad)[1]','DECIMAL(18,2)')
                * (1 + n.value('(IvaPorcentaje)[1]','DECIMAL(5,2)') / 100.0)
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

PRINT 'OK: usp_RegistrarOrdenVenta corregido (XPath /Detalle/Item, sin @Detalle).';
GO
