-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 18: Tope Diario de Compras — Global (todas las sucursales y roles)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-06
--
-- Qué hace:
--   1. Crea tabla PARAMETRO_SISTEMA para almacenar parámetros configurables
--   2. Inserta el parámetro TopeDiarioCompras = 2.000.000 Gs.
--   3. Altera usp_RegistrarOrdenCompra  → valida tope antes de crear la OC
--   4. Altera usp_RegistrarRecepcionDesdeOC → valida tope antes de registrar factura
--
-- Lógica del control:
--   • Al crear una OC: suma el TotalEstimado de todas las OC del día
--     (Estado <> 'Anulada' y <> 'Rechazada') + el monto de la nueva OC.
--     Si supera el tope → rechaza con mensaje claro.
--   • Al registrar una Recepción: suma el TotalCosto de todas las COMPRA
--     del día (Estado <> 'Anulada') + el monto de la nueva factura.
--     Si supera el tope → rechaza con mensaje claro.
--
-- El tope es GLOBAL: aplica a todas las sucursales y todos los roles.
-- Para modificar el tope: UPDATE PARAMETRO_SISTEMA SET Valor = '3000000'
--                         WHERE Clave = 'TopeDiarioCompras'
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: Crear tabla PARAMETRO_SISTEMA
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 1: Crear tabla PARAMETRO_SISTEMA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = 'PARAMETRO_SISTEMA' AND type = 'U')
BEGIN
    CREATE TABLE dbo.PARAMETRO_SISTEMA (
        IdParametro     INT           NOT NULL IDENTITY(1,1) CONSTRAINT PK_ParamSist PRIMARY KEY,
        Clave           VARCHAR(100)  NOT NULL CONSTRAINT UQ_ParamSist_Clave UNIQUE,
        Valor           VARCHAR(500)  NOT NULL,
        Descripcion     NVARCHAR(300) NULL,
        FechaModificacion DATETIME    NOT NULL CONSTRAINT DF_ParamSist_Fecha DEFAULT GETDATE()
    );
    PRINT '  OK: tabla PARAMETRO_SISTEMA creada';
END
ELSE
    PRINT '  SKIP: tabla PARAMETRO_SISTEMA ya existe';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: Insertar / actualizar parámetro TopeDiarioCompras
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 2: Insertar parámetro TopeDiarioCompras ━━━━━━━━━━━━━━━━━━━━━━━━━━'

IF NOT EXISTS (SELECT 1 FROM dbo.PARAMETRO_SISTEMA WHERE Clave = 'TopeDiarioCompras')
BEGIN
    INSERT INTO dbo.PARAMETRO_SISTEMA (Clave, Valor, Descripcion)
    VALUES (
        'TopeDiarioCompras',
        '2000000',
        'Monto máximo acumulado de compras por día en guaraníes. Aplica a todas las sucursales y roles. Modificar el Valor para cambiar el límite.'
    );
    PRINT '  OK: TopeDiarioCompras = 2.000.000 Gs. insertado';
END
ELSE
BEGIN
    UPDATE dbo.PARAMETRO_SISTEMA
       SET Valor = '2000000', FechaModificacion = GETDATE()
     WHERE Clave = 'TopeDiarioCompras';
    PRINT '  OK: TopeDiarioCompras actualizado a 2.000.000 Gs.';
END
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3: Verificar parámetro
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 3: Verificar parámetros ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
SELECT Clave, Valor, Descripcion, FechaModificacion FROM dbo.PARAMETRO_SISTEMA;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 4: Alterar usp_RegistrarOrdenCompra
--         Agrega validación de tope diario ANTES del INSERT
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 4: Alterar usp_RegistrarOrdenCompra ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
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
            @IdProveedor      = cab.value('(IdProveedor)[1]',      'INT'),
            @IdTienda         = cab.value('(IdTienda)[1]',         'INT'),
            @IdUsuario        = cab.value('(IdUsuario)[1]',        'INT'),
            @NumeroOrden      = cab.value('(NumeroOrden)[1]',      'NVARCHAR(50)'),
            @FechaOrden       = TRY_CAST(cab.value('(FechaOrden)[1]',    'NVARCHAR(20)') AS DATE),
            @FechaEntregaEst  = TRY_CAST(cab.value('(FechaEntregaEstimada)[1]', 'NVARCHAR(20)') AS DATE),
            @FechaTopeEntrega = TRY_CAST(cab.value('(FechaTopeEntrega)[1]',     'NVARCHAR(20)') AS DATE),
            @Observacion      = cab.value('(Observacion)[1]',      'NVARCHAR(500)'),
            @TotalEstimado    = cab.value('(TotalEstimado)[1]',    'DECIMAL(18,2)'),
            @TotalEstimadoIva = cab.value('(TotalEstimadoIva)[1]','DECIMAL(18,2)'),
            @IdCategoriaOC    = cab.value('(IdCategoriaOC)[1]',   'INT')
        FROM @Detalle.nodes('/OrdenCompra') AS T(cab);

        -- ── Validaciones básicas ──────────────────────────────────────────────
        IF @IdProveedor IS NULL OR @IdTienda IS NULL OR @IdUsuario IS NULL
        BEGIN
            SET @Resultado = 0; SET @IdGenerado = 0;
            SET @Mensaje = 'Datos incompletos: Proveedor, Tienda o Usuario requeridos.';
            RETURN;
        END

        -- ── Control de tope diario global ─────────────────────────────────────
        DECLARE @TopeDiario    DECIMAL(18,2),
                @AcumuladoHoy  DECIMAL(18,2);

        -- Leer tope desde PARAMETRO_SISTEMA
        SELECT @TopeDiario = TRY_CAST(Valor AS DECIMAL(18,2))
          FROM dbo.PARAMETRO_SISTEMA
         WHERE Clave = 'TopeDiarioCompras';

        -- Fallback si no existe el parámetro
        IF @TopeDiario IS NULL OR @TopeDiario <= 0 SET @TopeDiario = 2000000;

        -- Sumar OC del día de hoy (excluye Anuladas y Rechazadas)
        SELECT @AcumuladoHoy = ISNULL(SUM(TotalEstimado), 0)
          FROM dbo.OrdenCompra
         WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
           AND Estado NOT IN ('Anulada', 'Rechazada');

        IF (@AcumuladoHoy + @TotalEstimado) > @TopeDiario
        BEGIN
            SET @Resultado  = 0;
            SET @IdGenerado = 0;
            SET @Mensaje    = 'Tope diario de compras superado. '
                + 'Límite: Gs. '     + FORMAT(@TopeDiario,   'N0', 'es-PY') + ' | '
                + 'Acumulado hoy: Gs. ' + FORMAT(@AcumuladoHoy, 'N0', 'es-PY') + ' | '
                + 'Esta OC: Gs. '    + FORMAT(@TotalEstimado, 'N0', 'es-PY') + '. '
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
            item.value('(IdProducto)[1]',     'INT'),
            item.value('(Cantidad)[1]',        'INT'),
            0,
            item.value('(PrecioUnitario)[1]',  'DECIMAL(18,2)'),
            item.value('(IvaPorcentaje)[1]',   'DECIMAL(5,2)'),
            item.value('(TotalLinea)[1]',      'DECIMAL(18,2)'),
            item.value('(TotalLineaIva)[1]',   'DECIMAL(18,2)'),
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
PRINT '  OK: usp_RegistrarOrdenCompra actualizado con control de tope diario'
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 5: Alterar usp_RegistrarRecepcionDesdeOC
--         Agrega validación de tope diario ANTES del INSERT de COMPRA
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 5: Alterar usp_RegistrarRecepcionDesdeOC ━━━━━━━━━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarRecepcionDesdeOC]
    @IdOrdenCompra         INT,
    @IdUsuario             INT,
    @NumeroFactura         NVARCHAR(50),
    @NumeroTimbrado        NVARCHAR(50),
    @FechaVencTimbrado     DATE,
    @FechaFactura          DATE,
    @FechaEntrega          DATETIME,
    @Detalle               XML,
    @IdCompra              INT           OUTPUT,
    @Resultado             BIT           OUTPUT,
    @Mensaje               NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT YMD;

    BEGIN TRY
        BEGIN TRAN;

        -- ── 1. Validar OC ─────────────────────────────────────────────────────
        DECLARE @IdProveedor INT, @IdTienda INT, @EstadoOC VARCHAR(20);

        SELECT @IdProveedor = IdProveedor,
               @IdTienda    = IdTienda,
               @EstadoOC    = Estado
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @IdProveedor IS NULL
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'Orden de Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoOC <> 'Aprobada'
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'Solo se puede recepcionar una OC en estado Aprobada. Estado actual: ' + @EstadoOC;
            ROLLBACK; RETURN;
        END

        -- ── 2. Parsear líneas de detalle ──────────────────────────────────────
        DECLARE @Lineas TABLE (
            IdDetalleOC      INT,
            CantidadRecibida INT
        );

        INSERT INTO @Lineas (IdDetalleOC, CantidadRecibida)
        SELECT
            item.value('(IdDetalleOC)[1]',       'INT'),
            item.value('(CantidadRecibida)[1]',   'INT')
        FROM @Detalle.nodes('/DETALLE/ITEM') AS T(item);

        IF NOT EXISTS (SELECT 1 FROM @Lineas)
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'El detalle de recepción está vacío.';
            ROLLBACK; RETURN;
        END

        -- ── 3. Validar que los detalles pertenezcan a la OC ──────────────────
        IF EXISTS (
            SELECT 1 FROM @Lineas l
             WHERE NOT EXISTS (
                SELECT 1 FROM dbo.DetalleOrdenCompra doc
                 WHERE doc.IdDetalleOrdenCompra = l.IdDetalleOC
                   AND doc.IdOrdenCompra = @IdOrdenCompra))
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'Uno o más ítems del detalle no pertenecen a esta Orden de Compra.';
            ROLLBACK; RETURN;
        END

        -- ── 4. Calcular TotalCosto ────────────────────────────────────────────
        DECLARE @TotalCosto DECIMAL(18,2);

        SELECT @TotalCosto = SUM(l.CantidadRecibida * doc.PrecioUnitario)
          FROM @Lineas l
         INNER JOIN dbo.DetalleOrdenCompra doc ON doc.IdDetalleOrdenCompra = l.IdDetalleOC;

        IF ISNULL(@TotalCosto, 0) = 0
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'El total calculado es cero. Verifique las cantidades recibidas.';
            ROLLBACK; RETURN;
        END

        -- ── 5. Control de tope diario global ──────────────────────────────────
        DECLARE @TopeDiario   DECIMAL(18,2),
                @AcumuladoHoy DECIMAL(18,2);

        SELECT @TopeDiario = TRY_CAST(Valor AS DECIMAL(18,2))
          FROM dbo.PARAMETRO_SISTEMA
         WHERE Clave = 'TopeDiarioCompras';

        IF @TopeDiario IS NULL OR @TopeDiario <= 0 SET @TopeDiario = 2000000;

        -- Suma de compras confirmadas y pendientes de hoy (excluye Anuladas)
        SELECT @AcumuladoHoy = ISNULL(SUM(TotalCosto), 0)
          FROM dbo.COMPRA
         WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
           AND Estado <> 'Anulada';

        IF (@AcumuladoHoy + @TotalCosto) > @TopeDiario
        BEGIN
            SET @Resultado = 0;
            SET @IdCompra  = 0;
            SET @Mensaje   = 'Tope diario de compras superado. '
                + 'Límite: Gs. '        + FORMAT(@TopeDiario,   'N0', 'es-PY') + ' | '
                + 'Acumulado hoy: Gs. ' + FORMAT(@AcumuladoHoy, 'N0', 'es-PY') + ' | '
                + 'Esta factura: Gs. '  + FORMAT(@TotalCosto,   'N0', 'es-PY') + '. '
                + 'Contacte al administrador para modificar el límite.';
            ROLLBACK; RETURN;
        END

        -- ── 6. Crear COMPRA ───────────────────────────────────────────────────
        INSERT INTO dbo.COMPRA (
            IdUsuario, IdProveedor, IdTienda, TotalCosto, TipoComprobante,
            Activo, FechaRegistro, NumeroFactura, NumeroTimbrado,
            VencimientoTimbrado, FechaFactura, FechaEntrega,
            EstadoRecepcion, Estado)
        VALUES (
            @IdUsuario, @IdProveedor, @IdTienda, @TotalCosto, 'Compra',
            1, GETDATE(),
            ISNULL(@NumeroFactura,  ''),
            ISNULL(@NumeroTimbrado, ''),
            @FechaVencTimbrado, @FechaFactura, @FechaEntrega,
            'EnRecepcion', 'Pendiente');

        SET @IdCompra = SCOPE_IDENTITY();

        -- ── 7. Crear DETALLE_COMPRA ───────────────────────────────────────────
        INSERT INTO dbo.DETALLE_COMPRA (
            IdCompra, IdProducto, Cantidad, CantidadRecibida,
            PrecioUnitarioCompra, TotalCosto, Activo, FechaRegistro, EstadoLinea)
        SELECT
            @IdCompra,
            doc.IdProducto,
            doc.Cantidad,
            l.CantidadRecibida,
            doc.PrecioUnitario,
            l.CantidadRecibida * doc.PrecioUnitario,
            1,
            GETDATE(),
            CASE
                WHEN l.CantidadRecibida >= doc.Cantidad THEN 'Aceptada'
                WHEN l.CantidadRecibida  > 0            THEN 'NC'
                ELSE 'Rechazada'
            END
          FROM @Lineas l
         INNER JOIN dbo.DetalleOrdenCompra doc ON doc.IdDetalleOrdenCompra = l.IdDetalleOC;

        -- ── 8. Vincular Compra con OC ─────────────────────────────────────────
        INSERT INTO dbo.CompraOrdenCompra (IdCompra, IdOrdenCompra, FechaVinculacion)
        VALUES (@IdCompra, @IdOrdenCompra, GETDATE());

        -- ── 9. Marcar OC como Facturada ───────────────────────────────────────
        UPDATE dbo.OrdenCompra
           SET Estado = 'Facturada'
         WHERE IdOrdenCompra = @IdOrdenCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Recepción registrada correctamente. Compra ID: ' + CAST(@IdCompra AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @IdCompra  = 0;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error al registrar la recepción: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_RegistrarRecepcionDesdeOC actualizado con control de tope diario'
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 6: Verificación final
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 6: Verificación final ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- Tope configurado
SELECT 'Parámetro' AS Tipo, Clave, Valor AS Configurado,
       FORMAT(TRY_CAST(Valor AS DECIMAL(18,2)), 'N0', 'es-PY') + ' Gs.' AS Formateado
  FROM dbo.PARAMETRO_SISTEMA
 WHERE Clave = 'TopeDiarioCompras';

-- Acumulado OC hoy
SELECT 'OC hoy' AS Tipo,
       COUNT(*)          AS CantidadOC,
       SUM(TotalEstimado) AS TotalAcumulado,
       FORMAT(ISNULL(SUM(TotalEstimado),0), 'N0', 'es-PY') + ' Gs.' AS Formateado
  FROM dbo.OrdenCompra
 WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
   AND Estado NOT IN ('Anulada','Rechazada');

-- Acumulado Compras hoy
SELECT 'Compras hoy' AS Tipo,
       COUNT(*)      AS CantidadCompras,
       SUM(TotalCosto) AS TotalAcumulado,
       FORMAT(ISNULL(SUM(TotalCosto),0), 'N0', 'es-PY') + ' Gs.' AS Formateado
  FROM dbo.COMPRA
 WHERE CAST(FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
   AND Estado <> 'Anulada';
GO

PRINT ''
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'SCRIPT 18 COMPLETADO'
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'Para modificar el tope ejecutar:'
PRINT '  UPDATE dbo.PARAMETRO_SISTEMA SET Valor = ''3000000'' WHERE Clave = ''TopeDiarioCompras'''
PRINT ''
PRINT 'El control aplica en:'
PRINT '  • usp_RegistrarOrdenCompra       (al crear la OC)'
PRINT '  • usp_RegistrarRecepcionDesdeOC  (al registrar la factura)'
PRINT ''
