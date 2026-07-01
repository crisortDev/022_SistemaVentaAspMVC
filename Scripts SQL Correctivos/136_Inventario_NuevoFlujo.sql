-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 136: Inventario — Nuevo flujo Supervisor / Operador
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-22
--
-- CAMBIOS:
--   1. ALTER TABLE INVENTARIO → agrega FechaInicio, FechaFinalizacion
--   2. CREATE TABLE INVENTARIO_ASIGNACION (Supervisor asigna Operadores)
--   3. usp_CrearInventario         — Supervisor crea (Estado=Abierto)
--   4. usp_AsignarOperadorInventario — Supervisor asigna operadores
--   5. usp_IniciarConteoInventario  — Operador abre → En Progreso
--   6. usp_FinalizarConteoInventario— Operador finaliza → Pendiente de Aprobación
--   7. usp_AprobarInventario        — Supervisor aprueba (actualizado: acepta 'Pendiente de Aprobación')
--   8. usp_RechazarInventario       — Supervisor rechaza → En Corrección
--   9. usp_ObtenerInventariosSupervisor  — listado para Supervisor
--  10. usp_ObtenerInventariosOperador   — solo asignados al Operador
--  11. usp_ObtenerProductosParaConteo   — productos SIN stock/costo (para Operador)
--  12. usp_ObtenerDetalleInventario     — detalle CON diferencias (para Supervisor)
--
-- ESTADOS DEL PROCESO:
--   Abierto → En Progreso → Pendiente de Aprobación → Aprobado
--                                                   → En Corrección → (vuelve a En Progreso)
--
-- ⚠️ BACKUP antes de ejecutar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. ALTER TABLE INVENTARIO — nuevas columnas
-- ════════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.INVENTARIO') AND name='FechaInicio')
    ALTER TABLE dbo.INVENTARIO ADD FechaInicio DATETIME NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.INVENTARIO') AND name='FechaFinalizacion')
    ALTER TABLE dbo.INVENTARIO ADD FechaFinalizacion DATETIME NULL;

PRINT 'OK: columnas FechaInicio y FechaFinalizacion en INVENTARIO.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. CREATE TABLE INVENTARIO_ASIGNACION
-- ════════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='INVENTARIO_ASIGNACION')
BEGIN
    CREATE TABLE dbo.INVENTARIO_ASIGNACION (
        IdAsignacion    INT IDENTITY(1,1) PRIMARY KEY,
        IdInventario    INT NOT NULL,
        IdOperador      INT NOT NULL,
        FechaAsignacion DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_IA_Inv      FOREIGN KEY (IdInventario) REFERENCES dbo.INVENTARIO(IdInventario),
        CONSTRAINT FK_IA_Operador FOREIGN KEY (IdOperador)   REFERENCES dbo.USUARIO(IdUsuario),
        CONSTRAINT UQ_IA_InvOp    UNIQUE (IdInventario, IdOperador)
    );
    PRINT 'OK: tabla INVENTARIO_ASIGNACION creada.';
END
ELSE
    PRINT 'INFO: INVENTARIO_ASIGNACION ya existe.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. usp_CrearInventario — Supervisor abre un nuevo proceso de inventario
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_CrearInventario
    @IdTienda          INT,
    @IdSupervisor      INT,
    @Observacion       VARCHAR(500) = NULL,
    @IdInventario      INT          OUTPUT,
    @Resultado         BIT          OUTPUT,
    @Mensaje           NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Num VARCHAR(20);
        SELECT @Num = 'INV-' + RIGHT('00000000' + CAST(ISNULL(MAX(IdInventario),0)+1 AS VARCHAR), 8)
        FROM dbo.INVENTARIO;

        INSERT INTO dbo.INVENTARIO
            (Numero, IdTienda, IdUsuarioRegistro, FechaRegistro, Estado, Observacion)
        VALUES
            (@Num, @IdTienda, @IdSupervisor, GETDATE(), 'Abierto', @Observacion);

        SET @IdInventario = SCOPE_IDENTITY();
        SET @Resultado = 1;
        SET @Mensaje = 'Inventario ' + @Num + ' creado. Asigne operadores para continuar.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @IdInventario=0; SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_CrearInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. usp_AsignarOperadorInventario — Supervisor asigna un operador
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

    IF @Estado NOT IN ('Abierto','En Corrección')
    BEGIN SET @Resultado=0; SET @Mensaje='Solo se pueden asignar operadores cuando el inventario está Abierto o En Corrección. Estado actual: '+@Estado; RETURN; END

    IF EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
    BEGIN SET @Resultado=0; SET @Mensaje='Ese operador ya está asignado.'; RETURN; END

    INSERT INTO dbo.INVENTARIO_ASIGNACION (IdInventario, IdOperador, FechaAsignacion)
    VALUES (@IdInventario, @IdOperador, GETDATE());

    SET @Resultado=1; SET @Mensaje='Operador asignado correctamente.';
END
GO
PRINT 'OK: usp_AsignarOperadorInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 5. usp_IniciarConteoInventario — Operador abre el inventario → En Progreso
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

    IF @Estado NOT IN ('Abierto', 'En Corrección')
    BEGIN SET @Resultado=0; SET @Mensaje='Este inventario no puede iniciarse. Estado actual: '+@Estado; RETURN; END

    -- Limpiar detalle previo si viene de En Corrección
    IF @Estado = 'En Corrección'
        DELETE FROM dbo.DETALLE_INVENTARIO WHERE IdInventario = @IdInventario;

    UPDATE dbo.INVENTARIO
       SET Estado='En Progreso', FechaInicio=GETDATE(), FechaFinalizacion=NULL
     WHERE IdInventario=@IdInventario;

    SET @Resultado=1; SET @Mensaje='Conteo iniciado. Registre las cantidades físicas.';
END
GO
PRINT 'OK: usp_IniciarConteoInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 6. usp_FinalizarConteoInventario — Operador finaliza → Pendiente de Aprobación
--    XML de detalle: <Detalle><Item><IdProducto>1</IdProducto><CantidadContada>5</CantidadContada></Item>...</Detalle>
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

        IF @Estado <> 'En Progreso'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se puede finalizar un inventario En Progreso. Estado: '+@Estado; ROLLBACK; RETURN; END

        IF NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO_ASIGNACION
                       WHERE IdInventario=@IdInventario AND IdOperador=@IdOperador)
        BEGIN SET @Resultado=0; SET @Mensaje='No tiene permiso sobre este inventario.'; ROLLBACK; RETURN; END

        -- Limpiar detalle anterior (en caso de re-envío)
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
                r.n.value('IdProducto[1]',      'INT')   AS IdProducto,
                r.n.value('CantidadContada[1]', 'INT')   AS CantidadContada
            FROM @DetalleXml.nodes('/Detalle/Item') AS r(n)
        ) x
        JOIN dbo.PRODUCTO_TIENDA pt
            ON pt.IdProducto = x.IdProducto AND pt.IdTienda = @IdTienda;

        IF @@ROWCOUNT = 0
        BEGIN SET @Resultado=0; SET @Mensaje='No se procesaron productos. Verifique el detalle.'; ROLLBACK; RETURN; END

        UPDATE dbo.INVENTARIO
           SET Estado='Pendiente de Aprobación',
               FechaFinalizacion=GETDATE(),
               Observacion=ISNULL(NULLIF(@Observacion,''), Observacion)
         WHERE IdInventario=@IdInventario;

        SET @Resultado=1; SET @Mensaje='Conteo finalizado. El inventario quedó pendiente de aprobación del supervisor.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_FinalizarConteoInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 7. usp_AprobarInventario — actualizado para aceptar 'Pendiente de Aprobación'
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
        SELECT @Estado = Estado, @IdUsuarioReg = IdUsuarioRegistro
        FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; ROLLBACK; RETURN; END

        IF @Estado <> 'Pendiente de Aprobación'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se aprueban inventarios Pendientes de Aprobación. Estado: '+@Estado; ROLLBACK; RETURN; END

        -- Segregación: quien registró no puede aprobar (salvo SuperAdmin)
        IF @EsSuperAdmin = 0 AND @IdUsuarioReg = @IdUsuarioAprueba
        BEGIN SET @Resultado=0; SET @Mensaje='Quien creó el inventario no puede aprobarlo (segregación de funciones).'; ROLLBACK; RETURN; END

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
PRINT 'OK: usp_AprobarInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 8. usp_RechazarInventario — rechaza → En Corrección (vuelve al operador)
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
           SET Estado='En Corrección',
               IdUsuarioAprueba=@IdUsuarioAprueba,
               FechaAprobacion=GETDATE(),
               MotivoRechazo=@MotivoRechazo
         WHERE IdInventario=@IdInventario;

        SET @Resultado=1; SET @Mensaje='Inventario devuelto al operador para corrección.';
    END TRY
    BEGIN CATCH
        SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RechazarInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 9. usp_ObtenerInventariosSupervisor — listado completo para el Supervisor
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
        -- Lista de operadores asignados (concatenada)
        STUFF((
            SELECT ', ' + ISNULL(uo.Nombres + ' ' + uo.Apellidos, CAST(ia.IdOperador AS VARCHAR))
            FROM dbo.INVENTARIO_ASIGNACION ia
            LEFT JOIN dbo.USUARIO uo ON uo.IdUsuario = ia.IdOperador
            WHERE ia.IdInventario = i.IdInventario
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, '')            AS Operadores,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario), 0) AS CantItems,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario AND d.Diferencia<>0), 0) AS CantDiferencias
    FROM dbo.INVENTARIO i
    JOIN dbo.TIENDA t ON t.IdTienda = i.IdTienda
    LEFT JOIN dbo.USUARIO u ON u.IdUsuario = i.IdUsuarioRegistro
    LEFT JOIN dbo.USUARIO ua ON ua.IdUsuario = i.IdUsuarioAprueba
    WHERE (@IdTienda = 0 OR i.IdTienda = @IdTienda)
      AND (@Estado = '' OR i.Estado = @Estado)
    ORDER BY
        CASE i.Estado
            WHEN 'Pendiente de Aprobación' THEN 0
            WHEN 'En Progreso'  THEN 1
            WHEN 'Abierto'      THEN 2
            WHEN 'En Corrección' THEN 3
            ELSE 4
        END,
        i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventariosSupervisor';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 10. usp_ObtenerInventariosOperador — solo inventarios asignados al Operador
--     IMPORTANTE: NO incluye stock ni costos
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
    JOIN dbo.INVENTARIO_ASIGNACION ia ON ia.IdInventario = i.IdInventario AND ia.IdOperador = @IdOperador
    WHERE i.Estado IN ('Abierto', 'En Progreso', 'En Corrección')
    ORDER BY
        CASE i.Estado
            WHEN 'En Progreso'   THEN 0
            WHEN 'En Corrección' THEN 1
            WHEN 'Abierto'       THEN 2
        END,
        i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventariosOperador';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 11. usp_ObtenerProductosParaConteo — sin stock, sin costo (vista del Operador)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerProductosParaConteo
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProducto,
        p.Codigo,
        p.Nombre,
        ISNULL(c.Descripcion, 'Sin categoría') AS Categoria
        -- ⚠ NO se expone Stock, Costo ni Precio: el operador debe contar sin sesgo
    FROM dbo.PRODUCTO_TIENDA pt
    JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto AND p.Activo = 1
    LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdTienda = @IdTienda AND pt.Activo = 1
    ORDER BY c.Descripcion, p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductosParaConteo';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 12. usp_ObtenerDetalleInventario — con diferencias (solo para Supervisor)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleInventario
    @IdInventario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Codigo               AS CodigoProducto,
        p.Nombre               AS NombreProducto,
        ISNULL(c.Nombre,'—')   AS Categoria,
        d.StockSistema,
        d.StockContado,
        d.Diferencia
    FROM dbo.DETALLE_INVENTARIO d
    JOIN dbo.PRODUCTO p ON p.IdProducto = d.IdProducto
    LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE d.IdInventario = @IdInventario
    ORDER BY c.Nombre, p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerDetalleInventario';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
SELECT 'INVENTARIO_ASIGNACION' AS Tabla, COUNT(*) AS Filas FROM dbo.INVENTARIO_ASIGNACION
UNION ALL
SELECT 'INVENTARIO', COUNT(*) FROM dbo.INVENTARIO;

SELECT name AS SP, create_date, modify_date
FROM sys.objects
WHERE type='P' AND name LIKE 'usp_%nventari%'
ORDER BY name;
GO

PRINT '════ Script 136 completado ════';
GO
