-- ════════════════════════════════════════════════════════════════════════════════
-- FIX 38b: Corregir usp_ObtenerListaNotaCreditoVenta
-- El JOIN usaba m.IdMotivoNC pero la PK de MOTIVO_NOTA_CREDITO es IdMotivoNotaCredito
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaNotaCreditoVenta]
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = '',
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY,-30,CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        nc.IdNCVenta, nc.NumeroNCV, nc.Estado, nc.Monto, nc.Observacion,
        CONVERT(VARCHAR(10), nc.FechaRegistro, 103) AS FechaRegistro,
        ISNULL(CONVERT(VARCHAR(10), nc.FechaAprobacion, 103),'') AS FechaAprobacion,
        v.NumeroFactura, v.Codigo AS CodigoVenta,
        c.Nombre AS NombreCliente, c.NumeroDocumento,
        m.Descripcion AS MotivoNC,
        u.Nombres+' '+u.Apellidos AS NombreRegistro,
        t.Nombre AS NombreTienda,
        ISNULL(nc.MotivoRechazo,'') AS MotivoRechazo
    FROM dbo.NOTA_CREDITO_VENTA nc
    INNER JOIN dbo.VENTA   v ON v.IdVenta    = nc.IdVenta
    INNER JOIN dbo.CLIENTE c ON c.IdCliente  = v.IdCliente
    INNER JOIN dbo.TIENDA  t ON t.IdTienda   = v.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario  = nc.IdUsuarioRegistro
    INNER JOIN dbo.MOTIVO_NOTA_CREDITO m ON m.IdMotivoNotaCredito = nc.IdMotivoNC
    WHERE nc.Activo = 1
      AND (@IdTienda = 0 OR v.IdTienda = @IdTienda)
      AND (@Estado = '' OR nc.Estado = @Estado)
      AND CAST(nc.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY nc.FechaRegistro DESC;
END
GO

PRINT 'OK: usp_ObtenerListaNotaCreditoVenta (fix JOIN IdMotivoNotaCredito)';
GO
