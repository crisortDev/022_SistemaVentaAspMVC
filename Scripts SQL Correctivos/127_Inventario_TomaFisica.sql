-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 127: Toma de Inventario físico (conteo) — Etapa 2
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-09
--
-- Documento de inventario con CABECERA + DETALLE y flujo de aprobación:
--   - Cabecera (INVENTARIO): fecha, responsable, tienda, estado.
--   - Detalle  (DETALLE_INVENTARIO): producto, stock sistema, stock contado, diferencia.
--   - Estado: Borrador → Pendiente → Aprobado / Rechazado.
--   - Al APROBAR: ajusta PRODUCTO_TIENDA.Stock al valor contado (físico manda).
--   - Segregación: quien registra no aprueba (salvo SuperAdmin).
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Tabla cabecera INVENTARIO ───────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'INVENTARIO')
BEGIN
    CREATE TABLE dbo.INVENTARIO (
        IdInventario       INT IDENTITY(1,1) PRIMARY KEY,
        Numero             VARCHAR(20)  NULL,            -- INV-00000001
        IdTienda           INT          NOT NULL,
        IdUsuarioRegistro  INT          NOT NULL,
        FechaRegistro      DATETIME     NOT NULL DEFAULT GETDATE(),
        Estado             VARCHAR(20)  NOT NULL DEFAULT 'Pendiente', -- Pendiente/Aprobado/Rechazado
        Observacion        VARCHAR(500) NULL,
        IdUsuarioAprueba   INT          NULL,
        FechaAprobacion    DATETIME     NULL,
        MotivoRechazo      VARCHAR(255) NULL,
        CONSTRAINT FK_INV_Tienda  FOREIGN KEY (IdTienda)          REFERENCES dbo.TIENDA(IdTienda),
        CONSTRAINT FK_INV_UsuReg  FOREIGN KEY (IdUsuarioRegistro) REFERENCES dbo.USUARIO(IdUsuario)
    );
    PRINT 'OK: tabla INVENTARIO creada.';
END
ELSE PRINT 'INFO: tabla INVENTARIO ya existía.';
GO

-- ─── 2. Tabla detalle DETALLE_INVENTARIO ────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DETALLE_INVENTARIO')
BEGIN
    CREATE TABLE dbo.DETALLE_INVENTARIO (
        IdDetalleInventario INT IDENTITY(1,1) PRIMARY KEY,
        IdInventario        INT NOT NULL,
        IdProducto          INT NOT NULL,
        IdProductoTienda    INT NOT NULL,
        StockSistema        BIGINT NOT NULL DEFAULT 0,   -- lo que decía el sistema al tomar
        StockContado        BIGINT NOT NULL DEFAULT 0,   -- lo que se contó físicamente
        Diferencia          BIGINT NOT NULL DEFAULT 0,   -- contado - sistema
        CONSTRAINT FK_DINV_Inv FOREIGN KEY (IdInventario) REFERENCES dbo.INVENTARIO(IdInventario)
    );
    PRINT 'OK: tabla DETALLE_INVENTARIO creada.';
END
ELSE PRINT 'INFO: tabla DETALLE_INVENTARIO ya existía.';
GO

-- ─── 3. usp_RegistrarInventario — crea cabecera + detalle desde XML ──────────────
--   El detalle viene como XML: <Detalle><Item><IdProductoTienda>..</><StockContado>..</></Item>...</Detalle>
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarInventario
    @IdTienda          INT,
    @IdUsuarioRegistro INT,
    @Observacion       VARCHAR(500),
    @DetalleXml        XML,
    @Resultado         BIT           OUTPUT,
    @Mensaje           NVARCHAR(300) OUTPUT,
    @IdInventario      INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF @IdTienda IS NULL OR @IdTienda = 0
        BEGIN SET @Resultado=0; SET @Mensaje='Tienda no especificada.'; SET @IdInventario=0; ROLLBACK; RETURN; END

        IF (SELECT COUNT(*) FROM @DetalleXml.nodes('/Detalle/Item') AS t(n)) = 0
        BEGIN SET @Resultado=0; SET @Mensaje='Debe incluir al menos un producto contado.'; SET @IdInventario=0; ROLLBACK; RETURN; END

        INSERT INTO dbo.INVENTARIO (IdTienda, IdUsuarioRegistro, FechaRegistro, Estado, Observacion)
        VALUES (@IdTienda, @IdUsuarioRegistro, GETDATE(), 'Pendiente', @Observacion);

        SET @IdInventario = SCOPE_IDENTITY();

        UPDATE dbo.INVENTARIO
           SET Numero = 'INV-' + RIGHT('00000000' + CAST(@IdInventario AS VARCHAR), 8)
         WHERE IdInventario = @IdInventario;

        -- Detalle: toma el stock del sistema al momento y calcula diferencia
        INSERT INTO dbo.DETALLE_INVENTARIO
            (IdInventario, IdProducto, IdProductoTienda, StockSistema, StockContado, Diferencia)
        SELECT
            @IdInventario,
            pt.IdProducto,
            pt.IdProductoTienda,
            ISNULL(pt.Stock, 0)                                            AS StockSistema,
            n.value('(StockContado)[1]','BIGINT')                          AS StockContado,
            n.value('(StockContado)[1]','BIGINT') - ISNULL(pt.Stock,0)     AS Diferencia
        FROM @DetalleXml.nodes('/Detalle/Item') AS t(n)
        INNER JOIN dbo.PRODUCTO_TIENDA pt
            ON pt.IdProductoTienda = n.value('(IdProductoTienda)[1]','INT');

        SET @Resultado = 1;
        SET @Mensaje   = 'Inventario registrado. Queda PENDIENTE de aprobación.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @IdInventario=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarInventario creado.';
GO

-- ─── 4. usp_AprobarInventario — ajusta el stock al contado ──────────────────────
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

        DECLARE @Estado VARCHAR(20), @IdUsuarioReg INT;
        SELECT @Estado = Estado, @IdUsuarioReg = IdUsuarioRegistro
        FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;

        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; ROLLBACK; RETURN; END
        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se aprueban inventarios Pendientes. Estado: '+@Estado; ROLLBACK; RETURN; END

        IF @EsSuperAdmin = 0 AND @IdUsuarioReg = @IdUsuarioAprueba
        BEGIN SET @Resultado=0; SET @Mensaje='Quien registró el inventario no puede aprobarlo (segregación de funciones).'; ROLLBACK; RETURN; END

        -- Ajustar stock al valor contado (el conteo físico es la verdad)
        UPDATE pt
           SET pt.Stock = d.StockContado
        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN dbo.DETALLE_INVENTARIO d ON d.IdProductoTienda = pt.IdProductoTienda
        WHERE d.IdInventario = @IdInventario;

        UPDATE dbo.INVENTARIO
           SET Estado = 'Aprobado', IdUsuarioAprueba = @IdUsuarioAprueba, FechaAprobacion = GETDATE()
         WHERE IdInventario = @IdInventario;

        SET @Resultado = 1; SET @Mensaje = 'Inventario aprobado. Stock ajustado al conteo físico.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AprobarInventario creado.';
GO

-- ─── 5. usp_RechazarInventario ──────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RechazarInventario
    @IdInventario     INT,
    @IdUsuarioAprueba INT,
    @MotivoRechazo    VARCHAR(255),
    @Resultado        BIT           OUTPUT,
    @Mensaje          NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Estado VARCHAR(20);
        SELECT @Estado = Estado FROM dbo.INVENTARIO WHERE IdInventario = @IdInventario;
        IF @Estado IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Inventario no encontrado.'; RETURN; END
        IF @Estado <> 'Pendiente'
        BEGIN SET @Resultado=0; SET @Mensaje='Solo se rechazan inventarios Pendientes.'; RETURN; END

        UPDATE dbo.INVENTARIO
           SET Estado='Rechazado', IdUsuarioAprueba=@IdUsuarioAprueba,
               FechaAprobacion=GETDATE(), MotivoRechazo=@MotivoRechazo
         WHERE IdInventario=@IdInventario;

        SET @Resultado=1; SET @Mensaje='Inventario rechazado. El stock no fue modificado.';
    END TRY
    BEGIN CATCH SET @Resultado=0; SET @Mensaje='Error: '+ERROR_MESSAGE(); END CATCH
END
GO
PRINT 'OK: usp_RechazarInventario creado.';
GO

-- ─── 6. usp_ObtenerInventarios — lista cabeceras ────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerInventarios
    @IdTienda INT = 0,
    @Estado   VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        i.IdInventario, i.Numero, i.IdTienda, t.Nombre AS NombreTienda,
        i.Estado, ISNULL(i.Observacion,'') AS Observacion,
        CONVERT(VARCHAR(19), i.FechaRegistro, 120) AS FechaRegistro,
        ur.Nombres + ' ' + ur.Apellidos AS UsuarioRegistro,
        ISNULL(ua.Nombres + ' ' + ua.Apellidos,'') AS UsuarioAprueba,
        CONVERT(VARCHAR(19), i.FechaAprobacion, 120) AS FechaAprobacion,
        ISNULL(i.MotivoRechazo,'') AS MotivoRechazo,
        (SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario) AS CantItems,
        (SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario AND d.Diferencia<>0) AS CantDiferencias
    FROM dbo.INVENTARIO i
    INNER JOIN dbo.TIENDA  t  ON t.IdTienda  = i.IdTienda
    INNER JOIN dbo.USUARIO ur ON ur.IdUsuario = i.IdUsuarioRegistro
    LEFT  JOIN dbo.USUARIO ua ON ua.IdUsuario = i.IdUsuarioAprueba
    WHERE (@IdTienda=0 OR i.IdTienda=@IdTienda)
      AND (@Estado='' OR i.Estado=@Estado)
    ORDER BY CASE WHEN i.Estado='Pendiente' THEN 0 ELSE 1 END, i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventarios creado.';
GO

-- ─── 7. usp_ObtenerDetalleInventario — líneas de un inventario ──────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleInventario
    @IdInventario INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.IdDetalleInventario, d.IdProducto, p.Codigo AS CodigoProducto, p.Nombre AS NombreProducto,
        d.StockSistema, d.StockContado, d.Diferencia
    FROM dbo.DETALLE_INVENTARIO d
    INNER JOIN dbo.PRODUCTO p ON p.IdProducto = d.IdProducto
    WHERE d.IdInventario = @IdInventario
    ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerDetalleInventario creado.';
GO

PRINT '════ Script 127 (Toma de Inventario) completado ════';
GO
