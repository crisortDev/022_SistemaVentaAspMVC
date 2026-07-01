-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 120: Fix login — usuario sin EMPLEADO/Persona no podía loguear
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03
--
-- PROBLEMA:
--   usp_ObtenerUsuarioPorCorreo usaba INNER JOIN a EMPLEADO y Persona. Si el usuario
--   no tiene empleado/persona vinculado (IdEmpleado NULL o sin fila), el SP devolvía
--   vacío → el login mostraba "Usuario o contraseña incorrecta" aunque la clave fuera
--   correcta (caso: miguel123@gmail.com, Repositor).
--
-- FIX: LEFT JOIN en EMPLEADO y Persona (ROL se mantiene INNER porque todo usuario
--   debe tener rol). Así el login funciona aunque falte el vínculo de empleado.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROC usp_ObtenerUsuarioPorCorreo
    @Correo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        u.IdUsuario,
        p.Documento                         AS Documento,
        u.Nombres,
        u.Apellidos,
        u.Correo,
        u.Clave,
        u.IdTienda,
        u.IdRol,
        u.Activo,
        u.FechaRegistro,
        u.PasswordTemporalHash,
        u.PasswordTemporalExpira,
        u.RequiereCambioPassword,
        u.FechaCambioPassword,
        r.Descripcion                       AS DescripcionRol,
        ISNULL(u.IntentosFallidos, 0)       AS IntentosFallidos,
        u.FechaUltimoLogin
    FROM USUARIO u
    LEFT  JOIN EMPLEADO e   ON u.IdEmpleado = e.IdEmpleado   -- ← LEFT (antes INNER)
    LEFT  JOIN Persona p    ON e.IdPersona  = p.IdPersona    -- ← LEFT (antes INNER)
    INNER JOIN ROL r        ON r.IdRol      = u.IdRol
    WHERE u.Correo = @Correo;
END
GO
PRINT 'OK: usp_ObtenerUsuarioPorCorreo — LEFT JOIN a EMPLEADO/Persona.';
GO

-- Verificación: ahora debe devolver la fila de Miguel
EXEC usp_ObtenerUsuarioPorCorreo @Correo = 'miguel123@gmail.com';
GO
