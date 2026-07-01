-- ============================================================
-- Script 66: Limpieza y mejora de la tabla CLIENTE
-- Fecha: 2026-05-19
--
-- 1. Elimina FK y columna IdPersona (relación huérfana)
-- 2. Elimina columna FechaBaja (no utilizada en el sistema)
-- 3. Corrige cliente 18 (datos mezclados en columnas)
-- 4. Completa datos NULL de clientes 22-26
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ────────────────────────────────────────────────────────────
-- 1. QUITAR FK con tabla PERSONA (si existe)
-- ────────────────────────────────────────────────────────────
DECLARE @fkName NVARCHAR(200);

SELECT @fkName = fk.name
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.columns c ON fkc.parent_object_id = c.object_id
    AND fkc.parent_column_id = c.column_id
WHERE OBJECT_NAME(fk.parent_object_id) = 'CLIENTE'
  AND c.name = 'IdPersona';

IF @fkName IS NOT NULL
BEGIN
    EXEC('ALTER TABLE dbo.CLIENTE DROP CONSTRAINT ' + @fkName);
    PRINT 'FK eliminada: ' + @fkName;
END
ELSE
    PRINT 'No existe FK en IdPersona (ya fue eliminada o nunca existió con constraint).';
GO

-- ────────────────────────────────────────────────────────────
-- 2. ELIMINAR columna IdPersona
-- ────────────────────────────────────────────────────────────
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'IdPersona'
)
BEGIN
    ALTER TABLE dbo.CLIENTE DROP COLUMN IdPersona;
    PRINT 'Columna IdPersona eliminada.';
END
ELSE
    PRINT 'Columna IdPersona ya no existe.';
GO

-- ────────────────────────────────────────────────────────────
-- 3. ELIMINAR columna FechaBaja
-- ────────────────────────────────────────────────────────────
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'FechaBaja'
)
BEGIN
    ALTER TABLE dbo.CLIENTE DROP COLUMN FechaBaja;
    PRINT 'Columna FechaBaja eliminada.';
END
ELSE
    PRINT 'Columna FechaBaja ya no existe.';
GO

-- ────────────────────────────────────────────────────────────
-- 4. CORREGIR cliente 18 (campos mezclados)
--    NumeroDocumento tenía 'Pepito' y Nombre tenía 'Lopez'
-- ────────────────────────────────────────────────────────────
UPDATE dbo.CLIENTE SET
    TipoDocumento   = 'CI',
    NumeroDocumento = '5112345',
    Nombre          = 'Pepito Lopez',
    Direccion       = 'San Lorenzo, Calle Victoria',
    Telefono        = '0976564543',
    Ciudad          = 'San Lorenzo',
    Barrio          = 'Centro',
    Calle           = 'Victoria',
    NumeroCasa      = '150',
    Referencia      = 'Frente a la plaza principal',
    Geolocalizacion = '-25.3396,-57.5086'
WHERE IdCliente = 18;
PRINT 'Cliente 18 corregido.';
GO

-- ────────────────────────────────────────────────────────────
-- 5. COMPLETAR datos NULL — clientes 22 al 26
-- ────────────────────────────────────────────────────────────

-- IdCliente 22: María González
UPDATE dbo.CLIENTE SET
    Ciudad          = 'Asunción',
    Barrio          = 'Villa Morra',
    Calle           = 'España',
    NumeroCasa      = '1234',
    Referencia      = 'Frente al supermercado Stock',
    Geolocalizacion = '-25.2897,-57.5759'
WHERE IdCliente = 22;

-- IdCliente 23: Roberto Aquino
UPDATE dbo.CLIENTE SET
    Ciudad          = 'Fernando de la Mora',
    Barrio          = 'Centro',
    Calle           = '3 de Febrero',
    NumeroCasa      = '567',
    Referencia      = 'A una cuadra de la municipalidad',
    Geolocalizacion = '-25.3394,-57.5218'
WHERE IdCliente = 23;

-- IdCliente 24: TechSolutions S.A.
UPDATE dbo.CLIENTE SET
    Ciudad          = 'Asunción',
    Barrio          = 'Recoleta',
    Calle           = 'Mcal. López',
    NumeroCasa      = '890',
    Referencia      = 'Edificio Torres del Lago, piso 3',
    Geolocalizacion = '-25.2790,-57.5730'
WHERE IdCliente = 24;

-- IdCliente 25: Ana Ramírez
UPDATE dbo.CLIENTE SET
    Ciudad          = 'Luque',
    Barrio          = 'San José',
    Calle           = 'Ytororó',
    NumeroCasa      = '234',
    Referencia      = 'Casa de rejas verdes',
    Geolocalizacion = '-25.2637,-57.4869'
WHERE IdCliente = 25;

-- IdCliente 26: Consumidor Final
UPDATE dbo.CLIENTE SET
    Ciudad          = 'Asunción',
    Barrio          = '-',
    Calle           = '-',
    NumeroCasa      = '-',
    Referencia      = 'Cliente genérico para ventas sin identificar',
    Geolocalizacion = NULL
WHERE IdCliente = 26;

PRINT 'Datos de clientes 22-26 completados.';
GO

PRINT '════ Script 66 completado ════';
GO
