-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 87: Fix fórmula de Diferencia en usp_CerrarCaja
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- PROBLEMA:
--   usp_CerrarCaja calcula:
--       Diferencia = @MontoContado - @MontoSistema
--   donde MontoSistema = solo ventas contado + cobros CXC (SIN apertura).
--
--   El usuario cuenta TODO el efectivo físico en la caja = apertura + ventas.
--   Resultado: la diferencia siempre muestra un "sobrante" igual al monto de apertura.
--
-- SOLUCIÓN:
--   Diferencia = @MontoContado - (MontoApertura + @MontoSistema)
--   Así si el cajero cuenta exactamente apertura + ventas contado, la diferencia = 0.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_CerrarCaja
    @IdCaja         INT,
    @IdUsuario      INT,
    @MontoContado   DECIMAL(18,2),
    @Observacion    VARCHAR(500),
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda       INT,
                @FechaApertura  DATETIME,
                @Estado         VARCHAR(20),
                @MontoApertura  DECIMAL(18,2);

        SELECT @IdTienda      = IdTienda,
               @FechaApertura = FechaApertura,
               @Estado        = Estado,
               @MontoApertura = MontoApertura
        FROM   dbo.CAJA
        WHERE  IdCaja = @IdCaja;

        IF @Estado IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'Caja no encontrada.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Abierta'
        BEGIN SET @Resultado = 0; SET @Mensaje = 'La caja ya fue cerrada.'; ROLLBACK; RETURN; END

        -- ── MontoSistema = ventas CONTADO del período + cobros CXC de esta caja ──
        DECLARE @TotalContado   DECIMAL(18,2),
                @TotalCobrosCXC DECIMAL(18,2);

        -- Ventas contado cobradas en este turno
        SELECT @TotalContado = ISNULL(SUM(v.TotalCosto), 0)
        FROM   dbo.VENTA v
        INNER  JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
        WHERE  v.IdTienda        = @IdTienda
          AND  v.FechaRegistro  >= @FechaApertura
          AND  v.FechaRegistro  <= GETDATE()
          AND  v.Estado          = 'Activa'
          AND  ISNULL(v.Condicion, 'Contado') = 'Contado';

        -- Cobros de crédito recibidos durante este turno de caja
        SELECT @TotalCobrosCXC = ISNULL(SUM(cx.MontoRecibido - cx.MontoCambio), 0)
        FROM   dbo.COBRO_CXC cx
        WHERE  cx.IdCaja = @IdCaja;

        -- MontoSistema = solo las ventas/cobros (sin apertura)
        DECLARE @MontoSistema DECIMAL(18,2) = @TotalContado + @TotalCobrosCXC;

        -- ── Diferencia corregida: contado físico vs (apertura + ventas + cobros) ──
        -- El cajero cuenta TODO el efectivo en la caja, incluyendo el fondo inicial.
        -- Diferencia positiva = sobrante | negativa = faltante | 0 = cuadre exacto.
        DECLARE @Diferencia DECIMAL(18,2) = @MontoContado - (@MontoApertura + @MontoSistema);

        UPDATE dbo.CAJA
           SET FechaCierre     = GETDATE(),
               IdUsuarioCierre = @IdUsuario,
               MontoSistema    = @MontoSistema,
               MontoContado    = @MontoContado,
               Diferencia      = @Diferencia,
               Estado          = 'Cerrada',
               Observacion     = @Observacion
         WHERE IdCaja = @IdCaja;

        SET @Resultado = 1;
        SET @Mensaje   = 'Caja cerrada. '
                       + 'Apertura: Gs. '          + FORMAT(@MontoApertura,  'N0')
                       + ' | Ventas contado: Gs. ' + FORMAT(@TotalContado,   'N0')
                       + ' | Cobros crédito: Gs. ' + FORMAT(@TotalCobrosCXC, 'N0')
                       + ' | Saldo esperado: Gs. ' + FORMAT(@MontoApertura + @MontoSistema, 'N0')
                       + ' | Contado físico: Gs. ' + FORMAT(@MontoContado,   'N0')
                       + ' | Diferencia: Gs. '     + FORMAT(@Diferencia,     'N0') + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT 'OK: usp_CerrarCaja corregido — Diferencia = MontoContado - (MontoApertura + MontoSistema).';
PRINT '════ Script 87 completado ════';
GO
