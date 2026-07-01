-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 32: Renombrar productos de prueba con nombres reales
--            y reactivarlos para tener un catálogo completo
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- IdProducto 11  → era "Producto Test"  (IdCategoria 1 - HARDWARE)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Procesador Intel Core i5-10400',
    Descripcion = 'Procesador Intel Core i5-10400 6 núcleos 12 hilos, 2.9 GHz base, 4.3 GHz turbo, socket LGA1200',
    IdCategoria = 8,   -- PROCESADORES (CPU)
    Activo      = 1
WHERE IdProducto = 11;

-- IdProducto 13  → era "asdsds"  (IdCategoria 2 - Cables)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Cable de Red RJ45 Cat6 3m',
    Descripcion = 'Cable de red UTP categoría 6 de 3 metros, velocidad hasta 1 Gbps, conectores RJ45 blindados',
    IdCategoria = 20,  -- CABLES Y ADAPTADORES
    Activo      = 1
WHERE IdProducto = 13;

-- IdProducto 14  → era "test test"  (IdCategoria 3 - PERIFÉRICOS)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Webcam Full HD 1080p',
    Descripcion = 'Cámara web Full HD 1080p con micrófono integrado, conexión USB, compatible con Zoom, Teams y Meet',
    IdCategoria = 3,   -- PERIFÉRICOS
    Activo      = 1
WHERE IdProducto = 14;

-- IdProducto 22  → era "ddfdfdsf"  (IdCategoria 4 - ALMACENAMIENTO)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Disco Duro HDD 1 TB Seagate',
    Descripcion = 'Disco duro interno Seagate Barracuda 1 TB, 7200 RPM, SATA III, caché 64 MB',
    IdCategoria = 12,  -- DISCOS DUROS (HDD)
    Activo      = 1
WHERE IdProducto = 22;

-- IdProducto 28  → era "test"  (IdCategoria 1 - HARDWARE)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Fuente de Poder 600W Corsair',
    Descripcion = 'Fuente de poder Corsair 600W certificación 80 Plus Bronze, modular, ventilador 120mm silencioso',
    IdCategoria = 14,  -- FUENTES DE PODER
    Activo      = 1
WHERE IdProducto = 28;

-- IdProducto 30  → era "new"  (IdCategoria 1 - HARDWARE)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Gabinete ATX Mid Tower',
    Descripcion = 'Gabinete mid tower con panel lateral de vidrio templado, 2 ventiladores incluidos, soporte ATX/mATX',
    IdCategoria = 15,  -- GABINETES
    Activo      = 1
WHERE IdProducto = 30;

-- IdProducto 31  → era "ASDF"  (IdCategoria 1 - HARDWARE)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Tarjeta de Video NVIDIA GTX 1650',
    Descripcion = 'GPU NVIDIA GeForce GTX 1650 4 GB GDDR6, PCIe 3.0, salidas HDMI y DisplayPort, bajo consumo energético',
    IdCategoria = 11,  -- TARJETAS DE VIDEO (GPU)
    Activo      = 1
WHERE IdProducto = 31;

-- IdProducto 39  → era "sfds"  (IdCategoria 26 - ACCESORIOS)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Pad Mouse XL Gaming',
    Descripcion = 'Mousepad XL gaming 800x300 mm, superficie de tela de alta velocidad, base antideslizante de goma',
    IdCategoria = 16,  -- TECLADOS Y MOUSE
    Activo      = 1
WHERE IdProducto = 39;

-- IdProducto 40  → era "dfdfefwfew"  (IdCategoria 26 - ACCESORIOS)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Hub USB 3.0 de 4 Puertos',
    Descripcion = 'Concentrador USB 3.0 de 4 puertos, velocidad de transferencia hasta 5 Gbps, compatible con Windows y macOS',
    IdCategoria = 26,  -- ACCESORIOS Y OTROS
    Activo      = 1
WHERE IdProducto = 40;

PRINT 'OK: 9 productos renombrados y reactivados.';
GO

-- ── Verificar resultado final ───────────────────────────────────────────────
SELECT p.IdProducto, p.Codigo, p.Nombre, c.Descripcion AS Categoria,
       CASE WHEN p.Activo = 1 THEN 'Activo' ELSE 'Inactivo' END AS Estado
  FROM dbo.PRODUCTO p
  LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
 WHERE p.Codigo NOT LIKE 'TEST%'
 ORDER BY p.Nombre;
GO
