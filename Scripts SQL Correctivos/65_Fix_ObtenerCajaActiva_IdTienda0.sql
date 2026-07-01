-- ============================================================
-- Script 65: Fix usp_ObtenerCajaActiva — soporte @IdTienda = 0
-- Fecha: 2026-05-19
--
-- Cuando @IdTienda = 0 (SuperAdmin sin tienda fija) devuelve
-- la primera caja abierta que exista en cualquier tienda.
-- ============================================================

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        c.IdCaja,
        c.IdTienda,
        t.Nombre                              AS NombreTienda,
        c.IdUsuario,
        u.Nombres + ' ' + u.Apellidos         AS NombreUsuario,
        c.FechaApertura,
        c.MontoApertura,
        c.Estado,
        ISNULL(SUM(v.TotalCosto), 0)          AS TotalVentas,
        COUNT(v.IdVenta)                      AS CantidadVentas
    FROM  dbo.CAJA    c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    LEFT  JOIN dbo.VENTA   v ON v.IdTienda  = c.IdTienda
                             AND v.FechaRegistro >= c.FechaApertura
                             AND v.Estado = 'Activa'
    WHERE c.Estado = 'Abierta'
      AND (@IdTienda = 0 OR c.IdTienda = @IdTienda)
    GROUP BY c.IdCaja, c.IdTienda, t.Nombre, c.IdUsuario,
             u.Nombres, u.Apellidos, c.FechaApertura, c.MontoApertura, c.Estado
    ORDER BY c.FechaApertura DESC;
END
GO
PRINT 'OK: usp_ObtenerCajaActiva actualizado (soporta @IdTienda = 0).';
GO

PRINT '════ Script 65 completado ════';
GO
