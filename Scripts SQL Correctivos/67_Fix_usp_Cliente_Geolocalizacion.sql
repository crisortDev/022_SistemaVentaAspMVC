-- ============================================================
-- Script 67: Agregar @Geolocalizacion a usp_RegistrarCliente
--            y usp_ModificarCliente
-- Fecha: 2026-05-19
--
-- El campo Geolocalizacion fue agregado al código C# y a la
-- tabla CLIENTE, pero los SPs nunca fueron actualizados,
-- causando "too many arguments specified".
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ────────────────────────────────────────────────────────────
-- 1. usp_RegistrarCliente
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCliente
    @TipoDocumento   VARCHAR(30),
    @NumeroDocumento VARCHAR(20),
    @Nombre          VARCHAR(150),
    @Direccion       VARCHAR(200),
    @Telefono        VARCHAR(20),
    @Ciudad          VARCHAR(100) = NULL,
    @Barrio          VARCHAR(100) = NULL,
    @Calle           VARCHAR(100) = NULL,
    @NumeroCasa      VARCHAR(20)  = NULL,
    @Referencia      VARCHAR(200) = NULL,
    @Geolocalizacion VARCHAR(50)  = NULL,
    @Resultado       BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        INSERT INTO dbo.CLIENTE
            (TipoDocumento, NumeroDocumento, Nombre, Direccion, Telefono,
             Ciudad, Barrio, Calle, NumeroCasa, Referencia, Geolocalizacion,
             Activo, FechaRegistro)
        VALUES
            (@TipoDocumento, @NumeroDocumento, @Nombre, @Direccion, @Telefono,
             @Ciudad, @Barrio, @Calle, @NumeroCasa, @Referencia, @Geolocalizacion,
             1, GETDATE());

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_RegistrarCliente actualizado.';
GO

-- ────────────────────────────────────────────────────────────
-- 2. usp_ModificarCliente
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.usp_ModificarCliente
    @IdCliente       INT,
    @TipoDocumento   VARCHAR(30),
    @NumeroDocumento VARCHAR(20),
    @Nombre          VARCHAR(150),
    @Direccion       VARCHAR(200),
    @Telefono        VARCHAR(20),
    @Activo          BIT,
    @Ciudad          VARCHAR(100) = NULL,
    @Barrio          VARCHAR(100) = NULL,
    @Calle           VARCHAR(100) = NULL,
    @NumeroCasa      VARCHAR(20)  = NULL,
    @Referencia      VARCHAR(200) = NULL,
    @Geolocalizacion VARCHAR(50)  = NULL,
    @Resultado       BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE dbo.CLIENTE SET
            TipoDocumento   = @TipoDocumento,
            NumeroDocumento = @NumeroDocumento,
            Nombre          = @Nombre,
            Direccion       = @Direccion,
            Telefono        = @Telefono,
            Activo          = @Activo,
            Ciudad          = @Ciudad,
            Barrio          = @Barrio,
            Calle           = @Calle,
            NumeroCasa      = @NumeroCasa,
            Referencia      = @Referencia,
            Geolocalizacion = @Geolocalizacion
        WHERE IdCliente = @IdCliente;

        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        SET @Resultado = 0;
    END CATCH
END
GO
PRINT 'OK: usp_ModificarCliente actualizado.';
GO

PRINT '════ Script 67 completado ════';
GO
