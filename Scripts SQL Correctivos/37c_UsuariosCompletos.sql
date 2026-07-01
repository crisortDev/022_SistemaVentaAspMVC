-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 37c: Usuarios completos para demo de segregación de funciones
-- ─────────────────────────────────────────────────────────────────────────────
-- Usuarios EXISTENTES reasignados (por scripts 37 y 37b):
--   Cristian (1)  SUPERADMIN     global          acceso total
--   Lilian   (17) Encargado      Tienda 1        aprueba OC / confirma compras
--   Juan     (4)  CAJERO         Tienda 1        carga OC / recepción
--   Pepe     (5)  CAJERO         Tienda 1        carga OC / recepción
--   Jorge    (3)  ADMINISTRADOR  Tienda 2        acceso amplio Tienda 2
--   Federico (16) REPOSITOR      Tienda 2        solo carga/vista
--
-- Usuarios NUEVOS que crea este script:
--   Carlos Méndez  ADMINISTRADOR  Tienda 1
--   Sandra Torres  SUPERVISOR     Tienda 1
--   Diego Rojas    Encargado      Tienda 2  ← aprobador Tienda 2
--   Ana Martínez   SUPERVISOR     Tienda 2
--   Rosa Benítez   CAJERO         Tienda 2  ← cargadora Tienda 2
--
-- Contraseña de todos: 123456
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

DECLARE @pwd VARCHAR(64) = '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92'
DECLARE @hoy DATETIME     = GETDATE()

DECLARE @idPersona  INT
DECLARE @idEmpleado INT

-- ══════════════════════════════════════════════════════════════════════════════
-- TIENDA 1 — Compu Space Central
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1. Carlos Méndez — ADMINISTRADOR Tienda 1 ────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE Documento = '3456789')
BEGIN
    INSERT INTO dbo.Persona (Nombres, Apellidos, TipoDocumento, Documento, Correo, FechaRegistro, Activo)
    VALUES ('Carlos', 'Méndez', 'CI', '3456789', 'carlos.mendez@compuspace.com.py', @hoy, 1)
    SET @idPersona = SCOPE_IDENTITY()

    INSERT INTO dbo.Empleado (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso)
    VALUES (@idPersona, 'Carlos', 'Méndez', 1, 1, @hoy, @hoy)
    SET @idEmpleado = SCOPE_IDENTITY()

    INSERT INTO dbo.USUARIO (Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, Activo,
                              FechaRegistro, IdEmpleado, EstadoUsuario, RequiereCambioPassword, IntentosFallidos)
    VALUES ('Carlos', 'Méndez', 'carlos.mendez@compuspace.com.py', @pwd,
            1, 1, 1, @hoy, @idEmpleado, 0, 0, 0)
    PRINT 'OK: Carlos Méndez → ADMINISTRADOR Tienda 1'
END
ELSE PRINT 'INFO: Carlos Méndez ya existe.'

-- ── 2. Sandra Torres — SUPERVISOR Tienda 1 ───────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE Documento = '4567890')
BEGIN
    INSERT INTO dbo.Persona (Nombres, Apellidos, TipoDocumento, Documento, Correo, FechaRegistro, Activo)
    VALUES ('Sandra', 'Torres', 'CI', '4567890', 'sandra.torres@compuspace.com.py', @hoy, 1)
    SET @idPersona = SCOPE_IDENTITY()

    INSERT INTO dbo.Empleado (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso)
    VALUES (@idPersona, 'Sandra', 'Torres', 1, 1, @hoy, @hoy)
    SET @idEmpleado = SCOPE_IDENTITY()

    INSERT INTO dbo.USUARIO (Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, Activo,
                              FechaRegistro, IdEmpleado, EstadoUsuario, RequiereCambioPassword, IntentosFallidos)
    VALUES ('Sandra', 'Torres', 'sandra.torres@compuspace.com.py', @pwd,
            1, 11, 1, @hoy, @idEmpleado, 0, 0, 0)
    PRINT 'OK: Sandra Torres → SUPERVISOR Tienda 1'
END
ELSE PRINT 'INFO: Sandra Torres ya existe.'

-- ══════════════════════════════════════════════════════════════════════════════
-- TIENDA 2 — Compu Space Sucursal
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 3. Diego Rojas — Encargado Tienda 2 (APROBADOR) ──────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE Documento = '5678901')
BEGIN
    INSERT INTO dbo.Persona (Nombres, Apellidos, TipoDocumento, Documento, Correo, FechaRegistro, Activo)
    VALUES ('Diego', 'Rojas', 'CI', '5678901', 'diego.rojas@compuspace.com.py', @hoy, 1)
    SET @idPersona = SCOPE_IDENTITY()

    INSERT INTO dbo.Empleado (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso)
    VALUES (@idPersona, 'Diego', 'Rojas', 2, 1, @hoy, @hoy)
    SET @idEmpleado = SCOPE_IDENTITY()

    INSERT INTO dbo.USUARIO (Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, Activo,
                              FechaRegistro, IdEmpleado, EstadoUsuario, RequiereCambioPassword, IntentosFallidos)
    VALUES ('Diego', 'Rojas', 'diego.rojas@compuspace.com.py', @pwd,
            2, 6, 1, @hoy, @idEmpleado, 0, 0, 0)
    PRINT 'OK: Diego Rojas → Encargado Tienda 2 (aprobador)'
END
ELSE PRINT 'INFO: Diego Rojas ya existe.'

-- ── 4. Ana Martínez — SUPERVISOR Tienda 2 ────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE Documento = '6789012')
BEGIN
    INSERT INTO dbo.Persona (Nombres, Apellidos, TipoDocumento, Documento, Correo, FechaRegistro, Activo)
    VALUES ('Ana', 'Martínez', 'CI', '6789012', 'ana.martinez@compuspace.com.py', @hoy, 1)
    SET @idPersona = SCOPE_IDENTITY()

    INSERT INTO dbo.Empleado (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso)
    VALUES (@idPersona, 'Ana', 'Martínez', 2, 1, @hoy, @hoy)
    SET @idEmpleado = SCOPE_IDENTITY()

    INSERT INTO dbo.USUARIO (Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, Activo,
                              FechaRegistro, IdEmpleado, EstadoUsuario, RequiereCambioPassword, IntentosFallidos)
    VALUES ('Ana', 'Martínez', 'ana.martinez@compuspace.com.py', @pwd,
            2, 11, 1, @hoy, @idEmpleado, 0, 0, 0)
    PRINT 'OK: Ana Martínez → SUPERVISOR Tienda 2'
END
ELSE PRINT 'INFO: Ana Martínez ya existe.'

-- ── 5. Rosa Benítez — CAJERO Tienda 2 ────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE Documento = '7890123')
BEGIN
    INSERT INTO dbo.Persona (Nombres, Apellidos, TipoDocumento, Documento, Correo, FechaRegistro, Activo)
    VALUES ('Rosa', 'Benítez', 'CI', '7890123', 'rosa.benitez@compuspace.com.py', @hoy, 1)
    SET @idPersona = SCOPE_IDENTITY()

    INSERT INTO dbo.Empleado (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso)
    VALUES (@idPersona, 'Rosa', 'Benítez', 2, 1, @hoy, @hoy)
    SET @idEmpleado = SCOPE_IDENTITY()

    INSERT INTO dbo.USUARIO (Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, Activo,
                              FechaRegistro, IdEmpleado, EstadoUsuario, RequiereCambioPassword, IntentosFallidos)
    VALUES ('Rosa', 'Benítez', 'rosa.benitez@compuspace.com.py', @pwd,
            2, 4, 1, @hoy, @idEmpleado, 0, 0, 0)
    PRINT 'OK: Rosa Benítez → CAJERO Tienda 2 (cargadora)'
END
ELSE PRINT 'INFO: Rosa Benítez ya existe.'
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- RESUMEN FINAL COMPLETO
-- ══════════════════════════════════════════════════════════════════════════════
PRINT ''
PRINT '════════════════════════════════════════════════════════════'
PRINT 'USUARIOS COMPLETOS — contraseña: 123456 para todos'
PRINT '════════════════════════════════════════════════════════════'
PRINT ''
PRINT '🌐 GLOBAL'
PRINT '  admin@gmail.com                  Cristian    SUPERADMIN'
PRINT ''
PRINT '🏪 TIENDA 1 — Compu Space Central'
PRINT '  carlos.mendez@compuspace.com.py  Carlos      ADMINISTRADOR'
PRINT '  sandra.torres@compuspace.com.py  Sandra      SUPERVISOR'
PRINT '  cristian.a.ortega@hotmail.com    Lilian      Encargado     [APRUEBA]'
PRINT '  juan.perez@gmail.com             Juan        CAJERO        [CARGA]'
PRINT '  tiantega@gmail.com               Pepe        CAJERO        [CARGA]'
PRINT ''
PRINT '🏪 TIENDA 2 — Compu Space Sucursal'
PRINT '  jorge@correo.com                 Jorge       ADMINISTRADOR'
PRINT '  ana.martinez@compuspace.com.py   Ana         SUPERVISOR'
PRINT '  diego.rojas@compuspace.com.py    Diego       Encargado     [APRUEBA]'
PRINT '  rosa.benitez@compuspace.com.py   Rosa        CAJERO        [CARGA]'
PRINT '  crisarielorte@fpuna.edu.py       Federico    REPOSITOR     [VISTA]'
PRINT ''
PRINT '════════════════════════════════════════════════════════════'
PRINT 'Script 37c completado.'
GO
