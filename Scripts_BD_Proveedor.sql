-- ============================================================
-- SCRIPTS PARA ACTUALIZAR STORED PROCEDURES DE PROVEEDOR
-- Ejecutar en orden en SQL Server Management Studio
-- ============================================================

-- ------------------------------------------------------------
-- 1. Agregar columnas nuevas a la tabla Proveedor (si no existen)
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Proveedor' AND COLUMN_NAME = 'Ciudad')
    ALTER TABLE Proveedor ADD Ciudad VARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Proveedor' AND COLUMN_NAME = 'Geolocalizacion')
    ALTER TABLE Proveedor ADD Geolocalizacion VARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Proveedor' AND COLUMN_NAME = 'Barrio')
    ALTER TABLE Proveedor ADD Barrio VARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Proveedor' AND COLUMN_NAME = 'Calle')
    ALTER TABLE Proveedor ADD Calle VARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Proveedor' AND COLUMN_NAME = 'Referencia')
    ALTER TABLE Proveedor ADD Referencia VARCHAR(200) NULL;

GO

-- ------------------------------------------------------------
-- 2. usp_ObtenerProveedores
-- ------------------------------------------------------------
IF OBJECT_ID('usp_ObtenerProveedores', 'P') IS NOT NULL
    DROP PROCEDURE usp_ObtenerProveedores;
GO

CREATE PROCEDURE usp_ObtenerProveedores
AS
BEGIN
    SELECT
        IdProveedor,
        RUC,
        RazonSocial,
        Telefono,
        Correo,
        Direccion,
        Activo,
        ISNULL(Ciudad, '')        AS Ciudad,
        ISNULL(Geolocalizacion, '') AS Geolocalizacion,
        ISNULL(Barrio, '')        AS Barrio,
        ISNULL(Calle, '')         AS Calle,
        ISNULL(Referencia, '')    AS Referencia
    FROM Proveedor
    ORDER BY RazonSocial;
END
GO

-- ------------------------------------------------------------
-- 3. usp_RegistrarProveedor
-- ------------------------------------------------------------
IF OBJECT_ID('usp_RegistrarProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_RegistrarProveedor;
GO

CREATE PROCEDURE usp_RegistrarProveedor
    @Ruc            VARCHAR(20),
    @RazonSocial    VARCHAR(200),
    @Telefono       VARCHAR(30),
    @Correo         VARCHAR(100),
    @Direccion      VARCHAR(200),
    @Ciudad         VARCHAR(100),
    @Barrio         VARCHAR(100),
    @Calle          VARCHAR(100),
    @Referencia     VARCHAR(200),
    @Geolocalizacion VARCHAR(100),
    @Resultado      BIT OUTPUT
AS
BEGIN
    BEGIN TRY
        INSERT INTO Proveedor (RUC, RazonSocial, Telefono, Correo, Direccion, Activo,
                               Ciudad, Barrio, Calle, Referencia, Geolocalizacion)
        VALUES (@Ruc, @RazonSocial, @Telefono, @Correo, @Direccion, 1,
                @Ciudad, @Barrio, @Calle, @Referencia, @Geolocalizacion);

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- 4. usp_ModificarProveedor
-- ------------------------------------------------------------
IF OBJECT_ID('usp_ModificarProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_ModificarProveedor;
GO

CREATE PROCEDURE usp_ModificarProveedor
    @IdProveedor    INT,
    @Ruc            VARCHAR(20),
    @RazonSocial    VARCHAR(200),
    @Telefono       VARCHAR(30),
    @Correo         VARCHAR(100),
    @Direccion      VARCHAR(200),
    @Activo         BIT,
    @Ciudad         VARCHAR(100),
    @Barrio         VARCHAR(100),
    @Calle          VARCHAR(100),
    @Referencia     VARCHAR(200),
    @Geolocalizacion VARCHAR(100),
    @Resultado      BIT OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE Proveedor
        SET
            RUC             = @Ruc,
            RazonSocial     = @RazonSocial,
            Telefono        = @Telefono,
            Correo          = @Correo,
            Direccion       = @Direccion,
            Activo          = @Activo,
            Ciudad          = @Ciudad,
            Barrio          = @Barrio,
            Calle           = @Calle,
            Referencia      = @Referencia,
            Geolocalizacion = @Geolocalizacion
        WHERE IdProveedor = @IdProveedor;

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- 5. usp_EliminarProveedor
-- ------------------------------------------------------------
IF OBJECT_ID('usp_EliminarProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_EliminarProveedor;
GO

CREATE PROCEDURE usp_EliminarProveedor
    @IdProveedor INT,
    @Resultado   BIT OUTPUT,
    @Mensaje     NVARCHAR(300) OUTPUT
AS
BEGIN
    -- Verificar si tiene compras asociadas
    IF EXISTS (SELECT 1 FROM Compra WHERE IdProveedor = @IdProveedor)
    BEGIN
        SET @Resultado = 0;
        SET @Mensaje = 'El proveedor tiene compras registradas en el sistema y no puede eliminarse. Puede desactivarlo en su lugar.';
        RETURN;
    END

    BEGIN TRY
        DELETE FROM Proveedor WHERE IdProveedor = @IdProveedor;
        SET @Resultado = 1;
        SET @Mensaje = 'Proveedor eliminado correctamente.';
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
        -- Detectar error de clave foránea (error 547)
        IF ERROR_NUMBER() = 547
            SET @Mensaje = 'El proveedor está relacionado con otros registros del sistema y no puede eliminarse.';
        ELSE
            SET @Mensaje = 'Ocurrió un error inesperado al intentar eliminar. Código: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
    END CATCH
END
GO

-- ------------------------------------------------------------
-- 6. usp_ProveedorTieneCompras
--    Devuelve 1 si el proveedor tiene al menos una compra registrada
-- ------------------------------------------------------------
IF OBJECT_ID('usp_ProveedorTieneCompras', 'P') IS NOT NULL
    DROP PROCEDURE usp_ProveedorTieneCompras;
GO

CREATE PROCEDURE usp_ProveedorTieneCompras
    @IdProveedor INT,
    @Resultado   BIT OUTPUT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM Compra WHERE IdProveedor = @IdProveedor
    )
        SET @Resultado = 1;
    ELSE
        SET @Resultado = 0;
END
GO

-- ------------------------------------------------------------
-- 7. usp_DesactivarProveedor  (baja lógica)
-- ------------------------------------------------------------
IF OBJECT_ID('usp_DesactivarProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_DesactivarProveedor;
GO

CREATE PROCEDURE usp_DesactivarProveedor
    @IdProveedor INT,
    @Resultado   BIT OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE Proveedor SET Activo = 0 WHERE IdProveedor = @IdProveedor;
        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- 8. usp_ReactivarProveedor
-- ------------------------------------------------------------
IF OBJECT_ID('usp_ReactivarProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_ReactivarProveedor;
GO

CREATE PROCEDURE usp_ReactivarProveedor
    @IdProveedor INT,
    @Resultado   BIT OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE Proveedor SET Activo = 1 WHERE IdProveedor = @IdProveedor;
        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- 9. usp_VerificarRucProveedor
--    Devuelve 1 si el RUC ya existe en la tabla Proveedor
-- ------------------------------------------------------------
IF OBJECT_ID('usp_VerificarRucProveedor', 'P') IS NOT NULL
    DROP PROCEDURE usp_VerificarRucProveedor;
GO

CREATE PROCEDURE usp_VerificarRucProveedor
    @Ruc    VARCHAR(20),
    @Existe BIT OUTPUT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Proveedor WHERE RUC = @Ruc)
        SET @Existe = 1;
    ELSE
        SET @Existe = 0;
END
GO
