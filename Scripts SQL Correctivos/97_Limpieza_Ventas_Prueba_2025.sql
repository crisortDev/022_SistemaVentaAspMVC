-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 97: Limpieza de ventas de PRUEBA (versión anterior del sistema) — 2025
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-30
--
-- OBJETIVO (para defensa de tesis): que los reportes no muestren ventas inválidas
--   cargadas con una versión anterior (total 0 o sin detalle).
--
-- DECISIÓN: ANULAR, no borrar. Se marca Estado='Anulada' (+ auditoría).
--   - No se pierde historial → trazable.
--   - No rompe correlativos de numeración.
--   - Los reportes y SP que filtran por Estado/Activo dejan de incluirlas.
--
-- ALCANCE: SOLO ventas de 2025 (datos de prueba). Las de 2026 (sistema nuevo)
--   NO se tocan. Dentro de 2025, solo las que cumplen criterio de "inválida":
--     • TotalCosto <= 0, O
--     • sin líneas en DETALLE_VENTA activas.
--
-- ⚠️ HACER BACKUP ANTES. Ejecutar primero el PASO 1 (diagnóstico) y revisar
--    la lista. Recién si estás de acuerdo, ejecutar el PASO 2 (anulación).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1 — DIAGNÓSTICO (solo lectura, no cambia nada)
--   Revisá esta lista antes de anular. Son las candidatas.
-- ════════════════════════════════════════════════════════════════════════════════
SELECT
    v.IdVenta,
    v.Codigo,
    v.NumeroFactura,
    v.TipoDocumento,
    v.Estado,
    v.TotalCosto,
    CONVERT(VARCHAR(10), v.FechaRegistro, 103)              AS FechaRegistro,
    (SELECT COUNT(*) FROM dbo.DETALLE_VENTA dv
      WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1)        AS LineasActivas,
    CASE
        WHEN ISNULL(v.TotalCosto,0) <= 0 THEN 'Total 0/negativo'
        WHEN NOT EXISTS (SELECT 1 FROM dbo.DETALLE_VENTA dv
                          WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1)
             THEN 'Sin detalle'
        ELSE 'OK'
    END                                                      AS Motivo
FROM dbo.VENTA v
WHERE YEAR(v.FechaRegistro) = 2025
  AND ISNULL(v.Estado,'') <> 'Anulada'
  AND (
        ISNULL(v.TotalCosto,0) <= 0
        OR NOT EXISTS (SELECT 1 FROM dbo.DETALLE_VENTA dv
                        WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1)
      )
ORDER BY v.FechaRegistro, v.IdVenta;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2 — ANULACIÓN (descomentar para ejecutar, tras revisar el PASO 1)
--   Transaccional: si algo falla, no deja cambios a medias.
-- ════════════════════════════════════════════════════════════════════════════════
/*
BEGIN TRY
    BEGIN TRANSACTION;

    -- Tabla temporal con las ventas a anular (mismo criterio que el diagnóstico)
    DECLARE @aAnular TABLE (IdVenta INT);
    INSERT INTO @aAnular (IdVenta)
    SELECT v.IdVenta
    FROM dbo.VENTA v
    WHERE YEAR(v.FechaRegistro) = 2025
      AND ISNULL(v.Estado,'') <> 'Anulada'
      AND (
            ISNULL(v.TotalCosto,0) <= 0
            OR NOT EXISTS (SELECT 1 FROM dbo.DETALLE_VENTA dv
                            WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1)
          );

    DECLARE @n INT = (SELECT COUNT(*) FROM @aAnular);

    -- Marcar la venta como Anulada (solo columnas que con certeza existen)
    UPDATE v
       SET v.Estado = 'Anulada'
    FROM dbo.VENTA v
    INNER JOIN @aAnular a ON a.IdVenta = v.IdVenta;

    -- Si tu tabla VENTA tiene columna Activo, descomentá esta línea también:
    -- UPDATE v SET v.Activo = 0 FROM dbo.VENTA v INNER JOIN @aAnular a ON a.IdVenta = v.IdVenta;

    -- Desactivar su detalle para que no sume en reportes basados en DETALLE_VENTA
    UPDATE dv
       SET dv.Activo = 0
    FROM dbo.DETALLE_VENTA dv
    INNER JOIN @aAnular a ON a.IdVenta = dv.IdVenta;

    PRINT '>> Ventas de prueba 2025 anuladas: ' + CAST(@n AS VARCHAR);

    COMMIT TRANSACTION;
    PRINT '════ Script 97 (anulación) completado correctamente. ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: no se aplicó ningún cambio.';
END CATCH;
GO
*/

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3 — VERIFICACIÓN (tras ejecutar el PASO 2)
--   Debe devolver 0 filas si la limpieza fue completa.
-- ════════════════════════════════════════════════════════════════════════════════
-- SELECT v.IdVenta, v.Codigo, v.TotalCosto, v.Estado
-- FROM dbo.VENTA v
-- WHERE YEAR(v.FechaRegistro) = 2025
--   AND ISNULL(v.Estado,'') <> 'Anulada'
--   AND ISNULL(v.TotalCosto,0) <= 0;
-- GO
