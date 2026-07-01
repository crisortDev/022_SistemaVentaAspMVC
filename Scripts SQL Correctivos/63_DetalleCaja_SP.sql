-- ============================================================
-- Script 63: usp_ObtenerDetalleCaja
-- Devuelve 3 result sets para Comprobante de Apertura y Arqueo
-- Fecha: 2026-05-19
-- ============================================================

USE [DBVENTAS_WEB]
GO

-- ── SP: usp_ObtenerDetalleCaja ────────────────────────────────
-- RS1: Cabecera de la sesión + datos empresa (para header de impresión)
-- RS2: Operaciones del turno (igual que usp_ObtenerOperacionesCaja RS1)
-- RS3: Resumen por forma de cobro (igual que RS2)
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerDetalleCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdTienda      INT;
    DECLARE @FechaApertura DATETIME;
    DECLARE @FechaCierre   DATETIME;

    SELECT @IdTienda      = IdTienda,
           @FechaApertura = FechaApertura,
           @FechaCierre   = ISNULL(FechaCierre, GETDATE())
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
        ISNULL(dt.PuntoExpedicion, '001')            AS PuntoExpedicion,
        -- Totales calculados en tiempo real
        ISNULL((
            SELECT COUNT(*)
            FROM   dbo.VENTA v
            WHERE  v.IdTienda       = @IdTienda
              AND  v.FechaRegistro >= c.FechaApertura
              AND  v.FechaRegistro <= @FechaCierre
              AND  v.Estado = 'Activa'
        ), 0)                                        AS CantidadVentas,
        ISNULL((
            SELECT SUM(v.TotalCosto)
            FROM   dbo.VENTA v
            WHERE  v.IdTienda       = @IdTienda
              AND  v.FechaRegistro >= c.FechaApertura
              AND  v.FechaRegistro <= @FechaCierre
              AND  v.Estado = 'Activa'
        ), 0)                                        AS TotalVentas
    FROM   dbo.CAJA    c
    INNER  JOIN dbo.TIENDA   t  ON t.IdTienda  = c.IdTienda
    INNER  JOIN dbo.USUARIO  ua ON ua.IdUsuario = c.IdUsuario
    LEFT   JOIN dbo.USUARIO  uc ON uc.IdUsuario = c.IdUsuarioCierre
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
        v.Estado
    FROM   dbo.VENTA               v
    INNER  JOIN dbo.USUARIO        ua ON ua.IdUsuario      = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE        cli ON cli.IdCliente    = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta     = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO    fc  ON fc.IdFormaCobro  = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- ── RS3: Resumen por forma de cobro (solo activas) ────────
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))  AS FormaCobro,
        COUNT(v.IdVenta)    AS Cantidad,
        SUM(v.TotalCosto)   AS TotalMonto
    FROM   dbo.VENTA               v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta    = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO    fc  ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdTienda       = @IdTienda
      AND  v.FechaRegistro >= @FechaApertura
      AND  v.FechaRegistro <= @FechaCierre
      AND  v.Estado = 'Activa'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerDetalleCaja creado.';
GO

-- ── Verificación ──────────────────────────────────────────────
-- Ejecutar con un IdCaja existente para verificar:
-- EXEC dbo.usp_ObtenerDetalleCaja @IdCaja = 1;

PRINT '════ Script 63 completado ════';
GO
