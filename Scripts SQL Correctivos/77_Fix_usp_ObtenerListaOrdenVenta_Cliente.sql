-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 77: Agregar filtro @Cliente a usp_ObtenerListaOrdenVenta
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- Permite buscar pre-ventas por nombre de cliente o número de documento.
-- Punto n) de tutoria: validar orden de venta por nombre de cliente o nro documento.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaOrdenVenta]
    @IdTienda    INT          = 0,
    @Estado      VARCHAR(20)  = '',
    @FechaInicio DATE         = NULL,
    @FechaFin    DATE         = NULL,
    @NumeroOV    VARCHAR(20)  = '',
    @Cliente     VARCHAR(100) = ''   -- NUEVO: filtrar por nombre o Nº documento
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        ov.IdOrdenVenta,
        ov.NumeroOV,
        ov.Estado,
        ov.TotalEstimado,
        ov.IVA10,
        ov.IVA5,
        ov.Exento0,
        CONVERT(VARCHAR(10), ov.FechaRegistro,   103) AS FechaRegistro,
        CONVERT(VARCHAR(10), ov.FechaVencimiento, 103) AS FechaVencimiento,
        ov.Observacion,
        t.Nombre                                  AS NombreTienda,
        u.Nombres + ' ' + u.Apellidos             AS NombreUsuario,
        ISNULL(c.Nombre,          'Sin asignar')  AS NombreCliente,
        ISNULL(c.NumeroDocumento, '')             AS DocumentoCliente,
        CASE
            WHEN ov.Estado = 'Pendiente' AND ov.FechaVencimiento < CAST(GETDATE() AS DATE) THEN 'VENCIDA'
            WHEN ov.Estado = 'Pendiente' AND ov.FechaVencimiento = CAST(GETDATE() AS DATE) THEN 'VENCE HOY'
            ELSE ''
        END AS AlertaVencimiento
    FROM dbo.ORDEN_VENTA ov
    INNER JOIN dbo.TIENDA   t ON t.IdTienda  = ov.IdTienda
    INNER JOIN dbo.USUARIO  u ON u.IdUsuario = ov.IdUsuarioRegistro
    LEFT  JOIN dbo.CLIENTE  c ON c.IdCliente = ov.IdCliente
    WHERE ov.Activo = 1
      AND (@IdTienda  = 0  OR ov.IdTienda = @IdTienda)
      AND (@Estado    = '' OR ov.Estado   = @Estado)
      AND (@NumeroOV  = '' OR ov.NumeroOV LIKE '%' + @NumeroOV + '%')
      AND (@Cliente   = '' OR c.Nombre          LIKE '%' + @Cliente + '%'
                           OR c.NumeroDocumento LIKE '%' + @Cliente + '%')
      AND CAST(ov.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY ov.FechaRegistro ASC;   -- ASC: orden de carga (más antigua primero, punto o)
END
GO

PRINT 'OK: usp_ObtenerListaOrdenVenta actualizado (filtro @Cliente + ORDER ASC).';
GO
