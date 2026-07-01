-- =====================================================================
-- 141 · Anulación de inventario + mensaje de concurrencia mejorado
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1. usp_AnularInventario  (nuevo)
-- ─────────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_AnularInventario
    @IdInventario     INT,
    @IdUsuarioAnula   INT,
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(50);
    SELECT @EstadoActual = Estado
    FROM dbo.INVENTARIO
    WHERE IdInventario = @IdInventario;

    IF @EstadoActual IS NULL
    BEGIN
        SET @Resultado = 0;
        SET @Mensaje   = 'No se encontró el inventario.';
        RETURN;
    END

    IF @EstadoActual = 'Aprobado'
    BEGIN
        SET @Resultado = 0;
        SET @Mensaje   = 'No se puede anular un inventario ya aprobado.';
        RETURN;
    END

    IF @EstadoActual = 'Anulado'
    BEGIN
        SET @Resultado = 0;
        SET @Mensaje   = 'El inventario ya está anulado.';
        RETURN;
    END

    UPDATE dbo.INVENTARIO
    SET Estado           = 'Anulado',
        IdUsuarioAprueba = @IdUsuarioAnula,
        FechaAprobacion  = GETDATE(),
        MotivoRechazo    = 'Anulado manualmente por el supervisor.'
    WHERE IdInventario = @IdInventario;

    SET @Resultado = 1;
    SET @Mensaje   = 'Inventario anulado correctamente.';
END
GO
PRINT 'OK: usp_AnularInventario';
GO

-- ─────────────────────────────────────────────────────────────────────
-- 2. usp_FinalizarConteoInventario  (mejora mensaje de concurrencia)
--    Mismo SP del script 137, con mensaje más claro cuando otro
--    repositor ya cerró el inventario primero.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_FinalizarConteoInventario
    @IdInventario  INT,
    @IdOperador    INT,
    @DetalleXml    XML,
    @Observacion   VARCHAR(500) = NULL,
    @Resultado     BIT          OUTPUT,
    @Mensaje       NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Estado VARCHAR(30), @IdTienda INT;
        SELECT @Estado = Estado, @IdTienda = IdTienda
        FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; ROLLBACK; RETURN; END

        -- Control de concurrencia: si otro repositor ya finalizó, estado ya no es En Progreso/En Corrección
        IF @Estado NOT IN ('En Progreso', 'En Corrección')
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = CASE
                WHEN @Estado = 'Pendiente de Aprobación'
                    THEN 'Este inventario ya fue cerrado por otro repositor. No podés guardar.'
                WHEN @Estado = 'Aprobado'
                    THEN 'Este inventario ya fue aprobado. No se puede modificar.'
                WHEN @Estado = 'Anulado'
                    THEN 'Este inventario fue anulado. No se puede finalizar.'
                ELSE 'Estado inválido para finalizar: ' + @Estado
            END;
            ROLLBACK; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION
                       WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
        BEGIN SET @Resultado=0; SET @Mensaje='No tiene permiso sobre este inventario.'; ROLLBACK; RETURN; END

        -- Limpiar detalle anterior
        DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;

        -- Insertar detalle desde XML capturando StockSistema actual
        INSERT INTO dbo.DETALLE_INVENTARIO
            (IdInventario, IdProducto, IdProductoTienda, StockSistema, StockContado, Diferencia)
        SELECT
            @IdInventario,
            x.IdProducto,
            pt.IdProductoTienda,
            ISNULL(pt.Stock, 0),
            x.CantidadContada,
            x.CantidadContada - ISNULL(pt.Stock, 0)
        FROM (
            SELECT
                r.n.value('IdProducto[1]',      'INT') AS IdProducto,
                r.n.value('CantidadContada[1]', 'INT') AS CantidadContada
            FROM @DetalleXml.nodes('/Detalle/Item') AS r(n)
        ) x
        JOIN dbo.PRODUCTO_TIENDA pt
            ON pt.IdProducto = x.IdProducto AND pt.IdTienda = @IdTienda;

        IF @@ROWCOUNT = 0
        BEGIN SET @Resultado=0; SET @Mensaje='No se procesaron productos. Verifique el detalle.'; ROLLBACK; RETURN; END

        UPDATE dbo.INVENTARIO
           SET Estado            = 'Pendiente de Aprobación',
               FechaFinalizacion = GETDATE(),
               Observacion       = ISNULL(NULLIF(@Observacion,''), Observacion)
         WHERE IdInventario = @IdInventario;

        SET @Resultado=1; SET @Mensaje='Conteo finalizado. El supervisor lo revisará para aprobación.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_FinalizarConteoInventario (con control de concurrencia)';
GO
