-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 33: Módulo de Nota de Crédito formal
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- Contexto normativo (SET Paraguay / ex-DNT):
--   La Nota de Crédito es un documento fiscal que el PROVEEDOR debe emitir
--   con timbrado autorizado por SET dentro de los 30 días corridos desde
--   la fecha de la factura original.  El receptor (la empresa compradora)
--   debe registrarla con su número y timbrado para deducirla del IVA.
--
-- Flujo implementado:
--   1. Al guardar la recepción con diferencia → se crea NOTA_CREDITO con
--      Estado = 'Pendiente' (sin número, esperando el documento físico).
--   2. Módulo "Gestión NC" → operador registra NumeroNC + timbrado cuando
--      el proveedor trae el documento → Estado = 'Recibida'.
--   3. El SP de Confirmar Compra bloquea si hay NC con Estado ≠ 'Recibida'.
--   4. Estado 'Morosa' es calculado: Estado='Pendiente' y > 30 días
--      desde la fecha del registro (no se guarda en tabla, se muestra en vista).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Crear tabla NOTA_CREDITO ─────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'NOTA_CREDITO')
BEGIN
    CREATE TABLE [dbo].[NOTA_CREDITO] (
        [IdNC]                INT IDENTITY(1,1) NOT NULL,
        [IdCompra]            INT           NOT NULL,
        [IdMotivoNC]          INT           NOT NULL,
        -- Datos del documento fiscal (los completa el operador cuando
        -- el proveedor trae el papel)
        [NumeroNC]            VARCHAR(20)   NULL,   -- formato SET PY: xxx-xxx-xxxxxxx
        [NumeroTimbrado]      VARCHAR(20)   NULL,   -- timbrado autorizado por SET
        [FechaVencTimbrado]   DATE          NULL,   -- vencimiento del timbrado
        [FechaEmision]        DATE          NULL,   -- fecha en que el proveedor emitió la NC
        -- Importes
        [Monto]               DECIMAL(18,2) NOT NULL DEFAULT 0,
        -- Estado del ciclo de vida
        [Estado]              VARCHAR(20)   NOT NULL DEFAULT 'Pendiente',
          -- Pendiente : generada internamente; proveedor aún no trajo el doc
          -- Recibida  : doc físico en mano; confirmación habilitada
          -- Rechazada : doc inválido (timbrado vencido, monto incorrecto, etc.)
        [Observacion]         VARCHAR(500)  NULL,
        -- Auditoría
        [IdUsuarioRegistro]   INT           NOT NULL,
        [FechaRegistro]       DATETIME      NOT NULL DEFAULT GETDATE(),
        [IdUsuarioConfirma]   INT           NULL,
        [FechaConfirmacion]   DATETIME      NULL,

        CONSTRAINT [PK_NOTA_CREDITO] PRIMARY KEY CLUSTERED ([IdNC] ASC),
        CONSTRAINT [FK_NC_Compra]    FOREIGN KEY ([IdCompra])  REFERENCES [dbo].[COMPRA]([IdCompra]),
        CONSTRAINT [FK_NC_Motivo]    FOREIGN KEY ([IdMotivoNC]) REFERENCES [dbo].[MOTIVO_NOTA_CREDITO]([IdMotivoNotaCredito]),
        CONSTRAINT [CK_NC_Estado]    CHECK ([Estado] IN ('Pendiente','Recibida','Rechazada')),
        CONSTRAINT [UQ_NC_Compra]    UNIQUE ([IdCompra])   -- 1 NC por compra
    );

    PRINT 'OK: Tabla NOTA_CREDITO creada.';
END
ELSE
    PRINT 'INFO: Tabla NOTA_CREDITO ya existe.';
GO

-- ── 2. usp_RegistrarNotaCredito ─────────────────────────────────────────────
--    Llamado al hacer clic en "Generar NC" desde Recepción o Revisión.
--    Crea el registro en Pendiente Y actualiza COMPRA.MontoNotaCredito
--    (para compatibilidad con documentos existentes).
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

        -- Si ya existe NC para esta compra, no duplicar
        IF EXISTS (SELECT 1 FROM dbo.NOTA_CREDITO WHERE IdCompra = @IdCompra)
        BEGIN
            -- Solo actualizar el monto en COMPRA si cambió
            UPDATE dbo.COMPRA
               SET MontoNotaCredito   = @MontoNC,
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

        -- Actualizar COMPRA (compatibilidad con documentos / reportes existentes)
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
PRINT 'OK: usp_RegistrarNotaCredito creado.';
GO

-- ── 3. usp_ConfirmarRecepcionNC ─────────────────────────────────────────────
--    El operador llama a este SP cuando el proveedor trae el documento físico.
--    Carga NumeroNC, timbrado y fecha de emisión → Estado = 'Recibida'.
CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarRecepcionNC]
    @IdNC               INT,
    @NumeroNC           VARCHAR(20),
    @NumeroTimbrado     VARCHAR(20),
    @FechaVencTimbrado  DATE,
    @FechaEmision       DATE,
    @Observacion        VARCHAR(500),
    @IdUsuario          INT,
    @Resultado          BIT           OUTPUT,
    @Mensaje            NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @EstadoActual VARCHAR(20);
        SELECT @EstadoActual = Estado
          FROM dbo.NOTA_CREDITO
         WHERE IdNC = @IdNC;

        IF @EstadoActual IS NULL
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Nota de Crédito no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoActual <> 'Pendiente'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se pueden confirmar NCs en estado Pendiente. Estado actual: ' + @EstadoActual;
            ROLLBACK; RETURN;
        END

        -- Validar formato básico de NumeroNC (xxx-xxx-xxxxxxx)
        IF @NumeroNC IS NULL OR LEN(LTRIM(RTRIM(@NumeroNC))) < 5
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Debe ingresar el número de la Nota de Crédito.';
            ROLLBACK; RETURN;
        END

        IF @FechaEmision > GETDATE()
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'La fecha de emisión no puede ser futura.';
            ROLLBACK; RETURN;
        END

        -- Verificar que la NC fue emitida dentro de los 30 días de la factura (SET PY)
        DECLARE @FechaFactura DATE;
        SELECT @FechaFactura = FechaFactura
          FROM dbo.COMPRA c
         INNER JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
         WHERE nc.IdNC = @IdNC;

        IF @FechaFactura IS NOT NULL AND DATEDIFF(DAY, @FechaFactura, @FechaEmision) > 30
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Advertencia SET PY: la NC fue emitida más de 30 días después '
                           + 'de la fecha de la factura. Verificar con el proveedor.';
            ROLLBACK; RETURN;
        END

        UPDATE dbo.NOTA_CREDITO
           SET NumeroNC           = LTRIM(RTRIM(@NumeroNC)),
               NumeroTimbrado     = LTRIM(RTRIM(@NumeroTimbrado)),
               FechaVencTimbrado  = @FechaVencTimbrado,
               FechaEmision       = @FechaEmision,
               Estado             = 'Recibida',
               Observacion        = @Observacion,
               IdUsuarioConfirma  = @IdUsuario,
               FechaConfirmacion  = GETDATE()
         WHERE IdNC = @IdNC;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Nota de Crédito confirmada como Recibida. Puede proceder a confirmar la compra.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ConfirmarRecepcionNC creado.';
GO

-- ── 4. usp_RechazarNC ──────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RechazarNC]
    @IdNC        INT,
    @Observacion VARCHAR(500),
    @IdUsuario   INT,
    @Resultado   BIT           OUTPUT,
    @Mensaje     NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.NOTA_CREDITO WHERE IdNC = @IdNC AND Estado = 'Pendiente')
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'NC no encontrada o no está en estado Pendiente.';
            RETURN;
        END

        UPDATE dbo.NOTA_CREDITO
           SET Estado            = 'Rechazada',
               Observacion       = @Observacion,
               IdUsuarioConfirma = @IdUsuario,
               FechaConfirmacion = GETDATE()
         WHERE IdNC = @IdNC;

        SET @Resultado = 1; SET @Mensaje = 'Nota de Crédito rechazada.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0; SET @Mensaje = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RechazarNC creado.';
GO

-- ── 5. usp_ObtenerNotasCredito ──────────────────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerNotasCredito]
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        nc.IdNC,
        nc.IdCompra,
        c.NumeroFactura,
        c.FechaFactura,
        c.TotalCosto             AS MontoFactura,
        nc.Monto                 AS MontoNC,
        p.RazonSocial            AS Proveedor,
        p.Ruc                    AS RucProveedor,
        t.Nombre                 AS Tienda,
        mnc.Descripcion          AS MotivoNC,
        nc.NumeroNC,
        nc.NumeroTimbrado,
        nc.FechaVencTimbrado,
        nc.FechaEmision,
        nc.Estado,
        nc.Observacion,
        nc.FechaRegistro,
        nc.FechaConfirmacion,
        -- Días transcurridos desde el registro (para detectar mora visual)
        DATEDIFF(DAY, nc.FechaRegistro, GETDATE()) AS DiasTranscurridos,
        -- Flag de mora: Pendiente + más de 30 días desde fecha factura
        CASE
            WHEN nc.Estado = 'Pendiente'
             AND c.FechaFactura IS NOT NULL
             AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
            THEN 1 ELSE 0
        END AS EsMorosa,
        -- Usuario que registró
        ISNULL(u.Nombres + ' ' + u.Apellidos, 'Sistema') AS UsuarioRegistro
      FROM dbo.NOTA_CREDITO nc
     INNER JOIN dbo.COMPRA                c   ON c.IdCompra            = nc.IdCompra
     INNER JOIN dbo.PROVEEDOR             p   ON p.IdProveedor         = c.IdProveedor
     INNER JOIN dbo.TIENDA                t   ON t.IdTienda            = c.IdTienda
     INNER JOIN dbo.MOTIVO_NOTA_CREDITO   mnc ON mnc.IdMotivoNotaCredito = nc.IdMotivoNC
      LEFT JOIN dbo.USUARIO               u   ON u.IdUsuario           = nc.IdUsuarioRegistro
     WHERE (@IdTienda = 0 OR c.IdTienda = @IdTienda)
       AND (@Estado   = '' OR nc.Estado = @Estado)
     ORDER BY
        -- Morosas primero, luego Pendientes, luego el resto
        CASE WHEN nc.Estado='Pendiente' AND DATEDIFF(DAY,c.FechaFactura,GETDATE())>30 THEN 0
             WHEN nc.Estado='Pendiente' THEN 1
             WHEN nc.Estado='Recibida'  THEN 2
             ELSE 3 END,
        nc.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerNotasCredito creado.';
GO

-- ── 6. Actualizar usp_ConfirmarCompraEImpactarStock ─────────────────────────
--    Ahora verifica que si hay NOTA_CREDITO asociada, debe estar en 'Recibida'.
CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra      INT,
    @IdUsuario     INT  = 0,
    @EsSuperAdmin  BIT  = 0,
    @Resultado     BIT           OUTPUT,
    @Mensaje       NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda          INT,
                @EstadoRecepcion   VARCHAR(20),
                @EstadoActual      VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @IdTienda          = IdTienda,
               @EstadoRecepcion   = EstadoRecepcion,
               @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA WHERE IdCompra = @IdCompra;

        IF @IdTienda IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='Compra no encontrada.'; ROLLBACK; RETURN; END

        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Solo se puede confirmar en estado EnRecepcion. Actual: '+ISNULL(@EstadoRecepcion,'?');
            ROLLBACK; RETURN;
        END

        -- ── Validar NC: si hay diferencias debe existir NC en estado 'Recibida' ──
        DECLARE @HayDiferencia BIT = 0;
        IF EXISTS (
            SELECT 1 FROM dbo.DETALLE_COMPRA
             WHERE IdCompra = @IdCompra AND Activo = 1
               AND ISNULL(CantidadRecibida, Cantidad) < Cantidad
        ) SET @HayDiferencia = 1;

        IF @HayDiferencia = 1
        BEGIN
            DECLARE @EstadoNC VARCHAR(20);
            SELECT @EstadoNC = Estado
              FROM dbo.NOTA_CREDITO WHERE IdCompra = @IdCompra;

            IF @EstadoNC IS NULL
            BEGIN
                SET @Resultado=0;
                SET @Mensaje='Existen diferencias en cantidades. Debe generar la Nota de Crédito primero.';
                ROLLBACK; RETURN;
            END

            IF @EstadoNC <> 'Recibida'
            BEGIN
                SET @Resultado=0;
                SET @Mensaje='La Nota de Crédito está en estado "'+ @EstadoNC +'". '
                           + 'Debe registrar el documento físico del proveedor (estado Recibida) '
                           + 'desde Compras → Gestión de NC antes de confirmar.';
                ROLLBACK; RETURN;
            END
        END

        -- ── Validar segregación O&M ───────────────────────────────────────────
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='El usuario que registró la factura no puede confirmarla (segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- ── Validar stock máximo (PRODUCTO.StockMaximo) ───────────────────────
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';
        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: ' + CAST(ISNULL(pt.Stock,0) AS VARCHAR) +
               ', a recibir: '         + CAST(ISNULL(dc.CantidadRecibida,dc.Cantidad) AS VARCHAR) +
               ', máximo: '            + CAST(p.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO p         ON p.IdProducto  = dc.IdProducto
          LEFT JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                          AND pt.IdTienda   = @IdTienda
         WHERE dc.IdCompra   = @IdCompra AND dc.Activo = 1
           AND p.StockMaximo > 0
           AND ISNULL(pt.Stock,0) + ISNULL(dc.CantidadRecibida,dc.Cantidad) > p.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Confirmar superaría el stock máximo en: '+@ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ── Auto-crear PRODUCTO_TIENDA para productos nuevos ─────────────────
        INSERT INTO dbo.PRODUCTO_TIENDA
            (IdProducto, IdTienda, PrecioUnidadCompra, PrecioUnidadVenta,
             Stock, StockMinimo, StockMaximo, LimiteCompraDiaria, Iniciado, Activo, FechaRegistro)
        SELECT DISTINCT dc.IdProducto, @IdTienda, dc.PrecioUnitarioCompra,
                        0, 0, 0, 0, 0, 0, 1, GETDATE()
          FROM dbo.DETALLE_COMPRA dc
         WHERE dc.IdCompra = @IdCompra AND dc.Activo = 1
           AND dc.EstadoLinea IN ('Aceptada','NC')
           AND NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO_TIENDA pt
                            WHERE pt.IdProducto=dc.IdProducto AND pt.IdTienda=@IdTienda);

        -- ── Impactar stock ────────────────────────────────────────────────────
        ;WITH R AS (
            SELECT IdProducto, SUM(ISNULL(CantidadRecibida,Cantidad)) AS Qty
              FROM dbo.DETALLE_COMPRA
             WHERE IdCompra=@IdCompra AND Activo=1 AND EstadoLinea IN ('Aceptada','NC')
             GROUP BY IdProducto
        )
        UPDATE pt SET Stock=ISNULL(pt.Stock,0)+r.Qty, Iniciado=1
          FROM dbo.PRODUCTO_TIENDA pt INNER JOIN R r ON pt.IdProducto=r.IdProducto
         WHERE pt.IdTienda=@IdTienda;

        -- ── Actualizar estado ─────────────────────────────────────────────────
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario>0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- ── Historial ─────────────────────────────────────────────────────────
        IF @IdUsuario>0 AND EXISTS(SELECT 1 FROM dbo.USUARIO WHERE IdUsuario=@IdUsuario)
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra,EstadoAnterior,EstadoNuevo,IdUsuario,Observacion)
            VALUES(@IdCompra,ISNULL(@EstadoActual,'Pendiente'),'Confirmada',@IdUsuario,
                   CASE WHEN @EsSuperAdmin=1 THEN 'Confirmación por SuperAdmin'
                        ELSE 'Confirmación de factura e impacto de stock' END);

        COMMIT;
        SET @Resultado=1; SET @Mensaje='Compra confirmada. Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Resultado=0; SET @Mensaje='Error al confirmar: '+ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ConfirmarCompraEImpactarStock actualizado (verifica NC Recibida).';
GO

PRINT '════════════════════════════════════════════════════════';
PRINT 'Script 33 completado. Verificar:';
PRINT '  SELECT * FROM NOTA_CREDITO;';
PRINT '════════════════════════════════════════════════════════';
GO
