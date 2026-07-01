-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 142: Toma de Inventario — límite de cantidad contada por producto
-- Base de datos: [DBVENTAS_WEB]
--
-- PROBLEMA:
--   El campo "Cantidad Contada" que carga el repositor en la Toma de Inventario
--   no tenía ningún tope máximo, ni en la vista (Inventario_TomaInventario.js)
--   ni en el procedimiento almacenado. Al aprobar el inventario, ese valor se
--   vuelca directo a PRODUCTO_TIENDA.Stock (usp_AprobarInventario), por lo que
--   un valor mal cargado (ej. un cero de más) o uno enviado directamente por
--   API (bypaseando la UI) podía dejar un stock absurdo sin ninguna validación,
--   a diferencia del flujo de Compras que sí valida contra StockMaximo.
--
-- CAMBIOS:
--   1. usp_FinalizarConteoInventario → valida 0 <= CantidadContada <= @LimiteCantidad
--      ANTES de insertar el detalle. Si hay valores fuera de rango, rechaza todo
--      el conteo con un mensaje claro (no deja pasar nada parcialmente).
--   2. usp_AprobarInventario → guarda de seguridad adicional (defensa en profundidad):
--      si por algún motivo quedara una fila de detalle fuera de rango, la
--      aprobación se rechaza con mensaje explícito en vez de fallar con el
--      CHECK constraint de stock negativo (CK_ProductoTienda_StockNoNegativo)
--      o dejar pasar un sobrestock silencioso.
--
-- NOTA: el tope (99999) es el mismo valor que el atributo "max" del input en
--       Inventario_TomaInventario.js. Si se cambia acá, cambiar también ahí.
--
-- ⚠️ BACKUP antes de ejecutar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_FinalizarConteoInventario — agrega validación de rango
--    (mismo SP de los scripts 137/141, + límite de cantidad)
-- ════════════════════════════════════════════════════════════════════════════════
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
        DECLARE @LimiteCantidad INT = 99999;   -- tope de cantidad contada por producto

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

        -- Volcar el XML a una tabla temporal para poder validarlo ANTES de tocar el detalle real
        DECLARE @Items TABLE (IdProducto INT, CantidadContada INT);
        INSERT INTO @Items (IdProducto, CantidadContada)
        SELECT
            r.n.value('IdProducto[1]',      'INT'),
            r.n.value('CantidadContada[1]', 'INT')
        FROM @DetalleXml.nodes('/Detalle/Item') AS r(n);

        -- ── Validación de rango: ningún ítem puede ser negativo ni superar el tope ──
        IF EXISTS (SELECT 1 FROM @Items WHERE CantidadContada < 0 OR CantidadContada > @LimiteCantidad)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Hay cantidades fuera de rango (permitido: 0 a ' + CAST(@LimiteCantidad AS VARCHAR)
                            + '). Revise el conteo antes de finalizar.';
            ROLLBACK; RETURN;
        END

        -- Limpiar detalle anterior
        DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;

        -- Insertar detalle desde la tabla ya validada, capturando StockSistema actual
        INSERT INTO dbo.DETALLE_INVENTARIO
            (IdInventario, IdProducto, IdProductoTienda, StockSistema, StockContado, Diferencia)
        SELECT
            @IdInventario,
            x.IdProducto,
            pt.IdProductoTienda,
            ISNULL(pt.Stock, 0),
            x.CantidadContada,
            x.CantidadContada - ISNULL(pt.Stock, 0)
        FROM @Items x
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
PRINT 'OK: usp_FinalizarConteoInventario (con límite de cantidad 0-99999)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_AprobarInventario — guarda de seguridad adicional antes de tocar Stock
--    (mismo SP del script 136, + validación defensiva de rango)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_AprobarInventario
    @IdInventario     INT,
    @IdUsuarioAprueba INT,
    @EsSuperAdmin     BIT = 0,
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Estado VARCHAR(30), @IdUsuarioReg INT;
        DECLARE @LimiteCantidad INT = 99999;

        SELECT @Estado = Estado, @IdUsuarioReg = IdUsuarioRegistro
        FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Pendiente de Aprobación'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se aprueban inventarios Pendientes de Aprobación. Estado: '+@Estado; ROLLBACK; RETURN; END

        -- Segregación: quien registró no puede aprobar (salvo SuperAdmin)
        IF @EsSuperAdmin = 0 AND @IdUsuarioReg = @IdUsuarioAprueba
        BEGIN SET @Resultado=0; SET @Mensaje='Quien creó el inventario no puede aprobarlo (segregación de funciones).'; ROLLBACK; RETURN; END

        -- Defensa en profundidad: ningún ítem del detalle puede estar fuera de rango
        IF EXISTS (
            SELECT 1 FROM dbo.DETALLE_INVENTARIO
            WHERE IdInventario = @IdInventario
              AND (StockContado < 0 OR StockContado > @LimiteCantidad)
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El detalle contiene cantidades fuera de rango. No se puede aprobar; pida al repositor que corrija el conteo.';
            ROLLBACK; RETURN;
        END

        -- Ajustar stock al valor contado
        UPDATE pt
           SET pt.Stock = d.StockContado
        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN dbo.DETALLE_INVENTARIO d ON d.IdProductoTienda = pt.IdProductoTienda
        WHERE d.IdInventario = @IdInventario;

        UPDATE dbo.INVENTARIO
           SET Estado='Aprobado', IdUsuarioAprueba=@IdUsuarioAprueba, FechaAprobacion=GETDATE()
         WHERE IdInventario=@IdInventario;

        SET @Resultado=1; SET @Mensaje='Inventario aprobado. Stock ajustado al conteo físico.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AprobarInventario (con validación defensiva de rango antes de tocar Stock)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
SELECT name AS SP, modify_date
FROM sys.objects
WHERE type='P' AND name IN ('usp_FinalizarConteoInventario', 'usp_AprobarInventario')
ORDER BY name;

PRINT '════ Script 142 completado ════';
GO
