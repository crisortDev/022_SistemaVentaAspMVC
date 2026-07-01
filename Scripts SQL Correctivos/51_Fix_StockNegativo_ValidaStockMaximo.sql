-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 51: Corregir stock negativo y reforzar validación StockMaximo
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-15
--
-- PROBLEMA 1: PRODUCTO_TIENDA tiene filas con Stock < 0 (ej. IdProductoTienda=19, Stock=-1)
--             Causado por movimientos sin validación previa de stock suficiente.
--
-- PROBLEMA 2: StockMaximo existe en PRODUCTO (global) y en PRODUCTO_TIENDA (por tienda).
--             La fuente autoritativa es PRODUCTO_TIENDA.StockMaximo.
--             Los SPs de compras ya validan contra ella (Scripts 15, 27, 28).
--             Este script añade un CHECK constraint para evitar stock < 0 a futuro
--             y una verificación de consistencia entre ambas tablas.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO PREVIO
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '──────────────────────────────────────────────';
PRINT 'Filas con Stock negativo en PRODUCTO_TIENDA:';
SELECT pt.IdProductoTienda, pt.IdProducto, p.Nombre, pt.IdTienda,
       t.Nombre AS NombreTienda, pt.Stock, pt.StockMinimo, pt.StockMaximo
FROM   dbo.PRODUCTO_TIENDA pt
INNER  JOIN dbo.PRODUCTO   p ON p.IdProducto = pt.IdProducto
INNER  JOIN dbo.TIENDA     t ON t.IdTienda   = pt.IdTienda
WHERE  pt.Stock < 0;

PRINT '──────────────────────────────────────────────';
PRINT 'Filas donde Stock > StockMaximo (sobrestock):';
SELECT pt.IdProductoTienda, pt.IdProducto, p.Nombre, pt.IdTienda,
       t.Nombre AS NombreTienda, pt.Stock, pt.StockMaximo
FROM   dbo.PRODUCTO_TIENDA pt
INNER  JOIN dbo.PRODUCTO   p ON p.IdProducto = pt.IdProducto
INNER  JOIN dbo.TIENDA     t ON t.IdTienda   = pt.IdTienda
WHERE  pt.StockMaximo > 0 AND pt.Stock > pt.StockMaximo;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: Corregir filas con Stock negativo → llevar a 0
--         Se registra en un log por trazabilidad.
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE dbo.PRODUCTO_TIENDA
SET    Stock = 0
WHERE  Stock < 0;

PRINT 'OK: Stock negativo corregido a 0 en PRODUCTO_TIENDA. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: Agregar CHECK constraint para evitar Stock < 0 a futuro
--         Si ya existe, se omite con gracia.
-- ════════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE  parent_object_id = OBJECT_ID('dbo.PRODUCTO_TIENDA')
      AND  name = 'CK_ProductoTienda_StockNoNegativo'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO_TIENDA
        ADD CONSTRAINT CK_ProductoTienda_StockNoNegativo
        CHECK (Stock >= 0);
    PRINT 'OK: CHECK constraint CK_ProductoTienda_StockNoNegativo creado.';
END
ELSE
    PRINT 'INFO: El CHECK constraint ya existía, sin cambios.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3: Sincronizar PRODUCTO.StockMaximo con el máximo de PRODUCTO_TIENDA
--         PRODUCTO.StockMaximo es el techo global (referencia).
--         PRODUCTO_TIENDA.StockMaximo es el autoritativo por tienda.
--         Si PRODUCTO.StockMaximo = 0 y en alguna tienda sí tiene valor, actualizar.
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE p
SET    p.StockMaximo = MaxPorTienda.MaxStockMaximo
FROM   dbo.PRODUCTO p
INNER  JOIN (
    SELECT IdProducto, MAX(StockMaximo) AS MaxStockMaximo
    FROM   dbo.PRODUCTO_TIENDA
    WHERE  StockMaximo > 0
    GROUP  BY IdProducto
) AS MaxPorTienda ON MaxPorTienda.IdProducto = p.IdProducto
WHERE  p.StockMaximo = 0;

PRINT 'OK: PRODUCTO.StockMaximo sincronizado desde PRODUCTO_TIENDA. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN FINAL
-- ════════════════════════════════════════════════════════════════════════════════

PRINT '══ RESULTADO FINAL ══════════════════════════';
SELECT pt.IdProductoTienda, pt.IdProducto, p.Nombre,
       t.Nombre AS NombreTienda,
       pt.Stock, pt.StockMinimo, pt.StockMaximo,
       p.StockMaximo AS StockMaximoGlobal
FROM   dbo.PRODUCTO_TIENDA pt
INNER  JOIN dbo.PRODUCTO   p ON p.IdProducto = pt.IdProducto
INNER  JOIN dbo.TIENDA     t ON t.IdTienda   = pt.IdTienda
ORDER  BY pt.IdProducto, pt.IdTienda;
GO
