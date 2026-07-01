-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 20: SuperAdmin sin restricción de Segregación O&M
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-06
--
-- El SuperAdmin puede confirmar y aprobar documentos que él mismo registró.
-- Para el resto de roles la validación O&M sigue aplicando normalmente.
--
-- Cambio: agrega @EsSuperAdmin BIT = 0 a:
--   - usp_ConfirmarCompraEImpactarStock
--   - usp_AprobarOrdenCompra
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: usp_ConfirmarCompraEImpactarStock
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 1: usp_ConfirmarCompraEImpactarStock ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra      INT,
    @IdUsuario     INT  = 0,
    @EsSuperAdmin  BIT  = 0     -- 1 = saltear validación O&M
    ,@Resultado    BIT           OUTPUT,
    @Mensaje       NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda          INT,
                @EstadoRecepcion   VARCHAR(20),
                @EstadoActual      VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @IdTienda          = IdTienda,
               @EstadoRecepcion   = EstadoRecepcion,
               @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Solo se puede confirmar una compra en estado EnRecepcion. Estado actual: '
                         + ISNULL(@EstadoRecepcion, '?');
            ROLLBACK; RETURN;
        END

        -- Validar segregación O&M solo para usuarios que NO son SuperAdmin
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El usuario que registró la factura no puede confirmarla (segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- Validar stock máximo antes de impactar
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';

        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '  + CAST(ISNULL(pt.Stock, 0) AS VARCHAR) +
               ', a recibir: '          + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '             + CAST(pt.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                          AND pt.IdTienda   = @IdTienda
         INNER JOIN dbo.PRODUCTO p         ON p.IdProducto  = dc.IdProducto
         WHERE dc.IdCompra = @IdCompra
           AND dc.Activo   = 1
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > pt.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Confirmar superaría el stock máximo: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- Impactar stock
        ;WITH Recepcionado AS (
            SELECT IdProducto,
                   SUM(ISNULL(CantidadRecibida, Cantidad)) AS Cantidad
              FROM dbo.DETALLE_COMPRA
             WHERE IdCompra = @IdCompra
               AND Activo   = 1
               AND EstadoLinea IN ('Aceptada', 'NC')
             GROUP BY IdProducto
        )
        UPDATE pt
           SET Stock    = ISNULL(pt.Stock, 0) + r.Cantidad,
               Iniciado = 1
          FROM dbo.PRODUCTO_TIENDA pt
         INNER JOIN Recepcionado r ON pt.IdProducto = r.IdProducto
         WHERE pt.IdTienda = @IdTienda;

        -- Actualizar estado de la compra
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- Historial
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdCompra, ISNULL(@EstadoActual, 'Pendiente'), 'Confirmada', @IdUsuario,
                 CASE WHEN @EsSuperAdmin = 1
                      THEN 'Confirmación por SuperAdmin'
                      ELSE 'Confirmación de factura e impacto de stock' END);
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra confirmada. Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_ConfirmarCompraEImpactarStock — SuperAdmin puede confirmar sus propias recepciones'
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: usp_AprobarOrdenCompra
-- ════════════════════════════════════════════════════════════════════════════════
PRINT '━━━ PASO 2: usp_AprobarOrdenCompra ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_AprobarOrdenCompra]
    @IdOrdenCompra      INT,
    @IdUsuarioAprobador INT,
    @EsSuperAdmin       BIT  = 0,   -- 1 = saltear validación O&M
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual      VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuarioRegistro
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Orden de Compra no encontrada.';
            RETURN;
        END

        IF @EstadoActual <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se pueden aprobar órdenes en estado Pendiente. Estado actual: ' + @EstadoActual;
            RETURN;
        END

        -- Validar segregación O&M solo para usuarios que NO son SuperAdmin
        IF @EsSuperAdmin = 0 AND @IdUsuarioRegistro = @IdUsuarioAprobador
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que creó la orden no puede ser el mismo que la aprueba (segregación de funciones).';
            RETURN;
        END

        BEGIN TRAN;

        UPDATE dbo.OrdenCompra
           SET Estado             = 'Aprobada',
               IdUsuarioAprobador = @IdUsuarioAprobador,
               FechaAprobacion    = GETDATE(),
               MotivoRechazo      = NULL
         WHERE IdOrdenCompra = @IdOrdenCompra;

        -- Historial
        INSERT INTO dbo.HISTORIAL_ESTADO_OC
            (IdOrdenCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
        VALUES
            (@IdOrdenCompra, 'Pendiente', 'Aprobada', @IdUsuarioAprobador,
             CASE WHEN @EsSuperAdmin = 1
                  THEN 'Aprobación por SuperAdmin'
                  ELSE 'Aprobación de Orden de Compra' END);

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Orden de Compra aprobada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_AprobarOrdenCompra — SuperAdmin puede aprobar sus propias OC'
GO

PRINT ''
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'SCRIPT 20 COMPLETADO'
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'El SuperAdmin puede confirmar y aprobar documentos que él mismo registró.'
PRINT 'Para el resto de roles la segregación O&M sigue vigente.'
PRINT ''
