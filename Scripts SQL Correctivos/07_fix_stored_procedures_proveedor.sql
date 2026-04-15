-- ============================================================
-- SCRIPT 07: Actualizar Stored Procedures de PROVEEDOR
--
-- BUGS ENCONTRADOS:
--
-- 1. usp_RegistrarProveedor:
--    - No tenía parámetros @Ciudad, @Barrio, @Calle, @Referencia,
--      @Geolocalizacion → SQL Server lanzaba "too many arguments"
--    - El INSERT no grababa esos campos aunque existieran en la tabla
--
-- 2. usp_ModificarProveedor:
--    - Misma situación: no tenía los 5 parámetros extra
--    - El UPDATE no grababa Ciudad, Barrio, Calle, Referencia,
--      ni Geolocalizacion
--
-- 3. usp_ObtenerProveedores:
--    - Solo devolvía 7 columnas básicas, pero CD_Proveedor.cs
--      intenta leer Ciudad, Geolocalizacion, Barrio, Calle,
--      Referencia → IndexOutOfRangeException silencioso
--
-- CAUSA ADICIONAL EN C# (ya corregida en CD_Proveedor.cs):
--    - RegistrarProveedor registraba el parámetro OUTPUT como
--      "@Resultado" pero lo leía como "Resultado" (sin @)
--      → KeyNotFoundException: "no contiene SqlParameter 'Resultado'"
-- ============================================================

USE DBVENTAS_WEB;
GO

-- ============================================================
-- 1. usp_ObtenerProveedores — devolver todos los campos
-- ============================================================
ALTER PROCEDURE [dbo].[usp_ObtenerProveedores]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdProveedor,
        RUC,
        RazonSocial,
        Telefono,
        Correo,
        Direccion,
        Activo,
        ISNULL(Ciudad,          '') AS Ciudad,
        ISNULL(Geolocalizacion, '') AS Geolocalizacion,
        ISNULL(Barrio,          '') AS Barrio,
        ISNULL(Calle,           '') AS Calle,
        ISNULL(Referencia,      '') AS Referencia
    FROM PROVEEDOR
    ORDER BY RazonSocial ASC;
END
GO

-- ============================================================
-- 2. usp_RegistrarProveedor — agregar campos de dirección extendida
-- ============================================================
ALTER PROCEDURE [dbo].[usp_RegistrarProveedor]
(
    @Ruc             VARCHAR(50),
    @RazonSocial     VARCHAR(100),
    @Telefono        VARCHAR(50),
    @Correo          VARCHAR(50),
    @Direccion       VARCHAR(50),
    @Ciudad          VARCHAR(100) = NULL,
    @Barrio          VARCHAR(100) = NULL,
    @Calle           VARCHAR(100) = NULL,
    @Referencia      VARCHAR(255) = NULL,
    @Geolocalizacion VARCHAR(255) = NULL,
    @Resultado       BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 1;

    IF NOT EXISTS (SELECT 1 FROM PROVEEDOR WHERE RUC = @Ruc)
    BEGIN
        INSERT INTO PROVEEDOR (RUC, RazonSocial, Telefono, Correo, Direccion,
                               Ciudad, Barrio, Calle, Referencia, Geolocalizacion,
                               Activo, FechaRegistro)
        VALUES (@Ruc, @RazonSocial, @Telefono, @Correo, @Direccion,
                @Ciudad, @Barrio, @Calle, @Referencia, @Geolocalizacion,
                1, GETDATE());
    END
    ELSE
        SET @Resultado = 0;
END
GO

-- ============================================================
-- 3. usp_ModificarProveedor — agregar campos de dirección extendida
-- ============================================================
ALTER PROCEDURE [dbo].[usp_ModificarProveedor]
(
    @IdProveedor     INT,
    @Ruc             VARCHAR(50),
    @RazonSocial     VARCHAR(100),
    @Telefono        VARCHAR(50),
    @Correo          VARCHAR(50),
    @Direccion       VARCHAR(50),
    @Activo          BIT,
    @Ciudad          VARCHAR(100) = NULL,
    @Barrio          VARCHAR(100) = NULL,
    @Calle           VARCHAR(100) = NULL,
    @Referencia      VARCHAR(255) = NULL,
    @Geolocalizacion VARCHAR(255) = NULL,
    @Resultado       BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 1;

    IF NOT EXISTS (SELECT 1 FROM PROVEEDOR WHERE RUC = @Ruc AND IdProveedor != @IdProveedor)
    BEGIN
        UPDATE PROVEEDOR
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
    END
    ELSE
        SET @Resultado = 0;
END
GO

-- ============================================================
-- Verificación
-- ============================================================
-- EXEC usp_ObtenerProveedores;
-- ============================================================

PRINT 'Script 07 completado: Stored Procedures de PROVEEDOR actualizados correctamente.';
GO
