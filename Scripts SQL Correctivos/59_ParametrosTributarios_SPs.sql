-- ============================================================
-- Script 59: Parámetros Tributarios — SPs de gestión
-- Fecha: 2026-05-18
--
-- Objetivos:
--   1. Agregar columna RazonSocial a DATOS_TRIBUTARIOS (si no existe)
--   2. usp_ObtenerConfiguracionTributaria  → datos completos para el CRUD
--   3. usp_ActualizarConfiguracionTributaria → editar timbrado y establecimiento
--   4. usp_ObtenerHistorialTimbrados        → (futuro) registrar múltiples timbrados
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── 1. Columna RazonSocial en DATOS_TRIBUTARIOS ──────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.DATOS_TRIBUTARIOS') AND name = 'RazonSocial'
)
BEGIN
    ALTER TABLE dbo.DATOS_TRIBUTARIOS ADD RazonSocial VARCHAR(200) NULL;
    PRINT 'OK: Columna RazonSocial agregada a DATOS_TRIBUTARIOS.';
END
ELSE
    PRINT 'INFO: Columna RazonSocial ya existía.';
GO

-- ── 2. usp_ObtenerConfiguracionTributaria ────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerConfiguracionTributaria]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        NumeroTimbrado,
        VencimientoTimbrado,
        Establecimiento,
        PuntoExpedicion,
        SecuenciaActual,
        ISNULL(RazonSocial, '') AS RazonSocial,
        -- Próximo número de factura
        Establecimiento + '-' + PuntoExpedicion + '-'
            + RIGHT('0000000' + CAST(SecuenciaActual + 1 AS VARCHAR), 7)
                                 AS ProximoNumeroFactura,
        -- Días hasta vencimiento
        DATEDIFF(DAY, GETDATE(), VencimientoTimbrado) AS DiasParaVencer,
        -- Estado del timbrado
        CASE
            WHEN VencimientoTimbrado < CAST(GETDATE() AS DATE)           THEN 'VENCIDO'
            WHEN DATEDIFF(DAY, GETDATE(), VencimientoTimbrado) <= 30     THEN 'POR VENCER'
            ELSE 'VIGENTE'
        END AS EstadoTimbrado
    FROM dbo.DATOS_TRIBUTARIOS;
END
GO
PRINT 'OK: usp_ObtenerConfiguracionTributaria creado.';
GO

-- ── 3. usp_ActualizarConfiguracionTributaria ─────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ActualizarConfiguracionTributaria]
    @NumeroTimbrado     VARCHAR(20),
    @VencimientoTimbrado DATE,
    @Establecimiento    VARCHAR(3),
    @PuntoExpedicion    VARCHAR(3),
    @RazonSocial        VARCHAR(200),
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validaciones
        IF @NumeroTimbrado IS NULL OR LTRIM(RTRIM(@NumeroTimbrado)) = ''
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'El número de timbrado es obligatorio.'; RETURN;
        END
        IF @VencimientoTimbrado < CAST(GETDATE() AS DATE)
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'La fecha de vencimiento no puede ser anterior a hoy.'; RETURN;
        END
        IF LEN(LTRIM(RTRIM(@Establecimiento))) <> 3 OR LEN(LTRIM(RTRIM(@PuntoExpedicion))) <> 3
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Establecimiento y Punto de Expedición deben tener exactamente 3 dígitos.'; RETURN;
        END

        -- Si cambia el timbrado, reiniciar secuencia
        DECLARE @TimbradoActual VARCHAR(20);
        SELECT TOP 1 @TimbradoActual = NumeroTimbrado FROM dbo.DATOS_TRIBUTARIOS;

        UPDATE dbo.DATOS_TRIBUTARIOS
        SET NumeroTimbrado      = @NumeroTimbrado,
            VencimientoTimbrado = @VencimientoTimbrado,
            Establecimiento     = @Establecimiento,
            PuntoExpedicion     = @PuntoExpedicion,
            RazonSocial         = @RazonSocial,
            SecuenciaActual     = CASE WHEN @NumeroTimbrado <> ISNULL(@TimbradoActual, '')
                                       THEN 0           -- nuevo timbrado: reinicia secuencia
                                       ELSE SecuenciaActual  -- mismo timbrado: no toca
                                  END;

        SET @Resultado = 1;
        SET @Mensaje   = CASE WHEN @NumeroTimbrado <> ISNULL(@TimbradoActual, '')
                              THEN 'Timbrado renovado correctamente. Secuencia reiniciada a 0.'
                              ELSE 'Configuración tributaria actualizada.'
                         END;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ActualizarConfiguracionTributaria creado.';
GO

-- ── Verificación ─────────────────────────────────────────────────────────────
EXEC dbo.usp_ObtenerConfiguracionTributaria;
GO
PRINT '════ Script 59 completado ════';
GO
