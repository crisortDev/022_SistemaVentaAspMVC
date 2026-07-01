-- ============================================================
--  FIX: usp_GenerarNotaCreditoPorDiferencia
--  Agrega guarda para evitar generar NC duplicadas en la
--  misma compra. Si ya existe MontoNotaCredito > 0 retorna
--  error informativo en lugar de sobreescribir.
-- ============================================================

ALTER PROCEDURE [dbo].[usp_GenerarNotaCreditoPorDiferencia]
    @IdCompra            INT,
    @IdMotivoNotaCredito INT,
    @Resultado           BIT           OUTPUT,
    @Mensaje             NVARCHAR(400) OUTPUT,
    @MontoNC             DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- ── GUARDA: verificar si ya existe NC para esta compra ──
        DECLARE @MontoExistente DECIMAL(18,2);
        SELECT @MontoExistente = MontoNotaCredito
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        IF @MontoExistente IS NOT NULL AND @MontoExistente > 0
        BEGIN
            SET @Resultado = 0;
            SET @MontoNC   = @MontoExistente;
            SET @Mensaje   = 'Ya existe una Nota de Crédito para esta compra por Gs. '
                           + CAST(CAST(@MontoExistente AS INT) AS NVARCHAR(30)) + '.';
            ROLLBACK; RETURN;
        END
        -- ── FIN GUARDA ──────────────────────────────────────────

        SELECT @MontoNC = SUM(
              (ISNULL(dc.Cantidad,0) - ISNULL(dc.CantidadRecibida,0))
            *  ISNULL(dc.PrecioUnitarioCompra,0))
          FROM dbo.DETALLE_COMPRA dc
         WHERE dc.IdCompra = @IdCompra
           AND dc.Activo = 1
           AND ISNULL(dc.CantidadRecibida, dc.Cantidad) < dc.Cantidad;

        IF @MontoNC IS NULL OR @MontoNC = 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'No hay diferencia que justifique nota de crédito.';
            ROLLBACK; RETURN;
        END

        UPDATE dbo.COMPRA
           SET IdMotivoNotaCredito = @IdMotivoNotaCredito,
               MontoNotaCredito    = @MontoNC
         WHERE IdCompra = @IdCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Nota de crédito generada por Gs. '
                       + CAST(CAST(@MontoNC AS INT) AS NVARCHAR(30)) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
