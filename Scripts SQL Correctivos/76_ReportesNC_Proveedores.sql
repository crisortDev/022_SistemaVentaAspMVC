-- ============================================================
--  Script 76 — Reporte de NC asociadas + Reporte de Proveedores
--  Fecha: 2026-05-21
--  Punto j) del plan de tesis
-- ============================================================
USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
--  1. SP: usp_rptNotaCredito
--     Detalle de NCs filtrado por rango de fecha, proveedor,
--     tienda y estado.
-- ════════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.usp_rptNotaCredito', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_rptNotaCredito;
GO

CREATE PROCEDURE dbo.usp_rptNotaCredito
    @FechaInicio  DATE    = NULL,
    @FechaFin     DATE    = NULL,
    @IdProveedor  INT     = 0,
    @IdTienda     INT     = 0,
    @Estado       VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        nc.IdNC,
        nc.IdCompra,
        -- Factura de compra de origen
        c.NumeroFactura,
        CONVERT(VARCHAR(10), c.FechaFactura, 103)           AS FechaFactura,
        c.MontoTotal                                         AS MontoFactura,
        -- Datos del documento NC
        ISNULL(nc.NumeroNC, '')                              AS NumeroNC,
        ISNULL(nc.NumeroTimbrado, '')                        AS NumeroTimbrado,
        CASE WHEN nc.FechaVencTimbrado IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaVencTimbrado, 103)
             ELSE '' END                                     AS FechaVencTimbrado,
        CASE WHEN nc.FechaEmision IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaEmision, 103)
             ELSE '' END                                     AS FechaEmision,
        nc.MontoNC,
        nc.Estado,
        -- Morosa = Pendiente > 30 días desde fecha factura
        DATEDIFF(DAY, c.FechaFactura, GETDATE())             AS DiasTranscurridos,
        CASE WHEN nc.Estado = 'Pendiente'
              AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
             THEN 1 ELSE 0 END                               AS EsMorosa,
        -- Motivo y observación
        ISNULL(mn.Descripcion, '')                           AS MotivoNC,
        ISNULL(nc.Observacion, '')                           AS Observacion,
        -- Auditoría
        CASE WHEN nc.FechaRegistro IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaRegistro, 103)
             ELSE '' END                                     AS FechaRegistro,
        CASE WHEN nc.FechaConfirmacion IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaConfirmacion, 103)
             ELSE '' END                                     AS FechaConfirmacion,
        ISNULL(u.Nombre, '')                                 AS UsuarioRegistro,
        -- Proveedor
        p.IdProveedor,
        p.RazonSocial                                        AS Proveedor,
        p.RUC                                                AS RucProveedor,
        -- Tienda
        t.IdTienda,
        t.Nombre                                             AS Tienda
    FROM dbo.NOTA_CREDITO nc
    JOIN dbo.COMPRA        c  ON c.IdCompra    = nc.IdCompra
    JOIN dbo.PROVEEDOR     p  ON p.IdProveedor = c.IdProveedor
    JOIN dbo.TIENDA        t  ON t.IdTienda    = c.IdTienda
    LEFT JOIN dbo.USUARIO  u  ON u.IdUsuario   = nc.IdUsuarioRegistro
    LEFT JOIN dbo.MOTIVO_NC mn ON mn.IdMotivoNC = nc.IdMotivoNC
    WHERE
        -- Rango de fechas (sobre FechaRegistro de la NC)
        (@FechaInicio IS NULL OR CAST(nc.FechaRegistro AS DATE) >= @FechaInicio)
    AND (@FechaFin   IS NULL OR CAST(nc.FechaRegistro AS DATE) <= @FechaFin)
        -- Filtros opcionales
    AND (@IdProveedor = 0 OR p.IdProveedor = @IdProveedor)
    AND (@IdTienda    = 0 OR t.IdTienda    = @IdTienda)
    AND (@Estado      = '' OR nc.Estado    = @Estado)
    ORDER BY nc.FechaRegistro DESC, nc.IdNC DESC;
END
GO

PRINT 'OK: usp_rptNotaCredito creado.';
GO

-- ════════════════════════════════════════════════════════════
--  2. SP: usp_rptProveedores
--     Resumen por proveedor: cantidad de compras, monto total,
--     total NCs, monto neto y estado de deuda.
-- ════════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.usp_rptProveedores', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_rptProveedores;
GO

CREATE PROCEDURE dbo.usp_rptProveedores
    @FechaInicio  DATE    = NULL,
    @FechaFin     DATE    = NULL,
    @IdTienda     INT     = 0,
    @SoloConDeuda BIT     = 0       -- 1 = mostrar sólo proveedores con NC pendiente
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProveedor,
        p.RazonSocial                                        AS Proveedor,
        p.RUC                                                AS RucProveedor,
        ISNULL(p.Telefono,  '')                              AS Telefono,
        ISNULL(p.Correo,    '')                              AS Correo,
        -- Compras en el período
        COUNT(DISTINCT c.IdCompra)                           AS CantidadCompras,
        ISNULL(SUM(c.MontoTotal), 0)                         AS TotalCompras,
        -- NCs asociadas
        COUNT(DISTINCT nc.IdNC)                              AS CantidadNC,
        ISNULL(SUM(nc.MontoNC), 0)                           AS TotalMontoNC,
        -- NCs pendientes (posible deuda del proveedor con nosotros)
        SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1 ELSE 0 END) AS NCPendientes,
        ISNULL(SUM(CASE WHEN nc.Estado = 'Pendiente' THEN nc.MontoNC ELSE 0 END), 0) AS MontoNCPendiente,
        -- NCs recibidas / rechazadas
        SUM(CASE WHEN nc.Estado = 'Recibida'  THEN 1 ELSE 0 END) AS NCRecibidas,
        SUM(CASE WHEN nc.Estado = 'Rechazada' THEN 1 ELSE 0 END) AS NCRechazadas,
        -- Monto neto = Total compras − NC recibidas
        ISNULL(SUM(c.MontoTotal), 0)
            - ISNULL(SUM(CASE WHEN nc.Estado = 'Recibida' THEN nc.MontoNC ELSE 0 END), 0) AS MontoNeto,
        -- Tiene alguna NC morosa (pendiente > 30 días)
        MAX(CASE WHEN nc.Estado = 'Pendiente'
                  AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
                 THEN 1 ELSE 0 END)                          AS TieneMorosa
    FROM dbo.PROVEEDOR p
    LEFT JOIN dbo.COMPRA c
           ON c.IdProveedor = p.IdProveedor
          AND (@IdTienda    = 0 OR c.IdTienda = @IdTienda)
          AND (@FechaInicio IS NULL OR CAST(c.FechaRegistro AS DATE) >= @FechaInicio)
          AND (@FechaFin    IS NULL OR CAST(c.FechaRegistro AS DATE) <= @FechaFin)
    LEFT JOIN dbo.NOTA_CREDITO nc
           ON nc.IdCompra = c.IdCompra
    WHERE p.Activo = 1
    GROUP BY p.IdProveedor, p.RazonSocial, p.RUC, p.Telefono, p.Correo
    HAVING
        -- Si sólo queremos los que tienen deuda NC pendiente
        (@SoloConDeuda = 0
         OR SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1 ELSE 0 END) > 0)
    ORDER BY ISNULL(SUM(c.MontoTotal), 0) DESC;
END
GO

PRINT 'OK: usp_rptProveedores creado.';
GO

-- ════════════════════════════════════════════════════════════
--  3. Menú: agregar submenús bajo "Reporte"
-- ════════════════════════════════════════════════════════════
DECLARE @IdMenuRpt INT;
SELECT TOP 1 @IdMenuRpt = IdMenu FROM dbo.MENU WHERE Nombre = 'Reporte';

IF @IdMenuRpt IS NULL
BEGIN
    PRINT 'ERROR: No existe el menú "Reporte". Verificá la tabla MENU.';
    RETURN;
END

PRINT 'IdMenu Reporte: ' + CAST(@IdMenuRpt AS VARCHAR);
GO

-- 3a. Submenú: Reporte NC
DECLARE @IdMenuRpt INT;
DECLARE @IdSmNC    INT;
SELECT TOP 1 @IdMenuRpt = IdMenu FROM dbo.MENU WHERE Nombre = 'Reporte';

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE Controlador = 'Reporte' AND Vista = 'NotaCredito'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuRpt, 'Reporte NC', 'Reporte', 'NotaCredito', 'fas fa-file-invoice-dollar', 30, 1);
    SET @IdSmNC = SCOPE_IDENTITY();
    PRINT 'OK: Submenú "Reporte NC" creado (IdSubMenu = ' + CAST(@IdSmNC AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSmNC = IdSubMenu FROM dbo.SUBMENU WHERE Controlador = 'Reporte' AND Vista = 'NotaCredito';
    PRINT 'INFO: Submenú "Reporte NC" ya existía (IdSubMenu = ' + CAST(@IdSmNC AS VARCHAR) + ').';
END

-- Permisos: ADMINISTRADOR(1), Encargado(6), SUPERVISOR(11), SUPERADMIN(14)
DECLARE @rolesNC TABLE (IdRol INT);
INSERT INTO @rolesNC VALUES (1),(6),(11),(14);

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSmNC, 1, GETDATE()
FROM   @rolesNC r
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmNC
);
PRINT 'OK: Permisos Reporte NC asignados.';
GO

-- 3b. Submenú: Reporte Proveedores
DECLARE @IdMenuRpt INT;
DECLARE @IdSmProv  INT;
SELECT TOP 1 @IdMenuRpt = IdMenu FROM dbo.MENU WHERE Nombre = 'Reporte';

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE Controlador = 'Reporte' AND Vista = 'Proveedores'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuRpt, 'Reporte Proveedores', 'Reporte', 'Proveedores', 'fas fa-truck', 31, 1);
    SET @IdSmProv = SCOPE_IDENTITY();
    PRINT 'OK: Submenú "Reporte Proveedores" creado (IdSubMenu = ' + CAST(@IdSmProv AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSmProv = IdSubMenu FROM dbo.SUBMENU WHERE Controlador = 'Reporte' AND Vista = 'Proveedores';
    PRINT 'INFO: Submenú "Reporte Proveedores" ya existía (IdSubMenu = ' + CAST(@IdSmProv AS VARCHAR) + ').';
END

DECLARE @rolesProv TABLE (IdRol INT);
INSERT INTO @rolesProv VALUES (1),(6),(11),(14);

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSmProv, 1, GETDATE()
FROM   @rolesProv r
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmProv
);
PRINT 'OK: Permisos Reporte Proveedores asignados.';
GO

-- ════════════════════════════════════════════════════════════
--  4. Verificación
-- ════════════════════════════════════════════════════════════
SELECT s.IdSubMenu, s.Nombre, s.Controlador, s.Vista, s.Icono, s.Orden
FROM   dbo.SUBMENU s
JOIN   dbo.MENU m ON m.IdMenu = s.IdMenu
WHERE  m.Nombre = 'Reporte'
ORDER  BY s.Orden;
GO

SELECT r.Descripcion AS Rol, s.Nombre AS Submenu
FROM   dbo.PERMISOS p
JOIN   dbo.ROL     r ON r.IdRol    = p.IdRol
JOIN   dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
WHERE  s.Controlador = 'Reporte'
  AND  s.Vista IN ('NotaCredito', 'Proveedores')
ORDER  BY s.Vista, r.Descripcion;
GO

PRINT '════ Script 76 completado ════';
GO
