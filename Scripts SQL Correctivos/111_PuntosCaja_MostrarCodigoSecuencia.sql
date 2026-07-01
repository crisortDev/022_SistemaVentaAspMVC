-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 111: Gestión de Cajas — mostrar Código, Punto de Expedición y Secuencia
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31  ·  Depende del script 108.
--
-- usp_ObtenerPuntosCaja ahora devuelve Codigo, PuntoExpedicion, SecuenciaActual
-- y EstadoOperativo, para mostrarlos a modo informativo en la grilla de gestión.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerPuntosCaja
    @IdTienda INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pc.IdPuntoCaja,
        pc.IdTienda,
        t.Nombre                                  AS NombreTienda,
        pc.Nombre,
        ISNULL(pc.Descripcion, '')                AS Descripcion,
        ISNULL(pc.Codigo, '')                     AS Codigo,            -- nomenclatura caja
        ISNULL(pc.PuntoExpedicion, '')            AS PuntoExpedicion,   -- DNIT
        ISNULL(pc.SecuenciaActual, 0)             AS SecuenciaActual,   -- última factura emitida
        ISNULL(pc.EstadoOperativo, 'Activo')      AS EstadoOperativo,
        pc.Activo,
        pc.FechaRegistro,
        COUNT(c.IdCaja)                           AS TotalSesiones,
        SUM(CASE WHEN c.Estado = 'Abierta' THEN 1 ELSE 0 END) AS SesionesAbiertas,
        MAX(c.FechaApertura)                      AS UltimaApertura
    FROM dbo.PUNTO_CAJA pc
    INNER JOIN dbo.TIENDA t  ON t.IdTienda   = pc.IdTienda
    LEFT  JOIN dbo.CAJA   c  ON c.IdPuntoCaja = pc.IdPuntoCaja
    WHERE (@IdTienda = 0 OR pc.IdTienda = @IdTienda)
    GROUP BY pc.IdPuntoCaja, pc.IdTienda, t.Nombre,
             pc.Nombre, pc.Descripcion, pc.Codigo, pc.PuntoExpedicion,
             pc.SecuenciaActual, pc.EstadoOperativo, pc.Activo, pc.FechaRegistro
    ORDER BY pc.IdTienda, pc.PuntoExpedicion, pc.Nombre;
END
GO
PRINT 'OK: usp_ObtenerPuntosCaja — incluye Codigo, PuntoExpedicion, SecuenciaActual.';
GO
