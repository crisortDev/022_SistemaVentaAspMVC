-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 137: Inventario — Estado "Rechazado" + PERMISOS SuperAdmin
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-23
--
-- CAMBIOS:
--   1. usp_RechazarInventario      → Estado pasa a 'Rechazado' (era 'En Corrección')
--   2. usp_IniciarConteoInventario → acepta 'Rechazado' → pasa a 'En Corrección'
--                                    (mantiene 'Abierto' → 'En Progreso')
--   3. usp_FinalizarConteoInventario → acepta 'En Corrección' además de 'En Progreso'
--   4. usp_ObtenerInventariosOperador → incluye estados 'Rechazado' y 'En Corrección'
--   5. usp_AsignarOperadorInventario  → acepta 'Rechazado' además de 'Abierto'
--   6. usp_ObtenerInventariosSupervisor → agrega 'Rechazado' al ordenamiento
--   7. PERMISOS SuperAdmin (IdRol=14) para 'Toma de Inventario' e 'Inventarios'
--
-- ESTADOS DEL PROCESO (6 estados):
--   Abierto
--      │
--      ▼
--   En Progreso
--      │
--      ▼
--   Pendiente de Aprobación
--      │
--      ├──► Aprobado  (fin)
--      │
--      └──► Rechazado
--               │
--               ▼
--           En Corrección
--               │
--               ▼
--        Pendiente de Aprobación  (ciclo)
--
-- ⚠️ BACKUP antes de ejecutar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_RechazarInventario — ahora pone Estado = 'Rechazado'
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_RechazarInventario
    @IdInventario     INT,
    @IdUsuarioAprueba INT,
    @MotivoRechazo    VARCHAR(255),
    @Resultado        BIT          OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Estado VARCHAR(30);
        SELECT @Estado = Estado FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; RETURN; END

        IF @Estado <> 'Pendiente de Aprobación'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se rechazan inventarios Pendientes de Aprobación. Estado: '+@Estado; RETURN; END

        UPDATE dbo.INVENTARIO
           SET Estado         = 'Rechazado',          -- ← cambiado de 'En Corrección'
               IdUsuarioAprueba = @IdUsuarioAprueba,
               FechaAprobacion  = GETDATE(),
               MotivoRechazo    = @MotivoRechazo
         WHERE IdInventario = @IdInventario;

        SET @Resultado=1; SET @Mensaje='Inventario rechazado. El operador recibirá la notificación para corregir.';
    END TRY
    BEGIN CATCH
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RechazarInventario (→ Rechazado)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_IniciarConteoInventario — acepta 'Rechazado' → pone 'En Corrección'
--                                  mantiene 'Abierto'  → pone 'En Progreso'
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_IniciarConteoInventario
    @IdInventario INT,
    @IdOperador   INT,
    @Resultado    BIT          OUTPUT,
    @Mensaje      NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Estado VARCHAR(30);
    SELECT @Estado = Estado FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

    IF @Estado IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; RETURN; END

    -- Verificar que el operador esté asignado
    IF NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION
                   WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
    BEGIN SET @Resultado=0; SET @Mensaje='No tiene permiso sobre este inventario.'; RETURN; END

    IF @Estado NOT IN ('Abierto', 'Rechazado')
    BEGIN SET @Resultado=0; SET @Mensaje='Este inventario no puede iniciarse. Estado actual: '+@Estado; RETURN; END

    -- Limpiar detalle previo cuando viene de Rechazado (corrección)
    IF @Estado = 'Rechazado'
        DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;

    -- Abierto → En Progreso | Rechazado → En Corrección
    DECLARE @NuevoEstado VARCHAR(30) =
        CASE WHEN @Estado = 'Abierto' THEN 'En Progreso' ELSE 'En Corrección' END;

    UPDATE dbo.INVENTARIO
       SET Estado      = @NuevoEstado,
           FechaInicio = GETDATE(),
           FechaFinalizacion = NULL
     WHERE IdInventario = @IdInventario;

    SET @Resultado=1;
    SET @Mensaje = CASE WHEN @Estado = 'Abierto'
                        THEN 'Conteo iniciado. Registre las cantidades físicas.'
                        ELSE 'Corrección iniciada. Registre nuevamente las cantidades.' END;
END
GO
PRINT 'OK: usp_IniciarConteoInventario (acepta Rechazado → En Corrección)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. usp_FinalizarConteoInventario — acepta 'En Corrección' además de 'En Progreso'
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
        SELECT @Estado = Estado, @IdTienda = IdTienda
        FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; ROLLBACK; RETURN; END

        IF @Estado NOT IN ('En Progreso', 'En Corrección')   -- ← acepta ambos
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se puede finalizar un inventario En Progreso o En Corrección. Estado: '+@Estado; ROLLBACK; RETURN; END

        IF NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION
                       WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
        BEGIN SET @Resultado=0; SET @Mensaje='No tiene permiso sobre este inventario.'; ROLLBACK; RETURN; END

        -- Limpiar detalle anterior
        DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;

        -- Insertar detalle desde XML, capturando StockSistema
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
           SET Estado           = 'Pendiente de Aprobación',
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
PRINT 'OK: usp_FinalizarConteoInventario (acepta En Corrección)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. usp_ObtenerInventariosOperador — incluye 'Rechazado' y 'En Corrección'
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerInventariosOperador
    @IdOperador INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.IdInventario,
        i.Numero,
        i.FechaRegistro,
        i.FechaInicio,
        i.Estado,
        ISNULL(i.MotivoRechazo, '') AS MotivoRechazo,
        t.Nombre                    AS NombreTienda,
        i.IdTienda
    FROM dbo.INVENTARIO i
    JOIN dbo.TIENDA t ON t.IdTienda = i.IdTienda
    JOIN dbo.INVENTARIO_ASIGNACION ia
         ON ia.IdInventario = i.IdInventario AND ia.IdOperador = @IdOperador
    WHERE i.Estado IN ('Abierto', 'En Progreso', 'Rechazado', 'En Corrección')
    ORDER BY
        CASE i.Estado
            WHEN 'En Progreso'    THEN 0
            WHEN 'En Corrección'  THEN 1
            WHEN 'Rechazado'      THEN 2
            WHEN 'Abierto'        THEN 3
        END,
        i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventariosOperador (incluye Rechazado y En Corrección)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 5. usp_AsignarOperadorInventario — acepta 'Rechazado' además de 'Abierto'
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_AsignarOperadorInventario
    @IdInventario INT,
    @IdOperador   INT,
    @Resultado    BIT          OUTPUT,
    @Mensaje      NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Estado VARCHAR(30);
    SELECT @Estado = Estado FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

    IF @Estado IS NULL
    BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; RETURN; END

    IF @Estado NOT IN ('Abierto', 'Rechazado')   -- ← acepta Rechazado para reasignar
    BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden asignar operadores cuando el inventario está Abierto o Rechazado. Estado actual: '+@Estado; RETURN; END

    IF EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
    BEGIN SET @Resultado=0; SET @Mensaje='Ese operador ya está asignado.'; RETURN; END

    INSERT INTO dbo.INVENTARIO_ASIGNACION (IdInventario, IdOperador, FechaAsignacion)
    VALUES (@IdInventario, @IdOperador, GETDATE());

    SET @Resultado=1; SET @Mensaje='Operador asignado correctamente.';
END
GO
PRINT 'OK: usp_AsignarOperadorInventario (acepta Rechazado)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 6. usp_ObtenerInventariosSupervisor — agrega 'Rechazado' al ORDER BY
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerInventariosSupervisor
    @IdTienda INT = 0,
    @Estado   VARCHAR(30) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.IdInventario,
        i.Numero,
        i.FechaRegistro,
        i.FechaInicio,
        i.FechaFinalizacion,
        i.Estado,
        i.Observacion,
        i.MotivoRechazo,
        t.Nombre                                          AS NombreTienda,
        ISNULL(u.Nombres + ' ' + u.Apellidos, 'Sistema') AS Supervisor,
        ISNULL(ua.Nombres + ' ' + ua.Apellidos, '—')     AS Aprobador,
        i.FechaAprobacion,
        STUFF((
            SELECT ', ' + ISNULL(uo.Nombres + ' ' + uo.Apellidos, CAST(ia.IdOperador AS VARCHAR))
            FROM dbo.INVENTARIO_ASIGNACION ia
            LEFT JOIN dbo.USUARIO uo ON uo.IdUsuario = ia.IdOperador
            WHERE ia.IdInventario = i.IdInventario
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, '')            AS Operadores,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario), 0)                          AS CantItems,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario AND d.Diferencia<>0), 0)       AS CantDiferencias
    FROM dbo.INVENTARIO i
    JOIN dbo.TIENDA t ON t.IdTienda = i.IdTienda
    LEFT JOIN dbo.USUARIO u  ON u.IdUsuario  = i.IdUsuarioRegistro
    LEFT JOIN dbo.USUARIO ua ON ua.IdUsuario = i.IdUsuarioAprueba
    WHERE (@IdTienda = 0 OR i.IdTienda = @IdTienda)
      AND (@Estado = '' OR i.Estado = @Estado)
    ORDER BY
        CASE i.Estado
            WHEN 'Pendiente de Aprobación' THEN 0
            WHEN 'En Progreso'             THEN 1
            WHEN 'En Corrección'           THEN 2
            WHEN 'Rechazado'               THEN 3
            WHEN 'Abierto'                 THEN 4
            ELSE 5
        END,
        i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventariosSupervisor (con Rechazado en ORDER BY)';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 7. PERMISOS SuperAdmin (IdRol=14) para los submenús nuevos de inventario
--    Esto garantiza que aparezcan en el menú del SuperAdmin.
-- ════════════════════════════════════════════════════════════════════════════════
INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu)
SELECT 14, sm.IdSubMenu
FROM dbo.SUBMENU sm
WHERE sm.Nombre IN ('Toma de Inventario', 'Inventarios')
  AND sm.Activo = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.PERMISOS p
      WHERE p.IdRol = 14 AND p.IdSubMenu = sm.IdSubMenu
  );

PRINT 'OK: PERMISOS SuperAdmin para Toma de Inventario e Inventarios.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
SELECT name AS SP, modify_date
FROM sys.objects
WHERE type='P' AND name IN (
    'usp_RechazarInventario',
    'usp_IniciarConteoInventario',
    'usp_FinalizarConteoInventario',
    'usp_ObtenerInventariosOperador',
    'usp_AsignarOperadorInventario',
    'usp_ObtenerInventariosSupervisor'
)
ORDER BY name;

SELECT sm.Nombre AS SubMenu, p.IdRol
FROM dbo.PERMISOS p
JOIN dbo.SUBMENU sm ON sm.IdSubMenu = p.IdSubMenu
WHERE sm.Nombre IN ('Toma de Inventario','Inventarios')
  AND p.IdRol = 14;

PRINT '════ Script 137 completado ════';
GO
