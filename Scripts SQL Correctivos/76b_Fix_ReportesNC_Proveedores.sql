-- ============================================================
--  Script 76b — Fix: columnas MontoTotal→TotalCosto, MontoNC→Monto
--               y reparar IdMenu de los submenús 47 y 48
--  Motivo: usp_rptProveedores y usp_rptNotaCredito usaban nombres
--          de columna incorrectos. El menú "Reporte" no existía
--          con ese nombre exacto, por lo que los submenús quedaron
--          con IdMenu = NULL.
-- ============================================================
USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════
--  1. Recrear usp_rptNotaCredito (columnas correctas)
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
        -- Factura origen
        c.NumeroFactura,
        CONVERT(VARCHAR(10), c.FechaFactura,  103)           AS FechaFactura,
        c.TotalCosto                                         AS MontoFactura,   -- ← TotalCosto
        -- Documento NC
        ISNULL(nc.NumeroNC,         '')                      AS NumeroNC,
        ISNULL(nc.NumeroTimbrado,   '')                      AS NumeroTimbrado,
        CASE WHEN nc.FechaVencTimbrado IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaVencTimbrado, 103) ELSE '' END  AS FechaVencTimbrado,
        CASE WHEN nc.FechaEmision IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaEmision, 103) ELSE '' END       AS FechaEmision,
        nc.Monto                                             AS MontoNC,        -- ← Monto
        nc.Estado,
        DATEDIFF(DAY, c.FechaFactura, GETDATE())             AS DiasTranscurridos,
        CASE WHEN nc.Estado = 'Pendiente'
              AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
             THEN 1 ELSE 0 END                               AS EsMorosa,
        -- Motivo y observación
        ISNULL(mnc.Descripcion, '')                          AS MotivoNC,
        ISNULL(nc.Observacion,  '')                          AS Observacion,
        -- Auditoría
        CASE WHEN nc.FechaRegistro IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaRegistro, 103) ELSE '' END      AS FechaRegistro,
        CASE WHEN nc.FechaConfirmacion IS NOT NULL
             THEN CONVERT(VARCHAR(10), nc.FechaConfirmacion, 103) ELSE '' END  AS FechaConfirmacion,
        ISNULL(u.Nombre, '')                                 AS UsuarioRegistro,
        -- Proveedor
        p.IdProveedor,
        p.RazonSocial                                        AS Proveedor,
        p.RUC                                                AS RucProveedor,
        -- Tienda
        t.IdTienda,
        t.Nombre                                             AS Tienda
    FROM dbo.NOTA_CREDITO nc
    JOIN dbo.COMPRA                  c   ON c.IdCompra          = nc.IdCompra
    JOIN dbo.PROVEEDOR               p   ON p.IdProveedor        = c.IdProveedor
    JOIN dbo.TIENDA                  t   ON t.IdTienda           = c.IdTienda
    LEFT JOIN dbo.USUARIO            u   ON u.IdUsuario          = nc.IdUsuarioRegistro
    LEFT JOIN dbo.MOTIVO_NOTA_CREDITO mnc ON mnc.IdMotivoNotaCredito = nc.IdMotivoNC  -- ← tabla correcta
    WHERE
        (@FechaInicio IS NULL OR CAST(nc.FechaRegistro AS DATE) >= @FechaInicio)
    AND (@FechaFin   IS NULL OR CAST(nc.FechaRegistro AS DATE) <= @FechaFin)
    AND (@IdProveedor = 0 OR p.IdProveedor = @IdProveedor)
    AND (@IdTienda    = 0 OR t.IdTienda    = @IdTienda)
    AND (@Estado      = '' OR nc.Estado    = @Estado)
    ORDER BY nc.FechaRegistro DESC, nc.IdNC DESC;
END
GO

PRINT 'OK: usp_rptNotaCredito recreado con columnas correctas.';
GO

-- ════════════════════════════════════════════════════════════
--  2. Recrear usp_rptProveedores (columnas correctas)
-- ════════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.usp_rptProveedores', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_rptProveedores;
GO

CREATE PROCEDURE dbo.usp_rptProveedores
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL,
    @IdTienda     INT  = 0,
    @SoloConDeuda BIT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdProveedor,
        p.RazonSocial                                        AS Proveedor,
        p.RUC                                                AS RucProveedor,
        ISNULL(p.Telefono, '')                               AS Telefono,
        ISNULL(p.Correo,   '')                               AS Correo,
        -- Compras en el período
        COUNT(DISTINCT c.IdCompra)                           AS CantidadCompras,
        ISNULL(SUM(c.TotalCosto), 0)                         AS TotalCompras,   -- ← TotalCosto
        -- NCs
        COUNT(DISTINCT nc.IdNC)                              AS CantidadNC,
        ISNULL(SUM(nc.Monto), 0)                             AS TotalMontoNC,   -- ← Monto
        -- NC Pendientes
        SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1    ELSE 0  END) AS NCPendientes,
        ISNULL(SUM(CASE WHEN nc.Estado = 'Pendiente' THEN nc.Monto ELSE 0 END), 0) AS MontoNCPendiente,
        -- NC Recibidas / Rechazadas
        SUM(CASE WHEN nc.Estado = 'Recibida'  THEN 1 ELSE 0 END)     AS NCRecibidas,
        SUM(CASE WHEN nc.Estado = 'Rechazada' THEN 1 ELSE 0 END)     AS NCRechazadas,
        -- Monto neto
        ISNULL(SUM(c.TotalCosto), 0)
            - ISNULL(SUM(CASE WHEN nc.Estado = 'Recibida' THEN nc.Monto ELSE 0 END), 0) AS MontoNeto,
        -- Mora
        MAX(CASE WHEN nc.Estado = 'Pendiente'
                  AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
                 THEN 1 ELSE 0 END)                          AS TieneMorosa
    FROM dbo.PROVEEDOR p
    LEFT JOIN dbo.COMPRA c
           ON c.IdProveedor = p.IdProveedor
          AND (@IdTienda    = 0  OR c.IdTienda = @IdTienda)
          AND (@FechaInicio IS NULL OR CAST(c.FechaRegistro AS DATE) >= @FechaInicio)
          AND (@FechaFin    IS NULL OR CAST(c.FechaRegistro AS DATE) <= @FechaFin)
    LEFT JOIN dbo.NOTA_CREDITO nc ON nc.IdCompra = c.IdCompra
    WHERE p.Activo = 1
    GROUP BY p.IdProveedor, p.RazonSocial, p.RUC, p.Telefono, p.Correo
    HAVING
        @SoloConDeuda = 0
        OR SUM(CASE WHEN nc.Estado = 'Pendiente' THEN 1 ELSE 0 END) > 0
    ORDER BY ISNULL(SUM(c.TotalCosto), 0) DESC;
END
GO

PRINT 'OK: usp_rptProveedores recreado con columnas correctas.';
GO

-- ════════════════════════════════════════════════════════════
--  3. Reparar IdMenu de los submenús 47 y 48
--     (quedaron con IdMenu = NULL porque el menú "Reporte" no
--      existía con ese nombre exacto)
-- ════════════════════════════════════════════════════════════
DECLARE @IdMenuRpt INT;

-- Buscar por nombre exacto o parcial
SELECT TOP 1 @IdMenuRpt = IdMenu
FROM dbo.MENU
WHERE Nombre LIKE '%Reporte%' OR Nombre LIKE '%reporte%'
ORDER BY IdMenu;

IF @IdMenuRpt IS NULL
BEGIN
    -- Si no hay menú de Reportes, crearlo
    INSERT INTO dbo.MENU (Nombre, Icono, Activo)
    VALUES ('Reporte', 'fas fa-chart-bar', 1);
    SET @IdMenuRpt = SCOPE_IDENTITY();
    PRINT 'OK: Menú "Reporte" creado (IdMenu = ' + CAST(@IdMenuRpt AS VARCHAR) + ').';
END
ELSE
    PRINT 'INFO: Menú Reporte encontrado (IdMenu = ' + CAST(@IdMenuRpt AS VARCHAR) + ').';

-- Actualizar los submenús que quedaron sin IdMenu
UPDATE dbo.SUBMENU
SET    IdMenu = @IdMenuRpt
WHERE  IdSubMenu IN (47, 48)
  AND  (IdMenu IS NULL OR IdMenu <> @IdMenuRpt);

PRINT 'OK: Submenús 47 y 48 vinculados al menú Reporte. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- ════════════════════════════════════════════════════════════
--  4. Verificación final
-- ════════════════════════════════════════════════════════════
SELECT s.IdSubMenu, m.Nombre AS Menu, s.Nombre AS Submenu,
       s.Controlador, s.Vista, s.Icono, s.Activo
FROM   dbo.SUBMENU s
JOIN   dbo.MENU    m ON m.IdMenu = s.IdMenu
WHERE  s.IdSubMenu IN (47, 48);
GO

SELECT r.Descripcion AS Rol, s.Nombre AS Submenu
FROM   dbo.PERMISOS p
JOIN   dbo.ROL      r ON r.IdRol     = p.IdRol
JOIN   dbo.SUBMENU  s ON s.IdSubMenu = p.IdSubMenu
WHERE  s.IdSubMenu IN (47, 48)
ORDER  BY s.Nombre, r.Descripcion;
GO

-- Prueba rápida de los SPs
EXEC dbo.usp_rptNotaCredito  @FechaInicio = NULL, @FechaFin = NULL;
EXEC dbo.usp_rptProveedores  @FechaInicio = NULL, @FechaFin = NULL;
GO

PRINT '════ Script 76b completado ════';
GO
