-- ============================================================
-- Script 61: CRUD Puntos de Caja (maestro) + FK en CAJA (detalle)
-- Fecha: 2026-05-18
--
-- PUNTO_CAJA: representa una caja física por tienda (Caja 1, Caja 2…)
-- CAJA:       cada sesión de apertura/cierre queda ligada a un punto de caja
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── 1. Tabla PUNTO_CAJA ──────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.PUNTO_CAJA') AND type = 'U')
BEGIN
    CREATE TABLE dbo.PUNTO_CAJA (
        IdPuntoCaja  INT           IDENTITY(1,1) NOT NULL,
        IdTienda     INT           NOT NULL,
        Nombre       VARCHAR(50)   NOT NULL,          -- "Caja 1", "Caja Principal"
        Descripcion  VARCHAR(200)  NULL,
        Activo       BIT           NOT NULL DEFAULT 1,
        FechaRegistro DATETIME     NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_PUNTO_CAJA PRIMARY KEY (IdPuntoCaja),
        CONSTRAINT FK_PUNTO_CAJA_Tienda FOREIGN KEY (IdTienda)
            REFERENCES dbo.TIENDA(IdTienda)
    );
    PRINT 'OK: Tabla PUNTO_CAJA creada.';
END
ELSE
    PRINT 'INFO: Tabla PUNTO_CAJA ya existía.';
GO

-- ── 2. FK opcional en CAJA → PUNTO_CAJA ─────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.CAJA') AND name = 'IdPuntoCaja'
)
BEGIN
    ALTER TABLE dbo.CAJA ADD IdPuntoCaja INT NULL;
    ALTER TABLE dbo.CAJA ADD CONSTRAINT FK_CAJA_PuntoCaja
        FOREIGN KEY (IdPuntoCaja) REFERENCES dbo.PUNTO_CAJA(IdPuntoCaja);
    PRINT 'OK: Columna IdPuntoCaja agregada a CAJA.';
END
ELSE
    PRINT 'INFO: Columna IdPuntoCaja ya existía en CAJA.';
GO

-- ── 3. usp_ObtenerPuntosCaja ─────────────────────────────────────────────────
-- Lista todos los puntos de caja (con conteo de sesiones)
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerPuntosCaja
    @IdTienda INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pc.IdPuntoCaja,
        pc.IdTienda,
        t.Nombre                                  AS NombreTienda,
        pc.Nombre,
        ISNULL(pc.Descripcion, '')                AS Descripcion,
        pc.Activo,
        pc.FechaRegistro,
        COUNT(c.IdCaja)                           AS TotalSesiones,
        SUM(CASE WHEN c.Estado = 'Abierta' THEN 1 ELSE 0 END) AS SesionesAbiertas,
        MAX(c.FechaApertura)                      AS UltimaApertura
    FROM dbo.PUNTO_CAJA pc
    INNER JOIN dbo.TIENDA t  ON t.IdTienda   = pc.IdTienda
    LEFT  JOIN dbo.CAJA   c  ON c.IdPuntoCaja = pc.IdPuntoCaja
    WHERE (@IdTienda = 0 OR pc.IdTienda = @IdTienda)
    GROUP BY pc.IdPuntoCaja, pc.IdTienda, t.Nombre,
             pc.Nombre, pc.Descripcion, pc.Activo, pc.FechaRegistro
    ORDER BY pc.IdTienda, pc.Nombre;
END
GO
PRINT 'OK: usp_ObtenerPuntosCaja creado.';
GO

-- ── 4. usp_RegistrarPuntoCaja ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPuntoCaja
    @IdTienda    INT,
    @Nombre      VARCHAR(50),
    @Descripcion VARCHAR(200),
    @Resultado   BIT           OUTPUT,
    @Mensaje     NVARCHAR(300) OUTPUT,
    @IdPuntoCaja INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF LTRIM(RTRIM(@Nombre)) = ''
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'El nombre de la caja es obligatorio.';
            SET @IdPuntoCaja = 0; RETURN;
        END
        IF EXISTS (
            SELECT 1 FROM dbo.PUNTO_CAJA
            WHERE IdTienda = @IdTienda AND Nombre = LTRIM(RTRIM(@Nombre)) AND Activo = 1
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Ya existe una caja con ese nombre en esta tienda.';
            SET @IdPuntoCaja = 0; RETURN;
        END

        INSERT INTO dbo.PUNTO_CAJA (IdTienda, Nombre, Descripcion, Activo)
        VALUES (@IdTienda, LTRIM(RTRIM(@Nombre)), NULLIF(LTRIM(RTRIM(@Descripcion)),''), 1);

        SET @IdPuntoCaja = SCOPE_IDENTITY();
        SET @Resultado   = 1;
        SET @Mensaje     = 'Punto de caja registrado correctamente.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0; SET @IdPuntoCaja = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarPuntoCaja creado.';
GO

-- ── 5. usp_ActualizarPuntoCaja ───────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ActualizarPuntoCaja
    @IdPuntoCaja INT,
    @Nombre      VARCHAR(50),
    @Descripcion VARCHAR(200),
    @Activo      BIT,
    @Resultado   BIT           OUTPUT,
    @Mensaje     NVARCHAR(300) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.PUNTO_CAJA WHERE IdPuntoCaja = @IdPuntoCaja)
        BEGIN
            SET @Resultado = 0; SET @Mensaje = 'Punto de caja no encontrado.'; RETURN;
        END
        -- Verificar nombre duplicado (excluyendo el propio)
        DECLARE @IdTienda INT;
        SELECT @IdTienda = IdTienda FROM dbo.PUNTO_CAJA WHERE IdPuntoCaja = @IdPuntoCaja;

        IF EXISTS (
            SELECT 1 FROM dbo.PUNTO_CAJA
            WHERE IdTienda = @IdTienda AND Nombre = LTRIM(RTRIM(@Nombre))
              AND IdPuntoCaja <> @IdPuntoCaja AND Activo = 1
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Ya existe otra caja con ese nombre en esta tienda.'; RETURN;
        END

        -- No permitir desactivar si tiene caja abierta
        IF @Activo = 0 AND EXISTS (
            SELECT 1 FROM dbo.CAJA WHERE IdPuntoCaja = @IdPuntoCaja AND Estado = 'Abierta'
        )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'No se puede desactivar: tiene una sesión de caja abierta.'; RETURN;
        END

        UPDATE dbo.PUNTO_CAJA
           SET Nombre      = LTRIM(RTRIM(@Nombre)),
               Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)),''),
               Activo      = @Activo
         WHERE IdPuntoCaja = @IdPuntoCaja;

        SET @Resultado = 1;
        SET @Mensaje   = 'Punto de caja actualizado.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ActualizarPuntoCaja creado.';
GO

-- ── 6. usp_ObtenerSesionesPorPunto ──────────────────────────────────────────
-- Detalle: sesiones (turnos) de un punto de caja
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerSesionesPorPunto
    @IdPuntoCaja INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.IdCaja,
        ua.Nombres + ' ' + ua.Apellidos              AS Aperturista,
        c.FechaApertura,
        c.MontoApertura,
        c.FechaCierre,
        ISNULL(uc.Nombres + ' ' + uc.Apellidos, '—') AS UsuarioCierre,
        c.MontoSistema,
        c.MontoContado,
        c.Diferencia,
        c.Estado,
        c.Observacion,
        -- ventas del turno
        COUNT(v.IdVenta)                              AS CantidadVentas,
        ISNULL(SUM(CASE WHEN v.Estado='Activa' THEN v.TotalCosto ELSE 0 END), 0) AS TotalVentas
    FROM dbo.CAJA c
    INNER JOIN dbo.USUARIO ua ON ua.IdUsuario  = c.IdUsuario
    LEFT  JOIN dbo.USUARIO uc ON uc.IdUsuario  = c.IdUsuarioCierre
    LEFT  JOIN dbo.VENTA   v  ON v.IdTienda    = c.IdTienda
                              AND v.FechaRegistro >= c.FechaApertura
                              AND v.FechaRegistro <= ISNULL(c.FechaCierre, GETDATE())
    WHERE c.IdPuntoCaja = @IdPuntoCaja
    GROUP BY c.IdCaja, ua.Nombres, ua.Apellidos, c.FechaApertura,
             c.MontoApertura, c.FechaCierre, uc.Nombres, uc.Apellidos,
             c.MontoSistema, c.MontoContado, c.Diferencia, c.Estado, c.Observacion
    ORDER BY c.FechaApertura DESC;
END
GO
PRINT 'OK: usp_ObtenerSesionesPorPunto creado.';
GO

-- ── 7. usp_AbrirCaja — actualizar para aceptar IdPuntoCaja ──────────────────
CREATE OR ALTER PROCEDURE dbo.usp_AbrirCaja
    @IdTienda       INT,
    @IdUsuario      INT,
    @MontoApertura  DECIMAL(18,2),
    @IdPuntoCaja    INT = NULL,       -- opcional; NULL = sin punto asignado
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT,
    @IdCaja         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdTienda = @IdTienda AND Estado = 'Abierta')
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Ya existe una caja abierta para esta tienda. Debe cerrarla primero.';
            SET @IdCaja    = 0; ROLLBACK; RETURN;
        END
        IF @MontoApertura < 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El monto de apertura no puede ser negativo.';
            SET @IdCaja    = 0; ROLLBACK; RETURN;
        END

        INSERT INTO dbo.CAJA (IdTienda, IdUsuario, MontoApertura, Estado, IdPuntoCaja)
        VALUES (@IdTienda, @IdUsuario, @MontoApertura, 'Abierta',
                NULLIF(@IdPuntoCaja, 0));

        SET @IdCaja    = SCOPE_IDENTITY();
        SET @Resultado = 1;
        SET @Mensaje   = 'Caja abierta correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @IdCaja = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AbrirCaja actualizado (acepta IdPuntoCaja).';
GO

-- ── Datos de ejemplo ─────────────────────────────────────────────────────────
-- Insertar puntos de caja para la tienda 1 (ajustar según tus datos)
IF NOT EXISTS (SELECT 1 FROM dbo.PUNTO_CAJA WHERE IdTienda = 1)
BEGIN
    INSERT INTO dbo.PUNTO_CAJA (IdTienda, Nombre, Descripcion)
    VALUES (1, 'Caja 1', 'Caja principal de ventas'),
           (1, 'Caja 2', 'Caja secundaria');
    PRINT 'OK: Puntos de caja de ejemplo insertados para tienda 1.';
END
GO

PRINT '════ Script 61 completado ════';
GO
