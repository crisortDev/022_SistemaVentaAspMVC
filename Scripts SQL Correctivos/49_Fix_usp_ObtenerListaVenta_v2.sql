-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 49: Corregir usp_ObtenerListaVenta_v2
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
--
-- Dos problemas:
--   1. El parámetro se llamaba @NumeroDocumento pero CD_Venta.cs envía
--      @DocumentoCliente → SqlException silenciada → lista vacía.
--   2. INNER JOIN CLIENTE ocultaba ventas sin cliente asignado.
--      Cambiado a LEFT JOIN con ISNULL.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaVenta_v2]
    @IdTienda         INT          = 0,
    @FechaInicio      DATE         = NULL,
    @FechaFin         DATE         = NULL,
    @NumeroFactura    VARCHAR(30)  = '',
    @DocumentoCliente VARCHAR(50)  = '',   -- ← renombrado desde @NumeroDocumento
    @NombreCliente    VARCHAR(100) = '',
    @TipoFlujo        VARCHAR(20)  = '',
    @Estado           VARCHAR(20)  = ''
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    IF @FechaFin    IS NULL SET @FechaFin    = CAST(GETDATE() AS DATE);

    SELECT
        v.IdVenta,
        v.Codigo,
        v.NumeroFactura,
        v.NumeroTimbrado,
        v.TipoFlujo,
        v.Estado,
        CONVERT(VARCHAR(10), v.FechaRegistro, 103)        AS FechaRegistro,
        v.TotalCosto,
        v.IVA10,
        v.IVA5,
        ISNULL(c.Nombre,          'Consumidor Final')     AS NombreCliente,
        ISNULL(c.NumeroDocumento, '')                     AS DocumentoCliente,
        u.Nombres + ' ' + u.Apellidos                     AS NombreUsuario,
        t.Nombre                                          AS NombreTienda,
        ISNULL(ov.NumeroOV, '')                           AS NumeroOV,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, ''))     AS FormaCobro
    FROM dbo.VENTA v
    LEFT  JOIN dbo.CLIENTE     c  ON c.IdCliente     = v.IdCliente   -- LEFT para ventas sin cliente
    INNER JOIN dbo.USUARIO     u  ON u.IdUsuario     = v.IdUsuario
    INNER JOIN dbo.TIENDA      t  ON t.IdTienda      = v.IdTienda
    LEFT  JOIN dbo.ORDEN_VENTA ov ON ov.IdOrdenVenta = v.IdOrdenVenta
    LEFT  JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    WHERE v.Activo = 1
      AND (@IdTienda       = 0   OR v.IdTienda       = @IdTienda)
      AND CAST(v.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (@NumeroFactura   = '' OR v.NumeroFactura   LIKE '%' + @NumeroFactura + '%')
      AND (@DocumentoCliente= '' OR c.NumeroDocumento LIKE '%' + @DocumentoCliente + '%')
      AND (@NombreCliente   = '' OR c.Nombre          LIKE '%' + @NombreCliente + '%')
      AND (@TipoFlujo       = '' OR v.TipoFlujo       = @TipoFlujo)
      AND (@Estado          = '' OR v.Estado          = @Estado)
    ORDER BY v.FechaRegistro DESC;
END
GO

PRINT 'OK: usp_ObtenerListaVenta_v2 corregido (@DocumentoCliente, LEFT JOIN cliente).';
GO
