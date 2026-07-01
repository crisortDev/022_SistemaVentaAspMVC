-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 44: Corregir usp_ObtenerListaOrdenVenta — agregar columna Exento0
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
--
-- El SP original no incluía Exento0 en el SELECT, pero CD_OrdenVenta.cs
-- lo lee con dr["Exento0"], lo que lanzaba una IndexOutOfRangeException
-- silenciada por el catch, devolviendo siempre lista vacía.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaOrdenVenta]
    @IdTienda    INT          = 0,
    @Estado      VARCHAR(20)  = '',
    @FechaInicio DATE         = NULL,
    @FechaFin    DATE         = NULL,
    @NumeroOV    VARCHAR(20)  = ''
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
        ov.Exento0,                                                         -- ← columna faltante
        CONVERT(VARCHAR(10), ov.FechaRegistro,   103) AS FechaRegistro,
        CONVERT(VARCHAR(10), ov.FechaVencimiento, 103) AS FechaVencimiento,
        ov.Observacion,
        t.Nombre                                 AS NombreTienda,
        u.Nombres + ' ' + u.Apellidos            AS NombreUsuario,
        ISNULL(c.Nombre,           'Sin asignar') AS NombreCliente,
        ISNULL(c.NumeroDocumento,  '')            AS DocumentoCliente,
        -- Alerta de vencimiento
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
      AND (@IdTienda = 0 OR ov.IdTienda = @IdTienda)
      AND (@Estado   = '' OR ov.Estado  = @Estado)
      AND (@NumeroOV = '' OR ov.NumeroOV LIKE '%' + @NumeroOV + '%')
      AND CAST(ov.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY ov.FechaRegistro DESC;
END
GO

PRINT 'OK: usp_ObtenerListaOrdenVenta corregido (Exento0 agregado).';
GO
