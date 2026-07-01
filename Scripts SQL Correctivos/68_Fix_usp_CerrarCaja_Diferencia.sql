-- ============================================================
-- Script 68: Fix usp_CerrarCaja — cálculo correcto de Diferencia
-- Fecha: 2026-05-19
--
-- Error anterior:
--   Diferencia = MontoContado - MontoSistema
--   Ej: 2.300.000 - 300.000 = +2.000.000 (INCORRECTO)
--
-- Corrección:
--   Diferencia = MontoContado - (MontoApertura + MontoSistema)
--   Ej: 2.300.000 - (2.000.000 + 300.000) = 0 (CORRECTO)
--
-- Lógica:
--   MontoApertura  = efectivo con que se abrió la caja
--   MontoSistema   = suma de ventas activas del turno
--   Total esperado = MontoApertura + MontoSistema
--   Diferencia     = lo que hay físicamente menos lo que debería haber
-- ============================================================

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_CerrarCaja
    @IdCaja       INT,
    @IdUsuario    INT,
    @MontoContado DECIMAL(18,2),
    @Observacion  VARCHAR(500),
    @Resultado    BIT           OUTPUT,
    @Mensaje      NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda      INT;
        DECLARE @FechaApertura DATETIME;
        DECLARE @MontoApertura DECIMAL(18,2);
        DECLARE @Estado        VARCHAR(20);

        SELECT @IdTienda      = IdTienda,
               @FechaApertura = FechaApertura,
               @MontoApertura = MontoApertura,
               @Estado        = Estado
        FROM   dbo.CAJA
        WHERE  IdCaja = @IdCaja;

        IF @Estado IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Caja no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @Estado <> 'Abierta'
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'La caja ya fue cerrada.';
            ROLLBACK; RETURN;
        END

        -- Total ventas activas del turno
        DECLARE @MontoSistema DECIMAL(18,2);
        SELECT @MontoSistema = ISNULL(SUM(TotalCosto), 0)
        FROM   dbo.VENTA
        WHERE  IdTienda       = @IdTienda
          AND  FechaRegistro >= @FechaApertura
          AND  FechaRegistro <= GETDATE()
          AND  Estado = 'Activa';

        -- Diferencia = físico - (apertura + ventas)
        DECLARE @Diferencia DECIMAL(18,2);
        SET @Diferencia = @MontoContado - (@MontoApertura + @MontoSistema);

        UPDATE dbo.CAJA
           SET FechaCierre     = GETDATE(),
               IdUsuarioCierre = @IdUsuario,
               MontoSistema    = @MontoSistema,
               MontoContado    = @MontoContado,
               Diferencia      = @Diferencia,
               Estado          = 'Cerrada',
               Observacion     = @Observacion
         WHERE IdCaja = @IdCaja;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Caja cerrada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_CerrarCaja corregido (Diferencia = MontoContado - (MontoApertura + MontoSistema)).';
GO

PRINT '════ Script 68 completado ════';
GO
