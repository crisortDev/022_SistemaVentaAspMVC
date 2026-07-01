-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 98: Anular venta inválida con total 0 (IdVenta 35)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-30
--
-- CONTEXTO:
--   La venta IdVenta=35 (Factura 001-001-0000001, 12/05/2026, Juan Perez) quedó
--   con TotalCosto=0 y su única línea de detalle también en 0 (precio, IVA y total).
--   Se cargó incompleta con una versión anterior. No hay dato real que recuperar.
--
-- DECISIÓN: ANULAR (no borrar), igual criterio que las demás. Trazable, no rompe
--   correlativos, y deja de aparecer en reportes que filtran por Estado/Activo.
--
-- ⚠️ HACER BACKUP ANTES. Ejecutar el PASO 1 (verificar) y luego el PASO 2.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: confirmar que es la venta correcta (solo lectura) ───────────────────
SELECT v.IdVenta, v.Codigo, v.NumeroFactura, v.TipoDocumento, v.Estado, v.TotalCosto,
       CONVERT(VARCHAR(10), v.FechaRegistro, 103) AS FechaRegistro
FROM dbo.VENTA v
WHERE v.IdVenta = 35;
GO

-- ── PASO 2: anular venta + su detalle (transaccional) ───────────────────────────
BEGIN TRY
    BEGIN TRANSACTION;

    -- Seguridad extra: solo actúa si sigue en total 0 (evita anular algo recuperado)
    IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdVenta = 35 AND ISNULL(TotalCosto,0) = 0)
    BEGIN
        UPDATE dbo.VENTA
           SET Estado = 'Anulada'
         WHERE IdVenta = 35;

        -- Si tu tabla VENTA tiene columna Activo, descomentá:
        -- UPDATE dbo.VENTA SET Activo = 0 WHERE IdVenta = 35;

        UPDATE dbo.DETALLE_VENTA
           SET Activo = 0
         WHERE IdVenta = 35;

        PRINT '>> Venta IdVenta=35 anulada correctamente.';
    END
    ELSE
        PRINT '>> Sin cambios: la venta 35 ya no tiene total 0 (o no existe).';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: no se aplicó ningún cambio.';
END CATCH;
GO

-- ── PASO 3: verificación — no deben quedar ventas activas con total 0 ───────────
SELECT v.IdVenta, v.Codigo, v.Estado, v.TotalCosto
FROM dbo.VENTA v
WHERE ISNULL(v.TotalCosto,0) <= 0
  AND ISNULL(v.Estado,'') <> 'Anulada';
GO
