-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 101: Anular ventas de PRUEBA 2025 (precios irreales)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Las ventas de 2025 se cargaron con la versión anterior y tienen precios de prueba
-- irreales (ej. Gs 680 / Gs 430 para productos que cuestan cientos de miles), lo que
-- generaba márgenes negativos absurdos en el reporte de rentabilidad.
--
-- DECISIÓN: ANULAR (no borrar). Estado='Anulada' + detalle inactivo. Trazable,
--   no rompe correlativos, y sale de todos los reportes y totales.
--
-- ⚠️ BACKUP antes. Ejecutá el PASO 1 (diagnóstico) y revisá la lista.
--    Si estás de acuerdo, descomentá y ejecutá el PASO 2.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: DIAGNÓSTICO (solo lectura) — ventas activas de 2025 ─────────────────
SELECT
    v.IdVenta, v.Codigo, v.NumeroFactura, v.TipoDocumento, v.Estado,
    v.TotalCosto,
    CONVERT(VARCHAR(10), v.FechaRegistro, 103) AS FechaRegistro,
    (SELECT COUNT(*) FROM dbo.DETALLE_VENTA dv
      WHERE dv.IdVenta = v.IdVenta AND dv.Activo = 1) AS Lineas
FROM dbo.VENTA v
WHERE YEAR(v.FechaRegistro) = 2025
  AND ISNULL(v.Estado,'') <> 'Anulada'
ORDER BY v.FechaRegistro, v.IdVenta;
GO

-- ── PASO 2: ANULACIÓN (descomentar tras revisar el PASO 1) ─────────────────────
/*
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @aAnular TABLE (IdVenta INT);
    INSERT INTO @aAnular (IdVenta)
    SELECT v.IdVenta
    FROM dbo.VENTA v
    WHERE YEAR(v.FechaRegistro) = 2025
      AND ISNULL(v.Estado,'') <> 'Anulada';

    DECLARE @n INT = (SELECT COUNT(*) FROM @aAnular);

    UPDATE v SET v.Estado = 'Anulada'
    FROM dbo.VENTA v INNER JOIN @aAnular a ON a.IdVenta = v.IdVenta;

    -- Si VENTA tiene columna Activo, descomentá:
    -- UPDATE v SET v.Activo = 0 FROM dbo.VENTA v INNER JOIN @aAnular a ON a.IdVenta = v.IdVenta;

    UPDATE dv SET dv.Activo = 0
    FROM dbo.DETALLE_VENTA dv INNER JOIN @aAnular a ON a.IdVenta = dv.IdVenta;

    PRINT '>> Ventas de prueba 2025 anuladas: ' + CAST(@n AS VARCHAR);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO
*/

-- ── PASO 3: VERIFICACIÓN (tras el PASO 2) — debe dar 0 ─────────────────────────
-- SELECT COUNT(*) AS VentasActivas2025
-- FROM dbo.VENTA WHERE YEAR(FechaRegistro)=2025 AND ISNULL(Estado,'')<>'Anulada';
-- GO
