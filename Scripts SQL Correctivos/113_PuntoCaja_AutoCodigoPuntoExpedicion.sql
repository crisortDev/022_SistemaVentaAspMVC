-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 113: Cajas nuevas reciben Código y Punto de Expedición automáticos
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31  ·  Depende de scripts 108-112.
--
-- PROBLEMA:
--   usp_RegistrarPuntoCaja inserta la caja SIN Codigo ni PuntoExpedicion, por lo
--   que las cajas creadas desde la pantalla quedan sin numeración DNIT (ej. la
--   "Caja 2" de Sucursal quedó con Codigo='' y PuntoExpedicion='').
--
-- FIX:
--   1. usp_RegistrarPuntoCaja autogenera:
--        - PuntoExpedicion = siguiente correlativo libre POR TIENDA (001, 002...)
--        - Codigo          = 'CJ-' + IdPuntoCaja con 3 dígitos
--        - EstadoOperativo = 'Activo'
--   2. UPDATE de reparación: completa las cajas existentes que quedaron sin datos.
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Reparar cajas existentes sin Código / Punto de Expedición ───────────────
;WITH Faltantes AS (
    SELECT
        pc.IdPuntoCaja,
        pc.IdTienda,
        -- siguiente número disponible por tienda, considerando los ya asignados
        ROW_NUMBER() OVER (PARTITION BY pc.IdTienda ORDER BY pc.IdPuntoCaja)
          + ISNULL((SELECT MAX(TRY_CAST(p2.PuntoExpedicion AS INT))
                    FROM dbo.PUNTO_CAJA p2
                    WHERE p2.IdTienda = pc.IdTienda
                      AND p2.PuntoExpedicion <> '' AND p2.PuntoExpedicion IS NOT NULL), 0) AS NuevoNro
    FROM dbo.PUNTO_CAJA pc
    WHERE ISNULL(pc.PuntoExpedicion,'') = '' OR ISNULL(pc.Codigo,'') = ''
)
UPDATE pc
    SET pc.PuntoExpedicion = RIGHT('000' + CAST(f.NuevoNro AS VARCHAR), 3),
        pc.Codigo          = 'CJ-' + RIGHT('000' + CAST(pc.IdPuntoCaja AS VARCHAR), 3),
        pc.EstadoOperativo = ISNULL(NULLIF(pc.EstadoOperativo,''), 'Activo')
FROM dbo.PUNTO_CAJA pc
INNER JOIN Faltantes f ON f.IdPuntoCaja = pc.IdPuntoCaja;
PRINT 'OK: cajas existentes sin código/punto reparadas. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ─── 2. usp_RegistrarPuntoCaja — autogenera código y punto de expedición ────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPuntoCaja
    @IdTienda    INT,
    @Nombre      VARCHAR(50),
    @Descripcion VARCHAR(200),
    @Resultado   BIT           OUTPUT,
    @Mensaje     NVARCHAR(300) OUTPUT,
    @IdPuntoCaja INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF LTRIM(RTRIM(@Nombre)) = ''
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'El nombre de la caja es obligatorio.';
            SET @IdPuntoCaja = 0; RETURN;
        END
        IF EXISTS (
            SELECT 1 FROM dbo.PUNTO_CAJA
            WHERE IdTienda = @IdTienda AND Nombre = LTRIM(RTRIM(@Nombre)) AND Activo = 1
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Ya existe una caja con ese nombre en esta tienda.';
            SET @IdPuntoCaja = 0; RETURN;
        END

        -- Siguiente Punto de Expedición libre para esta tienda (001, 002...)
        DECLARE @NuevoNro INT =
            ISNULL((SELECT MAX(TRY_CAST(PuntoExpedicion AS INT))
                    FROM dbo.PUNTO_CAJA
                    WHERE IdTienda = @IdTienda
                      AND PuntoExpedicion <> '' AND PuntoExpedicion IS NOT NULL), 0) + 1;
        DECLARE @PtoExp VARCHAR(3) = RIGHT('000' + CAST(@NuevoNro AS VARCHAR), 3);

        INSERT INTO dbo.PUNTO_CAJA
            (IdTienda, Nombre, Descripcion, PuntoExpedicion, SecuenciaActual, EstadoOperativo, Activo)
        VALUES
            (@IdTienda, LTRIM(RTRIM(@Nombre)), NULLIF(LTRIM(RTRIM(@Descripcion)),''),
             @PtoExp, 0, 'Activo', 1);

        SET @IdPuntoCaja = SCOPE_IDENTITY();

        -- Código basado en el Id recién generado (CJ-00X)
        UPDATE dbo.PUNTO_CAJA
           SET Codigo = 'CJ-' + RIGHT('000' + CAST(@IdPuntoCaja AS VARCHAR), 3)
         WHERE IdPuntoCaja = @IdPuntoCaja;

        SET @Resultado   = 1;
        SET @Mensaje     = 'Punto de caja registrado (Pto. Exp. ' + @PtoExp + ').';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0; SET @IdPuntoCaja = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarPuntoCaja — autogenera Código y Punto de Expedición.';
GO

-- ─── 3. Verificación ────────────────────────────────────────────────────────────
SELECT IdPuntoCaja, IdTienda, Nombre, Codigo, PuntoExpedicion, EstadoOperativo
FROM dbo.PUNTO_CAJA
ORDER BY IdTienda, PuntoExpedicion;
GO

PRINT '════ Script 113 completado ════';
GO
