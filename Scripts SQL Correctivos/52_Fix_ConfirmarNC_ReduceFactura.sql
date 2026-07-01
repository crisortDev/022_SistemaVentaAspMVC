-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 52: Corregir usp_ConfirmarRecepcionNC y usp_RechazarNC
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
--
-- PROBLEMA (observación del profesor):
--   Al confirmar la recepción de una Nota de Crédito del proveedor, el sistema
--   solo cambiaba el estado a 'Recibida' pero NO reducía COMPRA.TotalCosto.
--   El monto de la factura de compra debía disminuir al confirmar la NC.
--
-- FLUJO CORRECTO:
--   1. Registrar NC  → Estado = 'Pendiente', COMPRA.MontoNotaCredito = MontoNC (ya estaba OK)
--   2. Confirmar NC  → Estado = 'Recibida',  COMPRA.TotalCosto -= MontoNC  ← FIX
--   3. Rechazar NC   → Estado = 'Rechazada', COMPRA.MontoNotaCredito = 0   ← FIX
--      (TotalCosto no se toca al rechazar porque la confirmación nunca ocurrió)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_ConfirmarRecepcionNC — agrega reducción de COMPRA.TotalCosto
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarRecepcionNC]
    @IdNC               INT,
    @NumeroNC           VARCHAR(20),
    @NumeroTimbrado     VARCHAR(20),
    @FechaVencTimbrado  DATE,
    @FechaEmision       DATE,
    @Observacion        VARCHAR(500),
    @IdUsuario          INT,
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- ── Verificar que la NC existe y está Pendiente ───────────────
        DECLARE @EstadoActual VARCHAR(20);
        DECLARE @IdCompra     INT;
        DECLARE @MontoNC      DECIMAL(18,2);

        SELECT @EstadoActual = nc.Estado,
               @IdCompra     = nc.IdCompra,
               @MontoNC      = nc.Monto
          FROM dbo.NOTA_CREDITO nc
         WHERE nc.IdNC = @IdNC;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Nota de Crédito no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoActual <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se pueden confirmar NCs en estado Pendiente. Estado actual: ' + @EstadoActual;
            ROLLBACK; RETURN;
        END

        -- ── Validaciones de datos del documento físico ────────────────
        IF @NumeroNC IS NULL OR LEN(LTRIM(RTRIM(@NumeroNC))) < 5
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Debe ingresar el número de la Nota de Crédito.';
            ROLLBACK; RETURN;
        END

        IF @FechaEmision > GETDATE()
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'La fecha de emisión no puede ser futura.';
            ROLLBACK; RETURN;
        END

        -- ── Verificar regla 30 días SET Paraguay ─────────────────────
        DECLARE @FechaFactura DATE;
        SELECT @FechaFactura = FechaFactura
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        IF @FechaFactura IS NOT NULL AND DATEDIFF(DAY, @FechaFactura, @FechaEmision) > 30
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Advertencia SET PY: la NC fue emitida más de 30 días después '
                           + 'de la fecha de la factura. Verificar con el proveedor.';
            ROLLBACK; RETURN;
        END

        -- ── Confirmar NC: cambiar estado a Recibida ───────────────────
        UPDATE dbo.NOTA_CREDITO
           SET NumeroNC           = LTRIM(RTRIM(@NumeroNC)),
               NumeroTimbrado     = LTRIM(RTRIM(@NumeroTimbrado)),
               FechaVencTimbrado  = @FechaVencTimbrado,
               FechaEmision       = @FechaEmision,
               Estado             = 'Recibida',
               Observacion        = @Observacion,
               IdUsuarioConfirma  = @IdUsuario,
               FechaConfirmacion  = GETDATE()
         WHERE IdNC = @IdNC;

        -- ── Reducir el monto de la factura de compra ──────────────────
        -- Se aplica solo al confirmar (documento físico recibido y validado).
        -- TotalCosto no puede quedar negativo.
        UPDATE dbo.COMPRA
           SET TotalCosto       = CASE
                                      WHEN TotalCosto >= @MontoNC
                                      THEN TotalCosto - @MontoNC
                                      ELSE 0
                                  END,
               MontoNotaCredito = @MontoNC   -- asegurar consistencia
         WHERE IdCompra = @IdCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Nota de Crédito confirmada. El monto de la factura fue reducido en Gs. '
                       + FORMAT(@MontoNC, 'N0') + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ConfirmarRecepcionNC actualizado — ahora reduce COMPRA.TotalCosto al confirmar.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_RechazarNC — limpia MontoNotaCredito en COMPRA al rechazar
--    (TotalCosto no se toca porque la confirmación nunca ocurrió)
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE [dbo].[usp_RechazarNC]
    @IdNC        INT,
    @Observacion VARCHAR(500),
    @IdUsuario   INT,
    @Resultado   BIT           OUTPUT,
    @Mensaje     NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdCompra INT;

        SELECT @IdCompra = IdCompra
          FROM dbo.NOTA_CREDITO
         WHERE IdNC = @IdNC AND Estado = 'Pendiente';

        IF @IdCompra IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'NC no encontrada o no está en estado Pendiente.';
            ROLLBACK; RETURN;
        END

        -- Rechazar la NC
        UPDATE dbo.NOTA_CREDITO
           SET Estado            = 'Rechazada',
               Observacion       = @Observacion,
               IdUsuarioConfirma = @IdUsuario,
               FechaConfirmacion = GETDATE()
         WHERE IdNC = @IdNC;

        -- Limpiar MontoNotaCredito en COMPRA
        -- (TotalCosto no se modifica porque nunca fue reducido al confirmar)
        UPDATE dbo.COMPRA
           SET MontoNotaCredito = 0
         WHERE IdCompra = @IdCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Nota de Crédito rechazada. El monto de la factura no fue modificado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RechazarNC actualizado — limpia MontoNotaCredito en COMPRA al rechazar.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN: Ver estado actual de COMPRA con sus NCs
-- ════════════════════════════════════════════════════════════════════════════════
SELECT c.IdCompra, c.NumeroFactura,
       c.TotalCosto         AS TotalActual,
       c.MontoNotaCredito,
       c.TotalCosto + c.MontoNotaCredito AS TotalOriginalEstimado,
       nc.Estado            AS EstadoNC,
       nc.Monto             AS MontoNC
FROM   dbo.COMPRA c
LEFT   JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
ORDER  BY c.IdCompra DESC;
GO
