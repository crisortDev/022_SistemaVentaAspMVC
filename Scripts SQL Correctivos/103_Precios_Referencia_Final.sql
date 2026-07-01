-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 103: Precios de referencia definitivos por producto (uniformes por tienda)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- OBJETIVO (defensa): cada producto con UN costo realista y EL MISMO en todas las
--   tiendas. Se corrigen a mano los productos con precios de prueba erróneos
--   (Mouse AD Gs 3, i5 Gs 200k, etc.) y para el resto se usa el mayor valor
--   confiable (último precio de compra vs costo actual).
--
-- Aplica a CostoPromedio y PrecioUnidadCompra de PRODUCTO_TIENDA (todas las tiendas).
--
-- ⚠️ BACKUP antes. Es directo (transaccional). Revisá la tabla de valores abajo.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Valores de referencia por producto (IdProducto, CostoReferencia) ─────────
    --   Dudosos: fijados a valor de mercado realista.
    --   Resto:   el mayor entre último precio de compra y costo actual.
    DECLARE @Ref TABLE (IdProducto INT PRIMARY KEY, CostoRef DECIMAL(18,2));
    INSERT INTO @Ref (IdProducto, CostoRef) VALUES
        (27,  50000),    -- Cable HDMI 1.8m
        (2,   50000),    -- Cable UTP Cat5e        (corrige 10.000 de prueba)
        (21, 120000),    -- Control para PC USB
        (16, 100000),    -- Control Sony DualShock (no tenía costo)
        (1,  250000),    -- Disco SSD ASUS 240 GB
        (30, 200000),    -- Gabinete ATX Mid Tower (corrige 15.000 de prueba)
        (15,  80000),    -- Mouse AD Bluetooth     (corrige Gs 3 de prueba)
        (4,   80000),    -- Mouse Inalámbrico HP
        (24,  95000),    -- Mouse Logitech M170
        (39,  50000),    -- Pad Mouse XL Gaming
        (10,  35000),    -- Pendrive USB 32 GB HP  (toma el mayor)
        (11, 850000),    -- Procesador Intel i5-10400 (corrige 200.000; valor real)
        (17, 500000),    -- Proyector HD
        (9,  100000),    -- Teclado Mecánico Gaming
        (14, 200000);    -- Webcam Full HD 1080p

    -- ── Aplicar a TODAS las tiendas ──────────────────────────────────────────────
    UPDATE pt
        SET pt.CostoPromedio      = r.CostoRef,
            pt.PrecioUnidadCompra = r.CostoRef
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN @Ref r ON r.IdProducto = pt.IdProducto
    WHERE pt.Activo = 1;

    PRINT '>> Precios de referencia aplicados. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);

    COMMIT TRANSACTION;
    PRINT '════ Script 103 completado ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO

-- ── VERIFICACIÓN — costo uniforme por producto (debe dar 0 filas) ──────────────
SELECT p.Codigo, p.Nombre,
       MIN(pt.CostoPromedio) AS CostoMin, MAX(pt.CostoPromedio) AS CostoMax
FROM dbo.PRODUCTO_TIENDA pt
INNER JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
WHERE pt.Activo = 1
GROUP BY p.Codigo, p.Nombre
HAVING MIN(ISNULL(pt.CostoPromedio,0)) <> MAX(ISNULL(pt.CostoPromedio,0));
GO
