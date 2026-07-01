-- ============================================================
--  Script 76c — Recrear usp_rptNotaCredito
-- ============================================================
USE [DBVENTAS_WEB]
GO

IF OBJECT_ID('dbo.usp_rptNotaCredito', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_rptNotaCredito;
GO

CREATE PROCEDURE dbo.usp_rptNotaCredito
    @FechaInicio  DATE        = NULL,
    @FechaFin     DATE        = NULL,
    @IdProveedor  INT         = 0,
    @IdTienda     INT         = 0,
    @Estado       VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        nc.IdNC,
        nc.IdCompra,
        c.NumeroFactura,
        CONVERT(VARCHAR(10), c.FechaFactura, 103)                               AS FechaFactura,
        c.TotalCosto                                                             AS MontoFactura,
        ISNULL(nc.NumeroNC,       '')                                            AS NumeroNC,
        ISNULL(nc.NumeroTimbrado, '')                                            AS NumeroTimbrado,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaVencTimbrado, 103), '')              AS FechaVencTimbrado,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaEmision,      103), '')              AS FechaEmision,
        nc.Monto                                                                 AS MontoNC,
        nc.Estado,
        DATEDIFF(DAY, c.FechaFactura, GETDATE())                                 AS DiasTranscurridos,
        CASE
            WHEN nc.Estado = 'Pendiente'
             AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
            THEN 1 ELSE 0
        END                                                                      AS EsMorosa,
        ISNULL(mnc.Descripcion, '')                                              AS MotivoNC,
        ISNULL(nc.Observacion,  '')                                              AS Observacion,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaRegistro,    103), '')               AS FechaRegistro,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaConfirmacion,103), '')               AS FechaConfirmacion,
        ISNULL(u.Nombres + ' ' + u.Apellidos, '')                                AS UsuarioRegistro,
        p.IdProveedor,
        p.RazonSocial                                                            AS Proveedor,
        p.RUC                                                                    AS RucProveedor,
        t.IdTienda,
        t.Nombre                                                                 AS Tienda
    FROM      dbo.NOTA_CREDITO          nc
    JOIN      dbo.COMPRA                 c   ON c.IdCompra            = nc.IdCompra
    JOIN      dbo.PROVEEDOR              p   ON p.IdProveedor          = c.IdProveedor
    JOIN      dbo.TIENDA                 t   ON t.IdTienda             = c.IdTienda
    LEFT JOIN dbo.USUARIO               u   ON u.IdUsuario            = nc.IdUsuarioRegistro
    LEFT JOIN dbo.MOTIVO_NOTA_CREDITO   mnc ON mnc.IdMotivoNotaCredito = nc.IdMotivoNC
    WHERE
        (@FechaInicio IS NULL OR CAST(nc.FechaRegistro AS DATE) >= @FechaInicio)
    AND (@FechaFin    IS NULL OR CAST(nc.FechaRegistro AS DATE) <= @FechaFin)
    AND (@IdProveedor = 0    OR p.IdProveedor = @IdProveedor)
    AND (@IdTienda    = 0    OR t.IdTienda    = @IdTienda)
    AND (@Estado      = ''   OR nc.Estado     = @Estado)
    ORDER BY nc.FechaRegistro DESC, nc.IdNC DESC;
END
GO

PRINT 'OK: usp_rptNotaCredito creado.';

-- Prueba
EXEC dbo.usp_rptNotaCredito;
GO
