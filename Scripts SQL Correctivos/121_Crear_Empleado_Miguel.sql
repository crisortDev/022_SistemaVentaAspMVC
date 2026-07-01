-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 121: Crear ficha de Empleado/Persona para el usuario Miguel y vincularlo
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03
--
-- El usuario miguel123@gmail.com (IdUsuario 24, Repositor, Tienda 1) no tenía
-- EMPLEADO ni Persona. Este script crea la Persona, el Empleado (tienda 1) y
-- actualiza USUARIO.IdEmpleado para vincularlos. Así el login y los reportes
-- muestran sus datos completos y respeta el modelo (cada usuario = un empleado).
--
-- Idempotente: no duplica si ya existe la persona con ese documento.
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @IdUsuario INT = 24;        -- miguel123@gmail.com
    DECLARE @IdTienda  INT = 1;
    DECLARE @Documento NVARCHAR(20) = '5566778';   -- CI demo (cambiá por la real si la tenés)
    DECLARE @IdPersona INT, @IdEmpleado INT;

    -- 1) Persona (reutiliza si ya existe por documento)
    SELECT @IdPersona = IdPersona FROM dbo.PERSONA WHERE Documento = @Documento;

    IF @IdPersona IS NULL
    BEGIN
        INSERT INTO dbo.PERSONA
            (Nombres, Apellidos, TipoDocumento, Documento, Correo, Telefono,
             Ciudad, Barrio, Calle1, FechaRegistro, Activo)
        VALUES
            ('Miguel', 'Cubas', 'CI', @Documento, 'miguel123@gmail.com', '0981-555666',
             'Asunción', 'Centro', 'Calle Principal', GETDATE(), 1);
        SET @IdPersona = SCOPE_IDENTITY();
        PRINT 'OK: Persona creada (IdPersona=' + CAST(@IdPersona AS VARCHAR) + ').';
    END
    ELSE
        PRINT 'INFO: Persona ya existía (IdPersona=' + CAST(@IdPersona AS VARCHAR) + ').';

    -- 2) Empleado vinculado a esa persona
    SELECT @IdEmpleado = IdEmpleado FROM dbo.EMPLEADO WHERE IdPersona = @IdPersona;

    IF @IdEmpleado IS NULL
    BEGIN
        INSERT INTO dbo.EMPLEADO
            (Nombres, Apellidos, IdTienda, Activo, FechaRegistro, IdPersona, FechaIngreso)
        VALUES
            ('Miguel', 'Cubas', @IdTienda, 1, GETDATE(), @IdPersona, CAST(GETDATE() AS DATE));
        SET @IdEmpleado = SCOPE_IDENTITY();
        PRINT 'OK: Empleado creado (IdEmpleado=' + CAST(@IdEmpleado AS VARCHAR) + ').';
    END
    ELSE
        PRINT 'INFO: Empleado ya existía (IdEmpleado=' + CAST(@IdEmpleado AS VARCHAR) + ').';

    -- 3) Vincular el usuario con el empleado
    UPDATE dbo.USUARIO
       SET IdEmpleado = @IdEmpleado
     WHERE IdUsuario = @IdUsuario;
    PRINT 'OK: Usuario 24 vinculado al Empleado ' + CAST(@IdEmpleado AS VARCHAR) + '.';

    COMMIT TRANSACTION;
    PRINT '════ Script 121 completado ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO

-- Verificación: el SP de login ahora debe traer la fila con Documento
EXEC usp_ObtenerUsuarioPorCorreo @Correo = 'miguel123@gmail.com';
GO
