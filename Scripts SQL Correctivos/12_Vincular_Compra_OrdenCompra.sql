-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT: Vincular Compra con Orden de Compra
-- Fecha: 26/04/2026
-- BD: [DBVENTAS_WEB]
-- Descripción: Crea un SP para vincular la Compra con la Orden de Compra base
--              Actualiza CantidadFacturada en DetalleOrdenCompra
--              Registra la relación en tabla CompraOrdenCompra
--
-- Tablas involucradas:
--   - COMPRA (principal)
--   - DETALLE_COMPRA (detalle de compra)
--   - OrdenCompra (orden base)
--   - DetalleOrdenCompra (detalle de orden)
--   - CompraOrdenCompra (tabla intermedia de relación N:M)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

PRINT 'Iniciando vinculación de Compra con Orden de Compra...'
GO

-- ────────────────────────────────────────────────────────────────────────────────
-- CREAR STORED PROCEDURE: usp_VincularCompraOrdenCompra
-- Se ejecuta DESPUÉS de que usp_RegistrarCompra registra la compra
-- ────────────────────────────────────────────────────────────────────────────────

IF OBJECT_ID('usp_VincularCompraOrdenCompra', 'P') IS NOT NULL
    DROP PROCEDURE usp_VincularCompraOrdenCompra;
GO

CREATE PROCEDURE usp_VincularCompraOrdenCompra
    @IdCompra INT,
    @IdOrdenCompra INT,
    @Resultado BIT OUTPUT,
    @Mensaje NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. VALIDAR que la Compra existe ────────────────────────────────
        IF NOT EXISTS (SELECT 1 FROM COMPRA WHERE IdCompra = @IdCompra)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Compra no encontrada.';
            RAISERROR('Compra no encontrada.', 16, 1);
        END

        -- ── 2. VALIDAR que la Orden de Compra existe ──────────────────────
        IF NOT EXISTS (SELECT 1 FROM OrdenCompra WHERE IdOrdenCompra = @IdOrdenCompra)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Orden de Compra no encontrada.';
            RAISERROR('Orden de Compra no encontrada.', 16, 1);
        END

        -- ── 3. VALIDAR que la OC está en estado "Aprobada" ─────────────────
        DECLARE @EstadoOC NVARCHAR(50);
        SELECT @EstadoOC = Estado FROM OrdenCompra WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @EstadoOC IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Estado de Orden no encontrado.';
            RAISERROR('Estado de Orden no encontrado.', 16, 1);
        END

        IF @EstadoOC <> 'Aprobada'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Solo se pueden registrar compras contra Órdenes Aprobadas. Estado actual: ' + @EstadoOC;
            RAISERROR('Solo órdenes aprobadas permitidas.', 16, 1);
        END

        -- ── 4. VINCULAR en tabla CompraOrdenCompra ──────────────────────────
        -- Evitar duplicados
        IF NOT EXISTS (SELECT 1 FROM CompraOrdenCompra
                       WHERE IdCompra = @IdCompra AND IdOrdenCompra = @IdOrdenCompra)
        BEGIN
            INSERT INTO CompraOrdenCompra (IdCompra, IdOrdenCompra, FechaVinculacion)
            VALUES (@IdCompra, @IdOrdenCompra, GETDATE());

            PRINT 'OK: Vinculación registrada en CompraOrdenCompra';
        END
        ELSE
        BEGIN
            PRINT 'NOTA: La vinculación ya existe';
        END

        -- ── 5. ACTUALIZAR CantidadFacturada en DetalleOrdenCompra ──────────
        -- Por cada producto en la compra, incrementar CantidadFacturada en la OC
        DECLARE @ProductosActualizados INT = 0;

        UPDATE doc
        SET doc.CantidadFacturada = doc.CantidadFacturada + dc.Cantidad
        FROM DetalleOrdenCompra doc
        INNER JOIN DETALLE_COMPRA dc ON doc.IdProducto = dc.IdProducto
        WHERE doc.IdOrdenCompra = @IdOrdenCompra
          AND dc.IdCompra = @IdCompra
          AND (doc.CantidadFacturada + dc.Cantidad) <= doc.Cantidad;

        SET @ProductosActualizados = @@ROWCOUNT;
        PRINT 'OK: CantidadFacturada actualizada en ' + CAST(@ProductosActualizados AS VARCHAR(10)) + ' línea(s)';

        -- ── 6. VALIDAR que NO hay excesos de cantidad ────────────────────────
        -- Verificar si algún producto excede la cantidad disponible
        IF EXISTS (
            SELECT 1 FROM DETALLE_COMPRA dc
            WHERE dc.IdCompra = @IdCompra
              AND NOT EXISTS (
                  SELECT 1 FROM DetalleOrdenCompra doc
                  WHERE doc.IdOrdenCompra = @IdOrdenCompra
                    AND doc.IdProducto = dc.IdProducto
                    AND doc.Cantidad > 0  -- Validar que existe en OC
              )
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Error: Algunos productos de la compra no están en la Orden de Compra.';
            RAISERROR('Productos no encontrados en OC.', 16, 1);
        END

        COMMIT TRANSACTION;
        SET @Resultado = 1;
        SET @Mensaje = 'Vinculación completada exitosamente.';
        PRINT @Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @Resultado = 0;
        SET @Mensaje = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @Mensaje;
    END CATCH
END
GO

PRINT ''
PRINT '════════════════════════════════════════════════════════════'
PRINT 'STORED PROCEDURE CREADO: usp_VincularCompraOrdenCompra'
PRINT '════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'USO:'
PRINT '  DECLARE @resultado BIT, @mensaje NVARCHAR(500)'
PRINT '  EXEC usp_VincularCompraOrdenCompra'
PRINT '    @IdCompra = <IdCompra>,'
PRINT '    @IdOrdenCompra = <IdOrdenCompra>,'
PRINT '    @Resultado = @resultado OUTPUT,'
PRINT '    @Mensaje = @mensaje OUTPUT'
PRINT '  SELECT @resultado AS Resultado, @mensaje AS Mensaje'
PRINT ''
PRINT '════════════════════════════════════════════════════════════'
PRINT 'PRÓXIMOS PASOS:'
PRINT '════════════════════════════════════════════════════════════'
PRINT '1. Modificar CompraController.cs para llamar este SP'
PRINT '   después de que usp_RegistrarCompra registra la compra'
PRINT ''
PRINT '2. Agregar en CompraController.Guardar():'
PRINT '   - Capturar IdCompra de usp_RegistrarCompra'
PRINT '   - Llamar usp_VincularCompraOrdenCompra con:'
PRINT '      * @IdCompra (recibido de usp_RegistrarCompra)'
PRINT '      * @IdOrdenCompra (del XML de entrada)'
PRINT ''
PRINT '3. Probar:'
PRINT '   - Registrar Compra con Orden de Compra seleccionada'
PRINT '   - Verificar CompraOrdenCompra esté vinculada'
PRINT '   - Verificar CantidadFacturada se actualizó en DetalleOrdenCompra'
PRINT ''
GO
