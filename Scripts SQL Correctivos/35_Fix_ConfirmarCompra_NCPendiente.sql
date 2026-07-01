-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 35: Ajuste de validación NC en usp_ConfirmarCompraEImpactarStock
--
-- Cambio solicitado por tutor:
--   Cuando hay diferencias en la recepción y la NC está en estado 'Pendiente',
--   igual se debe poder confirmar la compra e impactar el stock.
--   El seguimiento del documento físico queda pendiente en "Gestión de NC".
--
-- Nueva lógica de validación NC:
--   - Sin diferencias               → confirmar sin restricción (igual que antes)
--   - Con diferencias, NC = NULL    → BLOQUEAR (debe generarse la NC primero)
--   - Con diferencias, NC = Pendiente → PERMITIR (stock se suma, NC sigue pendiente)
--   - Con diferencias, NC = Recibida  → PERMITIR (flujo completo)
--   - Con diferencias, NC = Rechazada → BLOQUEAR (NC inválida, debe resolverse)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra      INT,
    @IdUsuario     INT  = 0,
    @EsSuperAdmin  BIT  = 0,
    @Resultado     BIT           OUTPUT,
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
          FROM dbo.COMPRA WHERE IdCompra = @IdCompra;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se puede confirmar en estado EnRecepcion. Actual: '
                           + ISNULL(@EstadoRecepcion, '?');
            ROLLBACK; RETURN;
        END

        -- ── Validar NC solo si hay diferencias ────────────────────────────────
        DECLARE @HayDiferencia BIT = 0;
        IF EXISTS (
            SELECT 1 FROM dbo.DETALLE_COMPRA
             WHERE IdCompra = @IdCompra AND Activo = 1
               AND ISNULL(CantidadRecibida, Cantidad) < Cantidad
        ) SET @HayDiferencia = 1;

        IF @HayDiferencia = 1
        BEGIN
            DECLARE @EstadoNC VARCHAR(20);
            SELECT @EstadoNC = Estado
              FROM dbo.NOTA_CREDITO
             WHERE IdCompra = @IdCompra;

            -- Sin NC generada → bloquear (el operador debe hacer clic en "Generar NC")
            IF @EstadoNC IS NULL
            BEGIN
                SET @Resultado = 0;
                SET @Mensaje   = 'Existen diferencias en cantidades. '
                               + 'Debe generar la Nota de Crédito antes de confirmar.';
                ROLLBACK; RETURN;
            END

            -- NC Rechazada → bloquear (documento inválido, debe resolverse)
            IF @EstadoNC = 'Rechazada'
            BEGIN
                SET @Resultado = 0;
                SET @Mensaje   = 'La Nota de Crédito fue Rechazada. '
                               + 'Comuníquese con el proveedor para obtener un nuevo documento.';
                ROLLBACK; RETURN;
            END

            -- NC Pendiente o Recibida → permitir (continuar con la confirmación)
        END

        -- ── Validar segregación O&M ───────────────────────────────────────────
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que registró la factura no puede confirmarla '
                           + '(segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- ── Validar stock máximo (PRODUCTO.StockMaximo) ───────────────────────
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';
        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '   + CAST(ISNULL(pt.Stock, 0) AS VARCHAR) +
               ', a recibir: '           + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '              + CAST(p.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = dc.IdProducto
          LEFT JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                         AND pt.IdTienda    = @IdTienda
         WHERE dc.IdCompra    = @IdCompra AND dc.Activo = 1
           AND p.StockMaximo  > 0
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > p.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Confirmar superaría el stock máximo en: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ── Auto-crear PRODUCTO_TIENDA para productos nuevos ──────────────────
        INSERT INTO dbo.PRODUCTO_TIENDA
            (IdProducto, IdTienda, PrecioUnidadCompra, PrecioUnidadVenta,
             Stock, StockMinimo, StockMaximo, LimiteCompraDiaria, Iniciado, Activo, FechaRegistro)
        SELECT DISTINCT dc.IdProducto, @IdTienda, dc.PrecioUnitarioCompra,
                        0, 0, 0, 0, 0, 0, 1, GETDATE()
          FROM dbo.DETALLE_COMPRA dc
         WHERE dc.IdCompra   = @IdCompra AND dc.Activo = 1
           AND dc.EstadoLinea IN ('Aceptada', 'NC')
           AND NOT EXISTS (
               SELECT 1 FROM dbo.PRODUCTO_TIENDA pt
                WHERE pt.IdProducto = dc.IdProducto AND pt.IdTienda = @IdTienda
           );

        -- ── Impactar stock ────────────────────────────────────────────────────
        ;WITH R AS (
            SELECT IdProducto, SUM(ISNULL(CantidadRecibida, Cantidad)) AS Qty
              FROM dbo.DETALLE_COMPRA
             WHERE IdCompra = @IdCompra AND Activo = 1
               AND EstadoLinea IN ('Aceptada', 'NC')
             GROUP BY IdProducto
        )
        UPDATE pt
           SET Stock    = ISNULL(pt.Stock, 0) + r.Qty,
               Iniciado = 1
          FROM dbo.PRODUCTO_TIENDA pt
         INNER JOIN R r ON pt.IdProducto = r.IdProducto
         WHERE pt.IdTienda = @IdTienda;

        -- ── Actualizar estado compra ──────────────────────────────────────────
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- ── Historial ─────────────────────────────────────────────────────────
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES (
                @IdCompra,
                ISNULL(@EstadoActual, 'Pendiente'),
                'Confirmada',
                @IdUsuario,
                CASE WHEN @EsSuperAdmin = 1
                     THEN 'Confirmación por SuperAdmin'
                     ELSE 'Confirmación de factura e impacto de stock' END
            );

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra confirmada. Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error al confirmar: ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT 'OK: usp_ConfirmarCompraEImpactarStock actualizado.';
PRINT 'Nueva regla NC: Pendiente=permitir, Recibida=permitir, Rechazada=bloquear, NULL=bloquear.';
GO
