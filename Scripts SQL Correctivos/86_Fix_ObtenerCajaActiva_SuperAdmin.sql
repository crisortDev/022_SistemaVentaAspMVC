-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 86: Fix usp_ObtenerCajaActiva para SuperAdmin
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- PROBLEMA:
--   usp_ObtenerCajaActiva tiene:
--       WHERE c.IdTienda = @IdTienda AND c.Estado = 'Abierta'
--
--   El controller llama con @IdTienda = 0 cuando el usuario es SuperAdmin.
--   Ninguna caja real tiene IdTienda = 0 (la caja fue abierta con IdTienda = 1 o 2).
--   Resultado: el SP retorna vacío → hayaCaja = false → no aparece el botón
--   "Cerrar Caja" ni el panel de la caja activa.
--
-- SOLUCIÓN:
--   Cambiar la condición a:
--       WHERE (@IdTienda = 0 OR c.IdTienda = @IdTienda) AND c.Estado = 'Abierta'
--   Igual que el resto de los SPs del sistema (usp_ObtenerHistorialCaja, etc.)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajaActiva
    @IdTienda INT
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
        -- Total ventas del turno (todas)
        ISNULL(vt.CantidadVentas, 0)  AS CantidadVentas,
        ISNULL(vt.TotalVentas,    0)  AS TotalVentas,
        -- Ventas SOLO contado (dinero real ingresado)
        ISNULL(vt.TotalContado,   0)  AS TotalVentasContado,
        ISNULL(vt.CantContado,    0)  AS CantVentasContado,
        -- Ventas crédito (vendidas pero aún no cobradas)
        ISNULL(vt.TotalCredito,   0)  AS TotalVentasCredito,
        ISNULL(vt.CantCredito,    0)  AS CantVentasCredito,
        -- Cobros de crédito recibidos en este turno (dinero real ingresado)
        ISNULL(cx.TotalCobrosCXC, 0)  AS TotalCobrosCXC,
        ISNULL(cx.CantCobrosCXC,  0)  AS CantCobrosCXC
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO u ON u.IdUsuario = c.IdUsuario
    -- Subquery ventas del turno
    OUTER APPLY (
        SELECT
            COUNT(v.IdVenta)                                                                     AS CantidadVentas,
            ISNULL(SUM(v.TotalCosto), 0)                                                         AS TotalVentas,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN v.TotalCosto ELSE 0 END), 0) AS TotalContado,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Contado' THEN 1 END)                AS CantContado,
            ISNULL(SUM(CASE WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN v.TotalCosto ELSE 0 END), 0) AS TotalCredito,
            COUNT(CASE  WHEN ISNULL(v.Condicion,'Contado')='Crédito' THEN 1 END)               AS CantCredito
        FROM dbo.VENTA v
        WHERE v.IdTienda       = c.IdTienda
          AND v.FechaRegistro >= c.FechaApertura
          AND v.Estado         = 'Activa'
    ) vt
    -- Subquery cobros CXC del turno
    OUTER APPLY (
        SELECT
            ISNULL(SUM(cx.MontoRecibido - cx.MontoCambio), 0) AS TotalCobrosCXC,
            COUNT(cx.IdCobroCXC)                               AS CantCobrosCXC
        FROM dbo.COBRO_CXC cx
        WHERE cx.IdCaja = c.IdCaja
    ) cx
    WHERE (@IdTienda = 0 OR c.IdTienda = @IdTienda)  -- ← FIX: 0 = cualquier tienda (SuperAdmin)
      AND c.Estado = 'Abierta';
END
GO

PRINT 'OK: usp_ObtenerCajaActiva corregido — SuperAdmin ahora ve la caja abierta de cualquier tienda.';

-- ── Verificación ─────────────────────────────────────────────────────────────
-- Ejecutar esto para confirmar que hay caja abierta:
SELECT c.IdCaja, c.IdTienda, t.Nombre AS Tienda, c.Estado, c.FechaApertura
FROM   dbo.CAJA c
INNER  JOIN dbo.TIENDA t ON t.IdTienda = c.IdTienda
WHERE  c.Estado = 'Abierta';

PRINT '════ Script 86 completado ════';
GO
