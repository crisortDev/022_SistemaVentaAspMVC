-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 29: Agregar IvaPorcentaje a la tabla PRODUCTO
--            Actualizar SPs: usp_ObtenerProductos, usp_RegistrarProducto
--            Crear SP:       usp_ModificarProducto
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-11
--
-- Regla de negocio:
--   • Cada producto tiene su propio porcentaje de IVA (10%, 5% o 0%).
--   • El IVA se carga automáticamente al agregar el producto a una OC.
--   • Los productos existentes quedan con IVA = 10 % por defecto.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Agregar columna (solo si no existe) ──────────────────────────────────
IF NOT EXISTS (
    SELECT 1
      FROM sys.columns
     WHERE object_id = OBJECT_ID('dbo.PRODUCTO')
       AND name      = 'IvaPorcentaje'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO
        ADD IvaPorcentaje DECIMAL(5,2) NOT NULL
            CONSTRAINT DF_PRODUCTO_IvaPorcentaje DEFAULT 10;

    PRINT 'OK: Columna IvaPorcentaje agregada a PRODUCTO (default 10).';
END
ELSE
    PRINT 'INFO: Columna IvaPorcentaje ya existe — no se modifica.';
GO

-- ── 2. usp_ObtenerProductos — incluir IvaPorcentaje ────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductos]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProducto,
        p.Codigo,
        p.ValorCodigo,
        p.Nombre,
        p.Descripcion       AS DescripcionProducto,
        p.IdCategoria,
        c.Descripcion       AS DescripcionCategoria,
        p.IvaPorcentaje,
        p.Activo
      FROM dbo.PRODUCTO p
      LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
     ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductos actualizado (incluye IvaPorcentaje).';
GO

-- ── 3. usp_RegistrarProducto — agregar @IvaPorcentaje ──────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarProducto]
    @Nombre        NVARCHAR(200),
    @Descripcion   NVARCHAR(500),
    @IdCategoria   INT,
    @IvaPorcentaje DECIMAL(5,2) = 10,
    @Resultado     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar que el nombre no esté duplicado
        IF EXISTS (
            SELECT 1 FROM dbo.PRODUCTO
             WHERE LTRIM(RTRIM(Nombre)) = LTRIM(RTRIM(@Nombre))
        )
        BEGIN
            SET @Resultado = 0; RETURN;
        END

        -- Generar código correlativo
        DECLARE @ValorCodigo INT;
        SELECT @ValorCodigo = ISNULL(MAX(ValorCodigo), 0) + 1
          FROM dbo.PRODUCTO;

        DECLARE @Codigo NVARCHAR(20) = RIGHT('000000' + CAST(@ValorCodigo AS VARCHAR), 6);

        INSERT INTO dbo.PRODUCTO
            (Codigo, ValorCodigo, Nombre, Descripcion, IdCategoria, IvaPorcentaje, PrecioVenta, Activo, FechaRegistro)
        VALUES
            (@Codigo, @ValorCodigo, @Nombre, @Descripcion, @IdCategoria, @IvaPorcentaje, 0, 1, GETDATE());

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarProducto actualizado (incluye @IvaPorcentaje).';
GO

-- ── 4. usp_ModificarProducto — SP dedicado para edición ────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ModificarProducto]
    @IdProducto    INT,
    @Nombre        NVARCHAR(200),
    @Descripcion   NVARCHAR(500),
    @IdCategoria   INT,
    @IvaPorcentaje DECIMAL(5,2) = 10,
    @Activo        BIT          = 1,
    @Resultado     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar existencia
        IF NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO WHERE IdProducto = @IdProducto)
        BEGIN
            SET @Resultado = 0; RETURN;
        END

        UPDATE dbo.PRODUCTO
           SET Nombre        = @Nombre,
               Descripcion   = @Descripcion,
               IdCategoria   = @IdCategoria,
               IvaPorcentaje = @IvaPorcentaje,
               Activo        = @Activo
         WHERE IdProducto    = @IdProducto;

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_ModificarProducto creado/actualizado.';
GO

-- ── 5. Diagnóstico: verificar columna y valores ─────────────────────────────
SELECT IdProducto, Codigo, Nombre, IvaPorcentaje, Activo
  FROM dbo.PRODUCTO
 ORDER BY Nombre;
GO
