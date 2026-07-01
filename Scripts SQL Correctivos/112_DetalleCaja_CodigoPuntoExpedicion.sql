-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 112: Comprobantes de caja muestran Código y Punto de Expedición de la caja
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31  ·  Depende de scripts 108-111.
--
-- usp_ObtenerDetalleCaja (alimenta comprobante de apertura, arqueo y cierre) ahora
-- devuelve CodigoCaja y el PuntoExpedicion DE LA CAJA (no el global), para que los
-- comprobantes muestren la nomenclatura correcta (#11, #12).
--
-- Sólo se modifica la cabecera (RS1). RS2 y RS3 quedan igual.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda INT, @FechaCierre DATETIME;
    SELECT @IdTienda    = IdTienda,
           @FechaCierre = ISNULL(FechaCierre, GETDATE())
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
        -- Datos tributarios / empresa
        ISNULL(dt.RazonSocial, t.Nombre)             AS RazonSocial,
        ISNULL(dt.NumeroTimbrado, '')                AS NumeroTimbrado,
        ISNULL(dt.Establecimiento, '001')            AS Establecimiento,
        -- ★ Punto de expedición y código DE LA CAJA (hereda lo guardado al abrir;
        --   si la sesión es vieja y no lo tiene, cae al del PUNTO_CAJA y luego al global)
        ISNULL(c.PuntoExpedicion,
               ISNULL(pc.PuntoExpedicion, dt.PuntoExpedicion))   AS PuntoExpedicion,
        ISNULL(c.CodigoCaja, ISNULL(pc.Codigo, ''))              AS CodigoCaja,
        ISNULL(pc.Nombre, '')                                    AS NombreCaja,
        -- Totales calculados en tiempo real
        ISNULL((
            SELECT COUNT(*)
            FROM   dbo.VENTA v
            WHERE  v.IdCaja = @IdCaja
              AND  v.Estado = 'Activa'
        ), 0)                                        AS CantidadVentas,
        ISNULL((
            SELECT SUM(v.TotalCosto)
            FROM   dbo.VENTA v
            WHERE  v.IdCaja = @IdCaja
              AND  v.Estado = 'Activa'
        ), 0)                                        AS TotalVentas
    FROM   dbo.CAJA    c
    INNER  JOIN dbo.TIENDA   t  ON t.IdTienda  = c.IdTienda
    INNER  JOIN dbo.USUARIO  ua ON ua.IdUsuario = c.IdUsuario
    LEFT   JOIN dbo.USUARIO  uc ON uc.IdUsuario = c.IdUsuarioCierre
    LEFT   JOIN dbo.PUNTO_CAJA pc ON pc.IdPuntoCaja = c.IdPuntoCaja
    OUTER  APPLY (SELECT TOP 1 RazonSocial, NumeroTimbrado, Establecimiento, PuntoExpedicion
                  FROM dbo.DATOS_TRIBUTARIOS) dt
    WHERE  c.IdCaja = @IdCaja;

    -- ── RS2: Operaciones del turno (filtra por la caja) ───────
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        v.FechaRegistro,
        ISNULL(cli.Nombre, 'Consumidor Final')                   AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))    AS FormaCobro,
        v.TotalCosto                                             AS Monto,
        ISNULL(cc.MontoRecibido, v.TotalCosto)                   AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                              AS MontoCambio,
        ua.Nombres + ' ' + ua.Apellidos                          AS NombreCajero
    FROM   dbo.VENTA v
    INNER  JOIN dbo.USUARIO ua ON ua.IdUsuario = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE cli ON cli.IdCliente = v.IdCliente
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    WHERE  v.IdCaja = @IdCaja
      AND  v.Estado = 'Activa'
    ORDER  BY v.FechaRegistro;

    -- ── RS3: Resumen por forma de cobro ───────────────────────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))  AS FormaCobro,
        COUNT(v.IdVenta)    AS Cantidad,
        SUM(v.TotalCosto)   AS TotalMonto
    FROM   dbo.VENTA v
    LEFT   JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    WHERE  v.IdCaja = @IdCaja
      AND  v.Estado = 'Activa'
    GROUP  BY ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'));
END
GO
PRINT 'OK: usp_ObtenerDetalleCaja — usa Código y Punto de Expedición de la caja.';
GO
