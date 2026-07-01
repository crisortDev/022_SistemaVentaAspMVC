-- ════════════════════════════════════════════════════════════════════════════════
-- Script 139 — Demo: Rellena DETALLE_INVENTARIO con StockContado = StockSistema
--              (sin diferencias) para el último inventario activo.
--
-- Uso: ejecutar para poblar un inventario de demo donde todo coincide.
-- Luego el supervisor puede aprobarlo para ver el flujo completo.
-- ════════════════════════════════════════════════════════════════════════════════
USE [DBVENTAS_WEB]
GO

DECLARE @IdInventario INT;
DECLARE @IdTienda     INT;
DECLARE @Estado       VARCHAR(50);

-- Tomar el inventario más reciente que esté en un estado modificable
SELECT TOP 1
    @IdInventario = IdInventario,
    @IdTienda     = IdTienda,
    @Estado       = Estado
FROM dbo.INVENTARIO
WHERE Estado IN ('Abierto', 'En Progreso', 'En Corrección', 'Rechazado', 'Pendiente de Aprobación')
ORDER BY IdInventario DESC;

IF @IdInventario IS NULL
BEGIN
    PRINT 'ERROR: No hay inventarios activos para poblar.';
    RETURN;
END

PRINT 'Inventario: ' + CAST(@IdInventario AS VARCHAR) + ' | Tienda: ' + CAST(@IdTienda AS VARCHAR) + ' | Estado: ' + @Estado;

BEGIN TRY
    BEGIN TRAN;

    -- Limpiar detalle anterior
    DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;
    PRINT 'Detalle anterior eliminado.';

    -- Insertar TODOS los productos de la sucursal con StockContado = Stock actual → Diferencia = 0
    INSERT INTO dbo.DETALLE_INVENTARIO
        (IdInventario, IdProducto, IdProductoTienda, StockSistema, StockContado, Diferencia)
    SELECT
        @IdInventario,
        pt.IdProducto,
        pt.IdProductoTienda,
        ISNULL(pt.Stock, 0),      -- StockSistema
        ISNULL(pt.Stock, 0),      -- StockContado = mismo valor → sin diferencia
        0                          -- Diferencia = 0
    FROM dbo.PRODUCTO_TIENDA pt
    WHERE pt.IdTienda = @IdTienda;

    DECLARE @Filas INT = @@ROWCOUNT;
    PRINT 'Productos insertados: ' + CAST(@Filas AS VARCHAR);

    -- Asegurarse de que el estado quede en Pendiente de Aprobación
    UPDATE dbo.INVENTARIO
       SET Estado             = 'Pendiente de Aprobación',
           FechaFinalizacion  = GETDATE()
     WHERE IdInventario = @IdInventario;

    PRINT 'Estado actualizado a: Pendiente de Aprobación';
    COMMIT;
    PRINT 'OK — El inventario ' + CAST(@IdInventario AS VARCHAR) + ' queda con ' + CAST(@Filas AS VARCHAR) + ' productos sin diferencias, listo para aprobar.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO
