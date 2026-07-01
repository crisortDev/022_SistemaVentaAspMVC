-- ============================================================
--  TABLA: RegistroAuditoria
--  Registra eventos críticos del sistema: login, logout, CRUD.
--  Ejecutar una sola vez en la base de datos.
-- ============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'RegistroAuditoria'
)
BEGIN
    CREATE TABLE RegistroAuditoria (
        IdAuditoria   INT           IDENTITY(1,1) PRIMARY KEY,
        IdUsuario     INT           NULL,           -- NULL si el evento ocurre antes de identificar al usuario
        Correo        NVARCHAR(150) NULL,           -- útil cuando IdUsuario es NULL (login fallido)
        Accion        NVARCHAR(100) NOT NULL,       -- 'LOGIN_OK', 'LOGIN_FAIL', 'LOGOUT', 'CREAR_COMPRA', etc.
        Detalle       NVARCHAR(500) NULL,           -- información adicional del evento
        DireccionIP   NVARCHAR(50)  NULL,
        Fecha         DATETIME      NOT NULL DEFAULT GETDATE(),

        CONSTRAINT FK_Auditoria_Usuario
            FOREIGN KEY (IdUsuario) REFERENCES Usuario(IdUsuario)
    );

    -- Índices para consultas frecuentes
    CREATE INDEX IX_Auditoria_IdUsuario ON RegistroAuditoria(IdUsuario);
    CREATE INDEX IX_Auditoria_Fecha     ON RegistroAuditoria(Fecha DESC);
    CREATE INDEX IX_Auditoria_Accion    ON RegistroAuditoria(Accion);

    PRINT 'Tabla RegistroAuditoria creada correctamente.';
END
ELSE
BEGIN
    PRINT 'La tabla RegistroAuditoria ya existe.';
END
