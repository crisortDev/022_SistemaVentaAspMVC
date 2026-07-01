-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 92: Cantidades decimales (coherencia con Unidad de Medida)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-29
--
-- MOTIVO:
--   Las categorías/productos ya tienen UnidadMedida (Metro, Kilo, Litro, etc.)
--   pero la Cantidad y el Stock son enteros (INT), por lo que no se puede
--   comprar/vender 1,5 m ni 0,250 kg. Este script pasa esas columnas a
--   DECIMAL(18,3) — hasta 3 decimales.
--
-- CARACTERÍSTICAS:
--   - Idempotente: verifica el tipo actual antes de alterar (se puede correr 2 veces).
--   - Defensivo: sólo altera columnas/tablas que existen (no falla si un nombre cambió).
--   - Transaccional: si algo falla, hace ROLLBACK y no deja cambios a medias.
--   - NO borra datos. Pasar de INT a DECIMAL es una ampliación segura.
--
-- ⚠️ HACER BACKUP DE LA BASE ANTES DE EJECUTAR.
--
-- DESPUÉS DE ESTE SCRIPT (ver sección final "PASO 2"):
--   Hay que actualizar los procedimientos que leen la cantidad del XML con
--   value('(Cantidad)[1]','INT')  →  'DECIMAL(18,3)'  y los modelos C# (int→decimal).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @sql NVARCHAR(MAX);

    -- Lista (Tabla, Columna) candidatas a pasar a DECIMAL(18,3).
    -- Se incluyen nombres alternativos por si difieren; sólo se alteran los que existan.
    DECLARE @objetivos TABLE (Tabla SYSNAME, Columna SYSNAME);
    INSERT INTO @objetivos (Tabla, Columna) VALUES
        ('DETALLE_VENTA',          'Cantidad'),
        ('DETALLE_ORDEN_VENTA',    'Cantidad'),
        ('DetalleOrdenCompra',     'Cantidad'),
        ('DetalleOrdenCompra',     'CantidadFacturada'),
        ('DETALLE_COMPRA',         'Cantidad'),
        ('DetalleCompra',          'Cantidad'),
        ('DETALLE_NOTA_CREDITO',         'Cantidad'),
        ('DETALLE_NOTA_CREDITO_VENTA',   'Cantidad'),
        ('DETALLE_NOTA_CREDITO_COMPRA',  'Cantidad'),
        ('DetalleNotaCredito',           'Cantidad'),
        ('DetalleNotaCreditoVenta',      'Cantidad'),
        ('DetalleNotaCreditoCompra',     'Cantidad'),
        ('LineaRecepcionOC',       'Cantidad'),
        ('PRODUCTO_TIENDA',        'Stock'),
        ('PRODUCTO_TIENDA',        'StockMinimo'),
        ('PRODUCTO_TIENDA',        'StockMaximo'),
        ('PRODUCTO',               'StockMaximo');

    DECLARE @Tabla SYSNAME, @Columna SYSNAME, @TipoActual SYSNAME, @Nullable BIT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT Tabla, Columna FROM @objetivos;
    OPEN cur;
    FETCH NEXT FROM cur INTO @Tabla, @Columna;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @TipoActual = TYPE_NAME(c.system_type_id),
            @Nullable   = c.is_nullable
        FROM sys.columns c
        WHERE c.object_id = OBJECT_ID('dbo.' + @Tabla)
          AND c.name      = @Columna;

        IF @TipoActual IS NULL
        BEGIN
            PRINT '  (omitido) dbo.' + @Tabla + '.' + @Columna + ' no existe.';
        END
        ELSE IF @TipoActual = 'decimal' OR @TipoActual = 'numeric'
        BEGIN
            PRINT '  (ok)      dbo.' + @Tabla + '.' + @Columna + ' ya es ' + @TipoActual + '.';
        END
        ELSE
        BEGIN
            SET @sql = 'ALTER TABLE dbo.' + QUOTENAME(@Tabla) +
                       ' ALTER COLUMN ' + QUOTENAME(@Columna) + ' DECIMAL(18,3) ' +
                       CASE WHEN @Nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END + ';';
            EXEC sp_executesql @sql;
            PRINT '  >> CAMBIADO  dbo.' + @Tabla + '.' + @Columna +
                  ' (' + @TipoActual + ' -> decimal(18,3)).';
        END

        SET @TipoActual = NULL;
        FETCH NEXT FROM cur INTO @Tabla, @Columna;
    END

    CLOSE cur;
    DEALLOCATE cur;

    COMMIT TRANSACTION;
    PRINT '════ Script 92 (columnas) completado correctamente. ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: no se aplicó ningún cambio.';
END CATCH;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2 (manual): actualizar procedimientos que parsean la cantidad del XML.
-- En estos SP, reemplazar  value('(Cantidad)[1]','INT')  por  'DECIMAL(18,3)':
--   - usp_RegistrarOrdenVenta            (script 89)
--   - usp_RegistrarOrdenCompra           (script 91b)
--   - usp_FacturarDesdeOrdenVenta        (script 89)  -> ya usa SUM sobre d.Cantidad, ok
--   - usp_RegistrarVenta / usp_RegistrarCompra (si existen, revisar)
--   - SPs de Nota de Crédito que reciban cantidad por XML
-- Avisar para generar el script 93 con esos CREATE OR ALTER ya hechos.
--
-- PASO 3 (manual, C#): en CapaModelo cambiar  public int Cantidad  ->  public decimal Cantidad
--   (DetalleVenta, DetalleOrdenCompra, DetalleCompra, NotaCredito*, etc.) y Stock.
--   En las vistas: <input type="number" step="0.001" ...> para la cantidad.
-- ════════════════════════════════════════════════════════════════════════════════

-- ─── Verificación: tipos actuales de las columnas de cantidad/stock ──────────────
SELECT  t.name AS Tabla, c.name AS Columna,
        TYPE_NAME(c.system_type_id) AS Tipo, c.scale AS Decimales, c.is_nullable
FROM sys.columns c
JOIN sys.tables  t ON t.object_id = c.object_id
WHERE c.name IN ('Cantidad','CantidadFacturada','Stock','StockMinimo','StockMaximo')
ORDER BY t.name, c.name;
GO
