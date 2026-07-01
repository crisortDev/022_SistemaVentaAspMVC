-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 117: Fix usp_ObtenerCajaActiva — restaura TODAS las columnas + filtro usuario
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03  ·  CORRIGE el script 116.
--
-- PROBLEMA: el 116 dejó el SP devolviendo solo TotalVentas/CantidadVentas, pero la
--   capa C# (CD_CajaVenta.ObtenerCajaActiva) lee también TotalVentasContado,
--   CantVentasContado, TotalVentasCredito, CantVentasCredito, TotalCobrosCXC,
--   CantCobrosCXC. Al faltar esas columnas, el mapeo lanzaba excepción → catch → null
--   → la pantalla de caja no veía la caja abierta (sin botón cerrar, sin operaciones).
--
-- FIX: versión completa del script 82 + parámetro @IdUsuario para que cada cajero
--   vea solo su caja (0 = sin filtro de usuario).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda  INT,
    @IdUsuario INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IdCaja,
        c.IdTienda,
        t.Nombre                      AS NombreTienda,
        c.IdUsuario,
        u.Nombres + ' ' + u.Apellidos AS NombreUsuario,
        c.FechaApertura,
        c.MontoApertura,
        c.Estado,
        ISNULL(vt.CantidadVentas, 0)  AS CantidadVentas,
        ISNULL(vt.TotalVentas,    0)  AS TotalVentas,
        ISNULL(vt.TotalContado,   0)  AS TotalVentasContado,
        ISNULL(vt.CantContado,    0)  AS CantVentasContado,
        ISNULL(vt.TotalCredito,   0)  AS TotalVentasCredito,
        ISNULL(vt.CantCredito,    0)  AS CantVentasCredito,
        ISNULL(cx.TotalCobrosCXC, 0)  AS TotalCobrosCXC,
        ISNULL(cx.CantCobrosCXC,  0)  AS CantCobrosCXC
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    OUTER APPLY (
        SELECT
            COUNT(v.IdVenta)                                        AS CantidadVentas,
            ISNULL(SUM(v.TotalCosto), 0)                            AS TotalVentas,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN v.TotalCosto ELSE 0 END), 0) AS TotalContado,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN 1 END)                          AS CantContado,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN v.TotalCosto ELSE 0 END), 0) AS TotalCredito,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN 1 END)                          AS CantCredito
        FROM dbo.VENTA v
        WHERE v.IdTienda       = c.IdTienda
          AND v.FechaRegistro >= c.FechaApertura
          AND v.Estado         = 'Activa'
    ) vt
    OUTER APPLY (
        SELECT
            ISNULL(SUM(cx.MontoRecibido - cx.MontoCambio), 0) AS TotalCobrosCXC,
            COUNT(cx.IdCobroCXC)                               AS CantCobrosCXC
        FROM dbo.COBRO_CXC cx
        WHERE cx.IdCaja = c.IdCaja
    ) cx
    WHERE (@IdTienda  = 0 OR c.IdTienda  = @IdTienda)
      AND (@IdUsuario = 0 OR c.IdUsuario = @IdUsuario)   -- cada cajero ve su caja (0 = todas)
      AND c.Estado = 'Abierta';
END
GO
PRINT 'OK: usp_ObtenerCajaActiva — columnas completas + filtro por usuario.';
GO
