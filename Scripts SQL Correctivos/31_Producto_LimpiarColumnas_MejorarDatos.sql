-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 31: Limpieza de columnas obsoletas de PRODUCTO y mejora de datos
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- Cambios:
--   1. DROP columna IdIva  (nunca usada en código C#)
--   2. DROP columna PrecioVenta (legacy; los precios se gestionan vía
--      tabla PRECIO_VENTA y PRODUCTO_TIENDA.PrecioUnidadVenta)
--   3. Actualizar usp_RegistrarProducto (quitar PrecioVenta del INSERT)
--   4. Mejorar nombres, descripciones y categorías de productos reales
--   5. Desactivar registros de prueba
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Eliminar FK / DEFAULT constraint de IdIva si existe ─────────────────
DECLARE @constraint NVARCHAR(200);

SELECT @constraint = dc.name
  FROM sys.default_constraints dc
 INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id
                          AND dc.parent_column_id = c.column_id
 WHERE c.object_id = OBJECT_ID('dbo.PRODUCTO')
   AND c.name      = 'IdIva';

IF @constraint IS NOT NULL
    EXEC('ALTER TABLE dbo.PRODUCTO DROP CONSTRAINT ' + @constraint);

-- FK hacia tabla IVA (si existe)
SELECT @constraint = fk.name
  FROM sys.foreign_keys fk
 INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
 INNER JOIN sys.columns c ON fkc.parent_object_id = c.object_id
                          AND fkc.parent_column_id = c.column_id
 WHERE c.object_id = OBJECT_ID('dbo.PRODUCTO')
   AND c.name      = 'IdIva';

IF @constraint IS NOT NULL
    EXEC('ALTER TABLE dbo.PRODUCTO DROP CONSTRAINT ' + @constraint);
GO

-- DROP IdIva
IF EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID('dbo.PRODUCTO') AND name = 'IdIva'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO DROP COLUMN IdIva;
    PRINT 'OK: Columna IdIva eliminada de PRODUCTO.';
END
ELSE
    PRINT 'INFO: Columna IdIva no existe, nada que hacer.';
GO

-- ── 2. Eliminar DEFAULT constraint de PrecioVenta si existe ────────────────
DECLARE @constraint NVARCHAR(200);

SELECT @constraint = dc.name
  FROM sys.default_constraints dc
 INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id
                          AND dc.parent_column_id = c.column_id
 WHERE c.object_id = OBJECT_ID('dbo.PRODUCTO')
   AND c.name      = 'PrecioVenta';

IF @constraint IS NOT NULL
    EXEC('ALTER TABLE dbo.PRODUCTO DROP CONSTRAINT ' + @constraint);
GO

-- DROP PrecioVenta
IF EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID('dbo.PRODUCTO') AND name = 'PrecioVenta'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO DROP COLUMN PrecioVenta;
    PRINT 'OK: Columna PrecioVenta eliminada de PRODUCTO.';
END
ELSE
    PRINT 'INFO: Columna PrecioVenta no existe, nada que hacer.';
GO

-- ── 3. usp_RegistrarProducto — sin PrecioVenta en el INSERT ────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarProducto]
    @Nombre        NVARCHAR(200),
    @Descripcion   NVARCHAR(500),
    @IdCategoria   INT,
    @IvaPorcentaje DECIMAL(5,2) = 10,
    @StockMaximo   INT          = 0,
    @Resultado     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM dbo.PRODUCTO
             WHERE LTRIM(RTRIM(Nombre)) = LTRIM(RTRIM(@Nombre))
        )
        BEGIN
            SET @Resultado = 0; RETURN;
        END

        DECLARE @ValorCodigo INT;
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1
          FROM dbo.PRODUCTO
         WHERE TRY_CAST(ValorCodigo AS INT) IS NOT NULL;  -- ignora TEST-OC-PROD

        DECLARE @Codigo NVARCHAR(20) = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);

        INSERT INTO dbo.PRODUCTO
            (Codigo, ValorCodigo, Nombre, Descripcion, IdCategoria,
             IvaPorcentaje, StockMaximo, Activo, FechaRegistro)
        VALUES
            (@Codigo, @ValorCodigo, @Nombre, @Descripcion, @IdCategoria,
             @IvaPorcentaje, @StockMaximo, 1, GETDATE());

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarProducto actualizado (sin PrecioVenta).';
GO

-- ── 4. usp_ObtenerProductos — asegurarse que no trae columnas eliminadas ───
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductos]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.IdProducto,
        p.Codigo,
        p.ValorCodigo,
        p.Nombre,
        p.Descripcion    AS DescripcionProducto,
        p.IdCategoria,
        c.Descripcion    AS DescripcionCategoria,
        p.IvaPorcentaje,
        p.StockMaximo,
        p.Activo
      FROM dbo.PRODUCTO p
      LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
     ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductos verificado.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. MEJORAR DATOS DE PRODUCTOS REALES
--    Nombre, Descripción y Categoría correcta
-- ══════════════════════════════════════════════════════════════════════════════

-- Disco SSD ASUS 240 GB → categoría UNIDADES SSD (13)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Disco SSD ASUS 240 GB',
    Descripcion = 'Unidad de estado sólido ASUS 240 GB, interfaz SATA III, velocidad lectura 500 MB/s',
    IdCategoria = 13
WHERE IdProducto = 1;

-- Cable UTP → categoría CABLES Y ADAPTADORES (20)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Cable UTP Cat5e',
    Descripcion = 'Cable de red UTP categoría 5e para conexiones RJ45, 1 metro',
    IdCategoria = 20
WHERE IdProducto = 2;

-- Mouse Inalámbrico HP → categoría TECLADOS Y MOUSE (16)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Mouse Inalámbrico HP',
    Descripcion = 'Mouse inalámbrico HP con tecnología Bluetooth, 1600 DPI, batería AAA',
    IdCategoria = 16
WHERE IdProducto = 4;

-- Disco Externo SSD 1 TB → categoría UNIDADES SSD (13)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Disco Externo SSD 1 TB',
    Descripcion = 'Disco externo de estado sólido 1 TB, conexión USB 3.1, velocidad hasta 540 MB/s',
    IdCategoria = 13
WHERE IdProducto = 5;

-- Memoria Ram DDR3 → categoría MEMORIAS RAM (10)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Memoria RAM DDR3 8 GB',
    Descripcion = 'Módulo de memoria RAM DDR3 8 GB 1600 MHz, compatible con plataformas Intel y AMD',
    IdCategoria = 10
WHERE IdProducto = 6;

-- Placa madre ASUS ROG → categoría PLACAS MADRE (9)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Placa Madre ASUS ROG Maximus XIII Hero Z590',
    Descripcion = 'Placa madre gaming ATX socket LGA1200, chipset Z590, soporte PCIe 4.0 y DDR4',
    IdCategoria = 9
WHERE IdProducto = 7;

-- Mouse Alambrico → categoría TECLADOS Y MOUSE (16)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Mouse Alámbrico ASUS',
    Descripcion = 'Mouse alámbrico ASUS óptico USB, 1000 DPI, diseño ergonómico',
    IdCategoria = 16
WHERE IdProducto = 8;

-- Teclado Snapdragon → categoría TECLADOS Y MOUSE (16)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Teclado Mecánico Gaming',
    Descripcion = 'Teclado mecánico retroiluminado RGB, switches Blue, distribución español',
    IdCategoria = 16
WHERE IdProducto = 9;

-- USB 32 GB → categoría ALMACENAMIENTO / ACCESORIOS (26)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Pendrive USB 32 GB HP',
    Descripcion = 'Memoria USB 3.0 HP 32 GB, velocidad de lectura hasta 25 MB/s',
    IdCategoria = 26
WHERE IdProducto = 10;

-- Mouse AD → categoría TECLADOS Y MOUSE (16)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Mouse AD Bluetooth',
    Descripcion = 'Mouse inalámbrico con tecnología Bluetooth, batería recargable, 1200 DPI',
    IdCategoria = 16
WHERE IdProducto = 15;

-- Control sony → categoría PERIFÉRICOS (3)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Control Sony DualShock',
    Descripcion = 'Control PS4/PC Sony DualShock, conexión USB y Bluetooth',
    IdCategoria = 3
WHERE IdProducto = 16;

-- Proyector → categoría MONITORES (7)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Proyector HD',
    Descripcion = 'Proyector HD 1080p, 3500 lúmenes, conexión HDMI y VGA, ideal para presentaciones',
    IdCategoria = 7
WHERE IdProducto = 17;

-- Control para pc → categoría PERIFÉRICOS (3)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Control para PC USB',
    Descripcion = 'Control de juegos para PC conexión USB, compatible con Windows 10/11',
    IdCategoria = 3
WHERE IdProducto = 21;

-- Cable USB → categoría CABLES Y ADAPTADORES (20)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Cable USB Tipo C',
    Descripcion = 'Cable USB tipo C a USB-A, 1 metro, carga rápida 3A, transferencia de datos',
    IdCategoria = 20
WHERE IdProducto = 23;

-- Mouse Logitech → categoría TECLADOS Y MOUSE (16)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Mouse Logitech M170',
    Descripcion = 'Mouse inalámbrico Logitech M170, receptor nano USB, 1000 DPI, hasta 18 meses de batería',
    IdCategoria = 16
WHERE IdProducto = 24;

-- Monitor → categoría MONITORES (7)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Monitor LG 24"',
    Descripcion = 'Monitor LG IPS 24 pulgadas Full HD 1080p, 75 Hz, conexión HDMI y VGA',
    IdCategoria = 7
WHERE IdProducto = 25;

-- Notebook HP → categoría LAPTOPS Y NOTEBOOKS (5)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Notebook HP 15.6"',
    Descripcion = 'Laptop HP pantalla 15.6 pulgadas FHD, procesador Core i5, 8 GB RAM, 512 GB SSD',
    IdCategoria = 5
WHERE IdProducto = 26;

-- Cable genérico → categoría CABLES Y ADAPTADORES (20)
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Cable HDMI 1.8m',
    Descripcion = 'Cable HDMI 2.0 de 1.8 metros, soporte 4K 60 Hz, conectores dorados',
    IdCategoria = 20
WHERE IdProducto = 27;

-- Auricular XIAMI → categoría AURICULARES Y HEADSETS (17), ya está bien
UPDATE dbo.PRODUCTO SET
    Nombre      = 'Auricular Xiaomi Tipo C',
    Descripcion = 'Auriculares in-ear Xiaomi con conector USB tipo C, micrófono integrado, cancelación de ruido',
    IdCategoria = 17
WHERE IdProducto = 38;

-- ── 6. Desactivar productos de prueba ──────────────────────────────────────
UPDATE dbo.PRODUCTO
   SET Activo = 0
 WHERE IdProducto IN (11, 13, 14, 22, 28, 30, 31, 39, 40);
-- IdProducto 11 = Producto Test
-- IdProducto 13 = asdsds
-- IdProducto 14 = test test
-- IdProducto 22 = ddfdfdsf
-- IdProducto 28 = test
-- IdProducto 30 = new
-- IdProducto 31 = ASDF
-- IdProducto 39 = sfds
-- IdProducto 40 = dfdfefwfew

PRINT 'OK: Productos de prueba desactivados.';
GO

-- ── 7. Diagnóstico final ───────────────────────────────────────────────────
SELECT p.IdProducto, p.Codigo, p.Nombre, p.Descripcion,
       c.Descripcion AS Categoria,
       p.IvaPorcentaje, p.StockMaximo,
       CASE WHEN p.Activo = 1 THEN 'Activo' ELSE 'Inactivo' END AS Estado
  FROM dbo.PRODUCTO p
  LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
 ORDER BY p.Activo DESC, p.Nombre;
GO
