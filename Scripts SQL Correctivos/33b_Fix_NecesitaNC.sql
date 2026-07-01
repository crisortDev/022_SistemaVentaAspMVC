-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 33b: Fix — agregar columna NecesitaNC a COMPRA
--             y recrear usp_RegistrarNotaCredito sin error de columna inválida.
-- Ejecutar DESPUÉS del Script 33.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Agregar columna NecesitaNC a COMPRA si no existe ──────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID('dbo.COMPRA')
       AND name      = 'NecesitaNC'
)
BEGIN
    ALTER TABLE dbo.COMPRA
        ADD NecesitaNC BIT NOT NULL DEFAULT 0;
    PRINT 'OK: Columna NecesitaNC agregada a COMPRA.';
END
ELSE
    PRINT 'INFO: Columna NecesitaNC ya existe en COMPRA.';
GO

-- ── 2. Recrear usp_RegistrarNotaCredito (ahora sin error de columna) ─────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarNotaCredito]
    @IdCompra         INT,
    @IdMotivoNC       INT,
    @IdUsuario        INT,
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(400) OUTPUT,
    @MontoNC          DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Calcular monto de la NC (diferencia entre pedido y recibido)
        SELECT @MontoNC = SUM(
                (ISNULL(dc.Cantidad, 0) - ISNULL(dc.CantidadRecibida, dc.Cantidad))
                * ISNULL(dc.PrecioUnitarioCompra, 0)
            )
          FROM dbo.DETALLE_COMPRA dc
         WHERE dc.IdCompra = @IdCompra
           AND dc.Activo   = 1;

        SET @MontoNC = ISNULL(@MontoNC, 0);

        -- Validar que haya diferencia
        IF @MontoNC <= 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No se detectaron diferencias entre lo pedido y lo recibido.';
            ROLLBACK; RETURN;
        END

        -- Si ya existe NC para esta compra, solo actualizar el monto
        IF EXISTS (SELECT 1 FROM dbo.NOTA_CREDITO WHERE IdCompra = @IdCompra)
        BEGIN
            UPDATE dbo.COMPRA
               SET MontoNotaCredito    = @MontoNC,
                   IdMotivoNotaCredito = @IdMotivoNC
             WHERE IdCompra = @IdCompra;

            SET @Resultado = 1;
            SET @Mensaje   = 'Nota de Crédito ya existente. Monto actualizado.';
            COMMIT; RETURN;
        END

        -- Insertar NC en estado Pendiente
        INSERT INTO dbo.NOTA_CREDITO
            (IdCompra, IdMotivoNC, Monto, Estado, IdUsuarioRegistro, FechaRegistro)
        VALUES
            (@IdCompra, @IdMotivoNC, @MontoNC, 'Pendiente', @IdUsuario, GETDATE());

        -- Actualizar COMPRA (compatibilidad con reportes existentes)
        UPDATE dbo.COMPRA
           SET MontoNotaCredito    = @MontoNC,
               IdMotivoNotaCredito = @IdMotivoNC,
               NecesitaNC          = 1
         WHERE IdCompra = @IdCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Nota de Crédito registrada en estado Pendiente. '
                       + 'Aguardando el documento físico del proveedor.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
        SET @MontoNC   = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarNotaCredito recreado sin errores.';
GO

-- ── 3. También actualizar usp_ObtenerListaCompraRevision para incluir NecesitaNC ──
--    (el C# lee esta columna con LeerBool en ObtenerListaRevision)
--    Solo si el SP existe y NO retorna ya la columna.
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_ObtenerListaCompraRevision')
BEGIN
    -- Verificar si ya retorna NecesitaNC
    IF NOT EXISTS (
        SELECT 1 FROM sys.sql_modules sm
         INNER JOIN sys.procedures sp ON sp.object_id = sm.object_id
         WHERE sp.name = 'usp_ObtenerListaCompraRevision'
           AND sm.definition LIKE '%NecesitaNC%'
    )
        PRINT 'AVISO: usp_ObtenerListaCompraRevision existe pero no incluye NecesitaNC en el SELECT.';
    ELSE
        PRINT 'INFO: usp_ObtenerListaCompraRevision ya incluye NecesitaNC — OK.';
END
ELSE
    PRINT 'INFO: usp_ObtenerListaCompraRevision no existe (puede ser inline en C#).';
GO

-- ── 4. Verificar estado final ─────────────────────────────────────────────────
SELECT
    c.name AS Columna,
    t.name AS Tipo,
    c.is_nullable,
    c.default_object_id
  FROM sys.columns c
  JOIN sys.types   t ON t.user_type_id = c.user_type_id
 WHERE c.object_id = OBJECT_ID('dbo.COMPRA')
   AND c.name IN ('NecesitaNC','MontoNotaCredito','IdMotivoNotaCredito');
GO

PRINT '════════════════════════════════════════════════════════';
PRINT 'Script 33b completado. NecesitaNC disponible en COMPRA.';
PRINT '════════════════════════════════════════════════════════';
GO
