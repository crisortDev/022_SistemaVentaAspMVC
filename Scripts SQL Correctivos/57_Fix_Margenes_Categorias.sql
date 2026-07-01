-- ============================================================
-- Script 57: Corrección de márgenes de ganancia por categoría
-- Fecha: 2026-05-18
--
-- Problemas detectados:
--   - ALMACENAMIENTO:          0.02%  → error decimal, debía ser 20%
--   - Cables (vieja):          0.00%  → sin margen, corregir a 35%
--   - PERIFÉRICOS:             1.00%  → demasiado bajo, corregir a 30%
--   - HARWARE DE COMPUTADORAS: 1.00%  → demasiado bajo, corregir a 15%
--   - CABLES Y ADAPTADORES:   50.00%  → un poco alto, ajustar a 40%
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── Correcciones de márgenes ──────────────────────────────────────────────────

UPDATE dbo.CATEGORIA SET PorcentajeGanancia = 20.00 WHERE IdCategoria = 4;   -- ALMACENAMIENTO (era 0.02 — error decimal)
UPDATE dbo.CATEGORIA SET PorcentajeGanancia = 35.00 WHERE IdCategoria = 2;   -- Cables (era 0.00)
UPDATE dbo.CATEGORIA SET PorcentajeGanancia = 30.00 WHERE IdCategoria = 3;   -- PERIFÉRICOS (era 1.00)
UPDATE dbo.CATEGORIA SET PorcentajeGanancia = 15.00 WHERE IdCategoria = 1;   -- HARWARE DE COMPUTADORAS (era 1.00)
UPDATE dbo.CATEGORIA SET PorcentajeGanancia = 40.00 WHERE IdCategoria = 20;  -- CABLES Y ADAPTADORES (era 50.00)

GO

-- ── Verificación: tabla completa con precios sugeridos de ejemplo ─────────────
SELECT
    c.IdCategoria,
    c.Descripcion,
    c.PorcentajeGanancia                                            AS [Margen %],
    COUNT(p.IdProducto)                                             AS [Productos],
    AVG(pt.PrecioUnidadCompra)                                      AS [Costo Prom.],
    AVG(CEILING(
        pt.PrecioUnidadCompra
        * (1.0 + p.IvaPorcentaje / 100.0)
        * (1.0 + c.PorcentajeGanancia / 100.0)
    ))                                                              AS [Precio Sugerido Prom.]
FROM dbo.CATEGORIA c
LEFT JOIN dbo.PRODUCTO p        ON p.IdCategoria = c.IdCategoria AND p.Activo = 1
LEFT JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = p.IdProducto  AND pt.Activo = 1
WHERE c.Activo = 1
GROUP BY c.IdCategoria, c.Descripcion, c.PorcentajeGanancia
ORDER BY c.Descripcion;
GO
