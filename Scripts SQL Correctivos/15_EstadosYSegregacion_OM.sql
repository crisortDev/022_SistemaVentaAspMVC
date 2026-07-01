-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 15: Segregación de Funciones O&M — Estados y Auditoría
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Qué hace este script:
--   1. Agrega columna Estado + auditoría a la tabla COMPRA
--   2. Crea tabla HISTORIAL_ESTADO_OC  (trazabilidad de OC)
--   3. Crea tabla HISTORIAL_ESTADO_COMPRA (trazabilidad de facturas)
--   4. Altera usp_AprobarOrdenCompra   → registra en historial
--   5. Altera usp_RechazarOrdenCompra  → corrige parámetro + historial
--   6. Altera usp_AnularOrdenCompra    → agrega @IdUsuario + FechaAnulacion + historial
--   7. Altera usp_ConfirmarCompraEImpactarStock → @IdUsuario + Estado + historial
--   8. Crea   usp_AnularCompra          (nueva)
--   9. Altera usp_ObtenerListaCompra   → incluye Estado y filtro
--  10. Crea   usp_ObtenerListaCompraRevision (compras pendientes de revisión)
--  11. Inserta SUBMENU "Revisión de Compras" para vincular con el rol correcto
--
-- Flujo de estados por documento
-- ────────────────────────────────────────────────────────────────────────────────
--   OrdenCompra : Pendiente ──► Aprobada ──► [facturas] ──► Cerrada
--                         └──► Rechazada
--                         └──► Anulada  (cualquier estado no cerrado)
--
--   Compra (factura/NC): Pendiente ──► Confirmada ──► [OP emitida]
--                                 └──► Anulada
--
-- Segregación de roles sugerida:
--   Operativo de Compras  → Crea OC (Pendiente), Registra factura (Pendiente)
--   Aprobador / Gerencia  → Aprueba o Rechaza OC
--   Revisor de Factura    → Confirma o Anula la factura (debe ser ≠ al que registró)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

PRINT '━━━ PASO 1: Columnas de Estado y Auditoría en COMPRA ━━━━━━━━━━━━━━━━━━━━━━━━'

-- Estado del ciclo de vida (Pendiente | Confirmada | Anulada)
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.COMPRA') AND name = 'Estado')
BEGIN
    ALTER TABLE dbo.COMPRA ADD Estado VARCHAR(20) NOT NULL CONSTRAINT DF_Compra_Estado DEFAULT 'Pendiente';
    PRINT '  OK: columna Estado agregada a COMPRA';
END
ELSE PRINT '  SKIP: Estado ya existe en COMPRA';
GO

-- Quién confirmó la compra
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.COMPRA') AND name = 'IdUsuarioConfirma')
BEGIN
    ALTER TABLE dbo.COMPRA ADD IdUsuarioConfirma INT NULL;
    PRINT '  OK: columna IdUsuarioConfirma agregada a COMPRA';
END
ELSE PRINT '  SKIP: IdUsuarioConfirma ya existe en COMPRA';
GO

-- Fecha de anulación
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.COMPRA') AND name = 'FechaAnulacion')
BEGIN
    ALTER TABLE dbo.COMPRA ADD FechaAnulacion DATETIME NULL;
    PRINT '  OK: columna FechaAnulacion agregada a COMPRA';
END
ELSE PRINT '  SKIP: FechaAnulacion ya existe en COMPRA';
GO

-- Motivo de anulación
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.COMPRA') AND name = 'MotivoAnulacion')
BEGIN
    ALTER TABLE dbo.COMPRA ADD MotivoAnulacion VARCHAR(500) NULL;
    PRINT '  OK: columna MotivoAnulacion agregada a COMPRA';
END
ELSE PRINT '  SKIP: MotivoAnulacion ya existe en COMPRA';
GO

-- Migrar registros existentes: sincronizar Estado con EstadoRecepcion
UPDATE dbo.COMPRA
   SET Estado = CASE
                    WHEN EstadoRecepcion = 'Confirmada' THEN 'Confirmada'
                    ELSE 'Pendiente'
                END
WHERE Estado = 'Pendiente';   -- solo las que aún no fueron migradas

PRINT '  OK: registros existentes migrados'
GO


PRINT '━━━ PASO 2: Tabla HISTORIAL_ESTADO_OC ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES
               WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'HISTORIAL_ESTADO_OC')
BEGIN
    CREATE TABLE dbo.HISTORIAL_ESTADO_OC (
        IdHistorial     INT          IDENTITY(1,1) NOT NULL,
        IdOrdenCompra   INT          NOT NULL,
        EstadoAnterior  VARCHAR(20)  NOT NULL,
        EstadoNuevo     VARCHAR(20)  NOT NULL,
        IdUsuario       INT          NOT NULL,
        FechaTransicion DATETIME     NOT NULL CONSTRAINT DF_HistOC_Fecha DEFAULT GETDATE(),
        Observacion     VARCHAR(500) NULL,
        CONSTRAINT PK_HistEstadoOC  PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_HistOC_OC     FOREIGN KEY (IdOrdenCompra) REFERENCES dbo.OrdenCompra(IdOrdenCompra),
        CONSTRAINT FK_HistOC_Usr    FOREIGN KEY (IdUsuario)     REFERENCES dbo.USUARIO(IdUsuario)
    );
    PRINT '  OK: tabla HISTORIAL_ESTADO_OC creada';
END
ELSE PRINT '  SKIP: HISTORIAL_ESTADO_OC ya existe';
GO


PRINT '━━━ PASO 3: Tabla HISTORIAL_ESTADO_COMPRA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES
               WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'HISTORIAL_ESTADO_COMPRA')
BEGIN
    CREATE TABLE dbo.HISTORIAL_ESTADO_COMPRA (
        IdHistorial     INT          IDENTITY(1,1) NOT NULL,
        IdCompra        INT          NOT NULL,
        EstadoAnterior  VARCHAR(20)  NOT NULL,
        EstadoNuevo     VARCHAR(20)  NOT NULL,
        IdUsuario       INT          NOT NULL,
        FechaTransicion DATETIME     NOT NULL CONSTRAINT DF_HistCompra_Fecha DEFAULT GETDATE(),
        Observacion     VARCHAR(500) NULL,
        CONSTRAINT PK_HistEstadoCompra PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_HistC_Compra     FOREIGN KEY (IdCompra)   REFERENCES dbo.COMPRA(IdCompra),
        CONSTRAINT FK_HistC_Usr        FOREIGN KEY (IdUsuario)  REFERENCES dbo.USUARIO(IdUsuario)
    );
    PRINT '  OK: tabla HISTORIAL_ESTADO_COMPRA creada';
END
ELSE PRINT '  SKIP: HISTORIAL_ESTADO_COMPRA ya existe';
GO


PRINT '━━━ PASO 4: usp_AprobarOrdenCompra — agrega registro en historial ━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_AprobarOrdenCompra]
    @IdOrdenCompra      INT,
    @IdUsuarioAprobador INT,
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual VARCHAR(20);
        SELECT @EstadoActual = Estado
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Orden de Compra no encontrada.';
            RETURN;
        END

        IF @EstadoActual <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se pueden aprobar órdenes en estado Pendiente. Estado actual: ' + @EstadoActual;
            RETURN;
        END

        -- Validar que el aprobador no sea el mismo que registró (segregación O&M)
        DECLARE @IdUsuarioRegistro INT;
        SELECT @IdUsuarioRegistro = IdUsuarioRegistro
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @IdUsuarioRegistro = @IdUsuarioAprobador
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que creó la orden no puede ser el mismo que la aprueba (segregación de funciones).';
            RETURN;
        END

        BEGIN TRAN;

        UPDATE dbo.OrdenCompra
           SET Estado             = 'Aprobada',
               IdUsuarioAprobador = @IdUsuarioAprobador,
               FechaAprobacion    = GETDATE(),
               MotivoRechazo      = NULL
         WHERE IdOrdenCompra = @IdOrdenCompra;

        -- Registrar en historial de auditoría
        INSERT INTO dbo.HISTORIAL_ESTADO_OC
            (IdOrdenCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
        VALUES
            (@IdOrdenCompra, 'Pendiente', 'Aprobada', @IdUsuarioAprobador, 'Aprobación de OC');

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Orden de Compra aprobada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_AprobarOrdenCompra actualizado'
GO


PRINT '━━━ PASO 5: usp_RechazarOrdenCompra — corrige param + historial ━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RechazarOrdenCompra]
    @IdOrdenCompra      INT,
    @IdUsuarioAprobador INT,
    @IdMotivoRechazo    INT,
    @Motivo             VARCHAR(500) = NULL,   -- antes @MotivoLibre (corregido)
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual VARCHAR(20);
        SELECT @EstadoActual = Estado
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @EstadoActual IS NULL
        BEGIN SET @Resultado = 0; SET @Mensaje = 'OC no encontrada.'; RETURN; END

        IF @EstadoActual <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Solo se rechazan OC en estado Pendiente. Estado actual: ' + @EstadoActual;
            RETURN;
        END

        IF @IdMotivoRechazo IS NULL OR
           NOT EXISTS (SELECT 1 FROM dbo.MOTIVO_RECHAZO_OC
                       WHERE IdMotivoRechazo = @IdMotivoRechazo AND Activo = 1)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Debe seleccionar un motivo de rechazo válido.';
            RETURN;
        END

        BEGIN TRAN;

        UPDATE dbo.OrdenCompra
           SET Estado             = 'Rechazada',
               IdUsuarioAprobador = @IdUsuarioAprobador,
               FechaAprobacion    = GETDATE(),
               IdMotivoRechazo    = @IdMotivoRechazo,
               MotivoRechazo      = COALESCE(@Motivo, '')
         WHERE IdOrdenCompra = @IdOrdenCompra;

        -- Registrar en historial
        DECLARE @DescMotivo VARCHAR(120);
        SELECT @DescMotivo = Descripcion FROM dbo.MOTIVO_RECHAZO_OC WHERE IdMotivoRechazo = @IdMotivoRechazo;

        INSERT INTO dbo.HISTORIAL_ESTADO_OC
            (IdOrdenCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
        VALUES
            (@IdOrdenCompra, 'Pendiente', 'Rechazada', @IdUsuarioAprobador,
             'Motivo: ' + ISNULL(@DescMotivo, '') + ISNULL(' | ' + @Motivo, ''));

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje = 'OC rechazada.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_RechazarOrdenCompra actualizado'
GO


PRINT '━━━ PASO 6: usp_AnularOrdenCompra — agrega @IdUsuario + FechaAnulacion + historial'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_AnularOrdenCompra]
    @IdOrdenCompra INT,
    @IdUsuario     INT = 0,           -- parámetro nuevo (default 0 = sin usuario)
    @Resultado     BIT           OUTPUT,
    @Mensaje       NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual VARCHAR(20);
        SELECT @EstadoActual = Estado
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Orden de Compra no encontrada.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.CompraOrdenCompra WHERE IdOrdenCompra = @IdOrdenCompra)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No se puede anular: la orden ya tiene facturas vinculadas.';
            RETURN;
        END

        IF @EstadoActual NOT IN ('Pendiente', 'Aprobada', 'Rechazada')
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No se puede anular una OC en estado ' + @EstadoActual + '.';
            RETURN;
        END

        BEGIN TRAN;

        UPDATE dbo.OrdenCompra
           SET Estado         = 'Anulada',
               FechaAnulacion = GETDATE(),
               Activo         = 0
         WHERE IdOrdenCompra = @IdOrdenCompra;

        -- Historial (solo si se pasa un usuario válido)
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_OC
                (IdOrdenCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdOrdenCompra, @EstadoActual, 'Anulada', @IdUsuario, 'Anulación manual');
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Orden de Compra anulada.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_AnularOrdenCompra actualizado'
GO


PRINT '━━━ PASO 7: usp_ConfirmarCompraEImpactarStock — @IdUsuario + Estado + historial'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra   INT,
    @IdUsuario  INT = 0,              -- parámetro nuevo
    @Resultado  BIT           OUTPUT,
    @Mensaje    NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda         INT,
                @EstadoRecepcion  VARCHAR(20),
                @EstadoActual     VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @IdTienda          = IdTienda,
               @EstadoRecepcion   = EstadoRecepcion,
               @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Solo se puede confirmar una compra en estado EnRecepcion. Estado actual: ' + ISNULL(@EstadoRecepcion,'?');
            ROLLBACK; RETURN;
        END

        -- Validar segregación: el confirmador debe ser distinto al registrador
        IF @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'El usuario que registró la factura no puede confirmarla (segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- Validar stock máximo antes de impactar
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';

        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '      + CAST(ISNULL(pt.Stock,0) AS VARCHAR) +
               ', a recibir: '              + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '                 + CAST(pt.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto AND pt.IdTienda = @IdTienda
         INNER JOIN dbo.PRODUCTO p         ON p.IdProducto  = dc.IdProducto
         WHERE dc.IdCompra = @IdCompra
           AND dc.Activo   = 1
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > pt.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje = 'Confirmar superaría el stock máximo: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- Impactar stock
        ;WITH Recepcionado AS (
            SELECT IdProducto,
                   SUM(ISNULL(CantidadRecibida, Cantidad)) AS Cantidad
              FROM dbo.DETALLE_COMPRA
             WHERE IdCompra = @IdCompra
               AND Activo   = 1
               AND EstadoLinea IN ('Aceptada', 'NC')
             GROUP BY IdProducto
        )
        UPDATE pt
           SET Stock    = ISNULL(pt.Stock, 0) + r.Cantidad,
               Iniciado = 1
          FROM dbo.PRODUCTO_TIENDA pt
         INNER JOIN Recepcionado r ON pt.IdProducto = r.IdProducto
         WHERE pt.IdTienda = @IdTienda;

        -- Actualizar estado de la compra (ambas columnas para consistencia)
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- Registrar en historial
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdCompra, ISNULL(@EstadoActual,'Pendiente'), 'Confirmada', @IdUsuario, 'Confirmación de factura e impacto de stock');
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra confirmada. Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_ConfirmarCompraEImpactarStock actualizado'
GO


PRINT '━━━ PASO 8: usp_AnularCompra (SP nuevo) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_AnularCompra]
    @IdCompra   INT,
    @IdUsuario  INT,
    @Motivo     VARCHAR(500) = NULL,
    @Resultado  BIT           OUTPUT,
    @Mensaje    NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @EstadoActual VARCHAR(20), @IdUsuarioRegistro INT;

        SELECT @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra AND Activo = 1;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Compra no encontrada o ya anulada.';
            RETURN;
        END

        IF @EstadoActual = 'Confirmada'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No se puede anular una compra ya confirmada. Emita una Nota de Crédito si corresponde.';
            RETURN;
        END

        IF @EstadoActual = 'Anulada'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'La compra ya se encuentra anulada.';
            RETURN;
        END

        -- Validar que exista OP pendiente
        IF EXISTS (SELECT 1 FROM dbo.ORDEN_PAGO WHERE IdCompra = @IdCompra AND Activo = 1)
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Existe una Orden de Pago activa. Anule primero la OP antes de anular la compra.';
            RETURN;
        END

        BEGIN TRAN;

        UPDATE dbo.COMPRA
           SET Estado          = 'Anulada',
               EstadoRecepcion = 'Anulada',
               FechaAnulacion  = GETDATE(),
               MotivoAnulacion = @Motivo,
               Activo          = 0
         WHERE IdCompra = @IdCompra;

        -- Registrar en historial
        IF EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdCompra, @EstadoActual, 'Anulada', @IdUsuario,
                 ISNULL('Anulación | ' + @Motivo, 'Anulación manual'));
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra anulada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
PRINT '  OK: usp_AnularCompra creado'
GO


PRINT '━━━ PASO 9: usp_ObtenerListaCompra — agrega Estado y filtro ━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaCompra]
    @FechaInicio DATE,
    @FechaFin    DATE,
    @IdProveedor INT  = 0,
    @IdTienda    INT  = 0,
    @Estado      VARCHAR(20) = NULL    -- NULL = todos
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT DMY;

    SELECT
        c.IdCompra,
        RIGHT('000000' + CONVERT(VARCHAR, c.IdCompra), 6)  AS NumeroCompra,
        c.NumeroFactura,
        p.RazonSocial,
        t.Nombre,
        CONVERT(CHAR(10), c.FechaRegistro, 103)            AS FechaCompra,
        CONVERT(CHAR(10), c.FechaFactura,  103)            AS FechaFactura,
        c.TotalCosto,
        c.Estado,
        c.EstadoRecepcion,
        u.Nombres                                          AS UsuarioRegistro
    FROM dbo.COMPRA c
    INNER JOIN dbo.PROVEEDOR p ON p.IdProveedor = c.IdProveedor
    INNER JOIN dbo.TIENDA    t ON t.IdTienda    = c.IdTienda
    INNER JOIN dbo.USUARIO   u ON u.IdUsuario   = c.IdUsuario
    WHERE CONVERT(DATE, c.FechaRegistro) BETWEEN @FechaInicio AND @FechaFin
      AND p.IdProveedor = IIF(@IdProveedor = 0, p.IdProveedor, @IdProveedor)
      AND t.IdTienda    = IIF(@IdTienda    = 0, t.IdTienda,    @IdTienda)
      AND (@Estado IS NULL OR c.Estado = @Estado)
    ORDER BY c.IdCompra DESC;
END
GO
PRINT '  OK: usp_ObtenerListaCompra actualizado'
GO


PRINT '━━━ PASO 10: usp_ObtenerListaCompraRevision (SP nuevo) ━━━━━━━━━━━━━━━━━━━━━'
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaCompraRevision]
    @FechaInicio DATE,
    @FechaFin    DATE,
    @IdProveedor INT = 0,
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = 'Pendiente'   -- default = Pendiente
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT DMY;

    SELECT
        c.IdCompra,
        RIGHT('000000' + CONVERT(VARCHAR, c.IdCompra), 6)   AS NumeroCompra,
        c.NumeroFactura,
        c.NumeroTimbrado,
        p.IdProveedor,
        p.RazonSocial,
        t.IdTienda,
        t.Nombre                                             AS NombreTienda,
        CONVERT(CHAR(10), c.FechaRegistro,  103)             AS FechaRegistro,
        CONVERT(CHAR(10), c.FechaFactura,   103)             AS FechaFactura,
        CONVERT(CHAR(10), c.FechaEntrega,   103)             AS FechaEntrega,
        c.TotalCosto,
        c.Estado,
        c.EstadoRecepcion,
        c.IdUsuario                                          AS IdUsuarioRegistro,
        u.Nombres                                            AS UsuarioRegistro,
        -- OC vinculada (si aplica)
        oc.NumeroOrden,
        oc.IdOrdenCompra
    FROM dbo.COMPRA c
    INNER JOIN dbo.PROVEEDOR p  ON p.IdProveedor = c.IdProveedor
    INNER JOIN dbo.TIENDA    t  ON t.IdTienda    = c.IdTienda
    INNER JOIN dbo.USUARIO   u  ON u.IdUsuario   = c.IdUsuario
    LEFT  JOIN dbo.CompraOrdenCompra coc ON coc.IdCompra = c.IdCompra
    LEFT  JOIN dbo.OrdenCompra       oc  ON oc.IdOrdenCompra = coc.IdOrdenCompra
    WHERE c.Activo = 1
      AND CONVERT(DATE, c.FechaRegistro) BETWEEN @FechaInicio AND @FechaFin
      AND p.IdProveedor = IIF(@IdProveedor = 0, p.IdProveedor, @IdProveedor)
      AND t.IdTienda    = IIF(@IdTienda    = 0, t.IdTienda,    @IdTienda)
      AND (@Estado = 'Todos' OR c.Estado = @Estado)
    ORDER BY c.IdCompra DESC;
END
GO
PRINT '  OK: usp_ObtenerListaCompraRevision creado'
GO


PRINT '━━━ PASO 11: SUBMENU "Revisión de Compras" ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- Buscar el IdMenu del módulo Compras
DECLARE @IdMenuCompras INT;
SELECT @IdMenuCompras = IdMenu FROM dbo.MENU WHERE Nombre LIKE '%Compra%' AND Activo = 1;

IF @IdMenuCompras IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU
                   WHERE Controlador = 'Compra' AND Vista = 'Revision')
    BEGIN
        INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Activo, FechaRegistro)
        VALUES (@IdMenuCompras, 'Revisión de Compras', 'Compra', 'Revision',
                'fas fa-clipboard-check', 1, GETDATE());

        PRINT '  OK: SubMenu "Revisión de Compras" insertado';

        -- Insertar el permiso para todos los roles existentes (desactivado por defecto)
        -- El admin deberá activarlo para el rol "Revisor" o equivalente
        DECLARE @IdSubMenu INT = SCOPE_IDENTITY();
        INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo)
        SELECT IdRol, @IdSubMenu, 0
          FROM dbo.ROL;

        PRINT '  OK: permisos en PERMISOS creados (desactivados, activar por rol)';
    END
    ELSE PRINT '  SKIP: SubMenu Revisión ya existe';
END
ELSE
    PRINT '  WARN: No se encontró el menú Compras. Insertar el SUBMENU manualmente.';
GO


PRINT ''
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'SCRIPT 15 COMPLETADO — Segregación de Funciones O&M'
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'PRÓXIMOS PASOS:'
PRINT '  1. Activar el permiso "Revisión de Compras" para el rol Revisor/Aprobador'
PRINT '     en la pantalla de administración de permisos.'
PRINT '  2. Ejecutar la aplicación y verificar el flujo:'
PRINT '     Crear OC → Aprobar OC → Registrar Factura → Confirmar Factura'
PRINT '  3. Comprobar que las tablas HISTORIAL_ESTADO_OC y HISTORIAL_ESTADO_COMPRA'
PRINT '     registran cada transición de estado con usuario y fecha.'
PRINT ''
