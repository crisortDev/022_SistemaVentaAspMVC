-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 91b: Agregar FechaTopeEntrega en OrdenCompra + actualizar SPs
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-27
--
-- Problema: usp_ObtenerDetalleOrdenCompra (script 91) fallaba con
--   Msg 207 "Invalid column name 'FechaTopeEntrega'" porque:
--   - La columna fue leída del XML en usp_RegistrarOrdenCompra pero NUNCA
--     se guardó en la tabla OrdenCompra.
--
-- Este script:
--   1. Agrega FechaTopeEntrega DATE NULL a OrdenCompra (idempotente)
--   2. Actualiza usp_RegistrarOrdenCompra para persistirla
--   3. Re-crea usp_ObtenerDetalleOrdenCompra (ahora sin error de columna)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Agregar columna FechaTopeEntrega ─────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.OrdenCompra') AND name = 'FechaTopeEntrega'
)
    ALTER TABLE dbo.OrdenCompra ADD FechaTopeEntrega DATE NULL;

PRINT 'OK: OrdenCompra.FechaTopeEntrega asegurada.';
GO

-- ─── 2. usp_RegistrarOrdenCompra — persistir FechaTopeEntrega ────────────────
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
             FechaOrden, FechaEntregaEstimada, FechaTopeEntrega, Observacion,
             TotalEstimado, TotalEstimadoIva,
             Estado, MotivoRechazo, Activo, FechaRegistro)
        VALUES
            (@NumeroOrden, @IdProveedor, @IdTienda, @IdUsuario, NULL,
             ISNULL(@FechaOrden, GETDATE()), @FechaEntregaEst, @FechaTopeEntrega, @Observacion,
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
PRINT 'OK: usp_RegistrarOrdenCompra — ahora persiste FechaTopeEntrega.';
GO

-- ─── 3. usp_ObtenerDetalleOrdenCompra — ahora FechaTopeEntrega existe ─────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleOrdenCompra]
    @IdOrdenCompra INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        oc.IdOrdenCompra,
        oc.NumeroOrden,
        CONVERT(VARCHAR(10), oc.FechaOrden,           103)     AS FechaOrden,
        CONVERT(VARCHAR(10), oc.FechaEntregaEstimada,  103)    AS FechaEntregaEstimada,
        CONVERT(VARCHAR(10), oc.FechaTopeEntrega,      103)    AS FechaTopeEntrega,
        ISNULL(oc.Observacion, '')                              AS Observacion,
        oc.TotalEstimado,
        oc.TotalEstimadoIva,
        oc.Estado,
        CONVERT(VARCHAR(10), oc.FechaAprobacion, 103)          AS FechaAprobacion,
        ISNULL(oc.MotivoRechazo, '')                            AS MotivoRechazo,

        -- ── Proveedor ──────────────────────────────────────────────────
        (SELECT
            pr.IdProveedor                                      AS [IdProveedor],
            pr.RUC                                              AS [RUC],
            pr.RazonSocial                                      AS [RazonSocial],
            ISNULL(pr.Telefono,  '')                            AS [Telefono],
            ISNULL(pr.Correo,    '')                            AS [Correo],
            ISNULL(pr.Direccion, '')                            AS [Direccion]
         FROM dbo.PROVEEDOR pr
         WHERE pr.IdProveedor = oc.IdProveedor
         FOR XML PATH('DETALLE_PROVEEDOR'), TYPE),

        -- ── Tienda ─────────────────────────────────────────────────────
        (SELECT
            t.IdTienda                                          AS [IdTienda],
            t.RUC                                              AS [RUC],
            t.Nombre                                           AS [Nombre],
            ISNULL(t.Direccion, '')                            AS [Direccion]
         FROM dbo.TIENDA t
         WHERE t.IdTienda = oc.IdTienda
         FOR XML PATH('DETALLE_TIENDA'), TYPE),

        -- ── Usuario que registró ────────────────────────────────────────
        (SELECT
            u.IdUsuario                                         AS [IdUsuario],
            u.Nombres                                           AS [Nombres],
            u.Apellidos                                         AS [Apellidos]
         FROM dbo.USUARIO u
         WHERE u.IdUsuario = oc.IdUsuarioRegistro
         FOR XML PATH('DETALLE_USUARIO'), TYPE),

        -- ── Líneas de producto ─────────────────────────────────────────
        (SELECT
            doc.IdDetalleOrdenCompra                           AS [IdDetalleOrdenCompra],
            doc.IdProducto                                     AS [IdProducto],
            p.Codigo                                           AS [CodigoProducto],
            p.Nombre                                           AS [NombreProducto],
            ISNULL(p.UnidadMedida, 'Unidad')                   AS [UnidadMedida],
            doc.Cantidad                                       AS [Cantidad],
            ISNULL(doc.CantidadFacturada, 0)                   AS [CantidadFacturada],
            doc.PrecioUnitario                                 AS [PrecioUnitario],
            doc.IvaPorcentaje                                  AS [IvaPorcentaje],
            doc.TotalLinea                                     AS [TotalLinea],
            doc.TotalLineaIva                                  AS [TotalLineaIva]
         FROM dbo.DetalleOrdenCompra doc
         INNER JOIN dbo.PRODUCTO p ON p.IdProducto = doc.IdProducto
         WHERE doc.IdOrdenCompra = oc.IdOrdenCompra
           AND doc.Activo = 1
         ORDER BY doc.IdDetalleOrdenCompra
         FOR XML PATH('PRODUCTO'), ROOT('DETALLE_PRODUCTO'), TYPE)

    FROM dbo.OrdenCompra oc
    WHERE oc.IdOrdenCompra = @IdOrdenCompra
    FOR XML PATH('DETALLE_ORDEN_COMPRA');
END
GO
PRINT 'OK: usp_ObtenerDetalleOrdenCompra — UnidadMedida + FechaTopeEntrega correctos.';
GO

-- ─── Verificación ──────────────────────────────────────────────────────────────
SELECT name AS Columna, TYPE_NAME(system_type_id) AS Tipo, is_nullable
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.OrdenCompra')
  AND name = 'FechaTopeEntrega';

PRINT '════ Script 91b completado ════';
GO
