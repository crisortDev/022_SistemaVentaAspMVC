-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 115: usp_ObtenerDetalleCaja — operaciones consistentes con el cuadre
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-02  ·  Reemplaza la versión del script 112.
--
-- PROBLEMA:
--   El cuadre (usp_CerrarCaja) cuenta ventas por TIENDA + RANGO DE FECHAS de la
--   sesión, pero el detalle de operaciones filtraba por v.IdCaja. Si una venta
--   quedó con IdCaja NULL, el cuadre la sumaba pero el detalle mostraba "0 ventas".
--
-- FIX:
--   RS2 (operaciones) y RS3 (resumen) usan el MISMO criterio que el cierre:
--     v.IdTienda = caja.IdTienda
--     AND v.FechaRegistro entre FechaApertura y FechaCierre (o ahora si sigue abierta)
--     AND v.Estado = 'Activa'
--   Además, si la venta tiene IdCaja, se respeta; si es NULL, igual entra por fecha.
--   (El fix en BaseController.CajaId evita que sigan entrando ventas con IdCaja NULL.)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda INT, @FechaApertura DATETIME, @FechaCorte DATETIME;
    SELECT @IdTienda     = IdTienda,
           @FechaApertura= FechaApertura,
           @FechaCorte   = ISNULL(FechaCierre, GETDATE())
    FROM   dbo.CAJA
    WHERE  IdCaja = @IdCaja;

    -- ── RS1: Cabecera ─────────────────────────────────────────
    SELECT
        c.IdCaja,
        c.IdTienda,
        t.Nombre                                     AS NombreTienda,
        ISNULL(t.Direccion, '')                      AS DireccionTienda,
        ISNULL(t.Telefono, '')                       AS TelefonoTienda,
        ua.Nombres + ' ' + ua.Apellidos              AS Aperturista,
        c.FechaApertura,
        c.MontoApertura,
        c.FechaCierre,
        ISNULL(uc.Nombres + ' ' + uc.Apellidos, '')  AS UsuarioCierre,
        ISNULL(c.MontoSistema, 0)                    AS MontoSistema,
        ISNULL(c.MontoContado, 0)                    AS MontoContado,
        ISNULL(c.Diferencia, 0)                      AS Diferencia,
        c.Estado,
        ISNULL(c.Observacion, '')                    AS Observacion,
        ISNULL(dt.RazonSocial, t.Nombre)             AS RazonSocial,
        ISNULL(dt.NumeroTimbrado, '')                AS NumeroTimbrado,
        ISNULL(dt.Establecimiento, '001')            AS Establecimiento,
        ISNULL(c.PuntoExpedicion,
               ISNULL(pc.PuntoExpedicion, dt.PuntoExpedicion))   AS PuntoExpedicion,
        ISNULL(c.CodigoCaja, ISNULL(pc.Codigo, ''))              AS CodigoCaja,
        ISNULL(pc.Nombre, '')                                    AS NombreCaja,
        -- Totales: mismo criterio que el cuadre (tienda + rango + IdCaja o fecha)
        ISNULL((
            SELECT COUNT(*)
            FROM   dbo.VENTA v
            WHERE  v.Estado = 'Activa'
              AND  v.IdTienda = @IdTienda
              AND  (v.IdCaja = @IdCaja
                    OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte))
        ), 0)                                        AS CantidadVentas,
        ISNULL((
            SELECT SUM(v.TotalCosto)
            FROM   dbo.VENTA v
            WHERE  v.Estado = 'Activa'
              AND  v.IdTienda = @IdTienda
              AND  (v.IdCaja = @IdCaja
                    OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte))
        ), 0)                                        AS TotalVentas
    FROM   dbo.CAJA    c
    INNER  JOIN dbo.TIENDA   t  ON t.IdTienda  = c.IdTienda
    INNER  JOIN dbo.USUARIO  ua ON ua.IdUsuario = c.IdUsuario
    LEFT   JOIN dbo.USUARIO  uc ON uc.IdUsuario = c.IdUsuarioCierre
    LEFT   JOIN dbo.PUNTO_CAJA pc ON pc.IdPuntoCaja = c.IdPuntoCaja
    OUTER  APPLY (SELECT TOP 1 RazonSocial, NumeroTimbrado, Establecimiento, PuntoExpedicion
                  FROM dbo.DATOS_TRIBUTARIOS) dt
    WHERE  c.IdCaja = @IdCaja;

    -- ── RS2: Operaciones del turno ────────────────────────────
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        v.FechaRegistro,
        ISNULL(cli.Nombre, 'Consumidor Final')                   AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        v.TotalCosto                                             AS Monto,
        ISNULL(cc.MontoRecibido, v.TotalCosto)                   AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                              AS MontoCambio,
        ua.Nombres + ' ' + ua.Apellidos                          AS NombreCajero,
        v.Estado                                                 AS Estado
    FROM   dbo.VENTA v
    INNER  JOIN dbo.USUARIO ua ON ua.IdUsuario = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE cli ON cli.IdCliente = v.IdCliente
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    WHERE  v.Estado = 'Activa'
      AND  v.IdTienda = @IdTienda
      AND  (v.IdCaja = @IdCaja
            OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte))
    ORDER  BY v.FechaRegistro;

    -- ── RS3: Resumen por forma de cobro ───────────────────────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))  AS FormaCobro,
        COUNT(v.IdVenta)    AS Cantidad,
        SUM(v.TotalCosto)   AS TotalMonto
    FROM   dbo.VENTA v
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    WHERE  v.Estado = 'Activa'
      AND  v.IdTienda = @IdTienda
      AND  (v.IdCaja = @IdCaja
            OR (v.IdCaja IS NULL AND v.FechaRegistro BETWEEN @FechaApertura AND @FechaCorte))
    GROUP  BY ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'));
END
GO
PRINT 'OK: usp_ObtenerDetalleCaja — operaciones consistentes con el cuadre.';
GO

-- ── OPCIONAL: vincular ventas huérfanas (IdCaja NULL) a la caja por fecha ───────
--   Repara ventas pasadas que quedaron sin IdCaja, asignándoles la caja cuya
--   ventana de apertura/cierre las contiene. Descomentá para ejecutar.
/*
UPDATE v
   SET v.IdCaja = c.IdCaja
FROM dbo.VENTA v
INNER JOIN dbo.CAJA c
   ON c.IdTienda = v.IdTienda
  AND v.FechaRegistro BETWEEN c.FechaApertura AND ISNULL(c.FechaCierre, GETDATE())
WHERE v.IdCaja IS NULL;
PRINT 'Ventas huérfanas vinculadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
*/
GO
