-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 19: Agregar NecesitaNC y MontoNotaCredito a usp_ObtenerListaCompraRevision
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-06
--
-- Permite que la vista Revisión de Compras detecte si una compra tiene
-- diferencias de cantidad sin NC generada, para mostrar el botón NC.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerListaCompraRevision]
    @FechaInicio DATE,
    @FechaFin    DATE,
    @IdProveedor INT = 0,
    @IdTienda    INT = 0,
    @Estado      VARCHAR(20) = 'Pendiente'
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT DMY;

    SELECT
        c.IdCompra,
        RIGHT('000000' + CONVERT(VARCHAR, c.IdCompra), 6)   AS NumeroCompra,
        c.NumeroFactura,
        c.NumeroTimbrado,
        p.IdProveedor,
        p.RazonSocial,
        t.IdTienda,
        t.Nombre                                             AS NombreTienda,
        CONVERT(CHAR(10), c.FechaRegistro,  103)             AS FechaRegistro,
        CONVERT(CHAR(10), c.FechaFactura,   103)             AS FechaFactura,
        CONVERT(CHAR(10), c.FechaEntrega,   103)             AS FechaEntrega,
        c.TotalCosto,
        c.Estado,
        c.EstadoRecepcion,
        c.IdUsuario                                          AS IdUsuarioRegistro,
        u.Nombres                                            AS UsuarioRegistro,
        oc.NumeroOrden,
        oc.IdOrdenCompra,
        -- NC ya generada
        ISNULL(c.MontoNotaCredito, 0)                        AS MontoNotaCredito,
        -- Necesita NC: tiene líneas con diferencia y aún no se generó NC
        CASE
            WHEN ISNULL(c.MontoNotaCredito, 0) = 0
             AND EXISTS (
                SELECT 1 FROM dbo.DETALLE_COMPRA dc
                 WHERE dc.IdCompra = c.IdCompra
                   AND dc.Activo   = 1
                   AND ISNULL(dc.CantidadRecibida, dc.Cantidad) < dc.Cantidad
             )
            THEN 1
            ELSE 0
        END                                                  AS NecesitaNC
    FROM dbo.COMPRA c
    INNER JOIN dbo.PROVEEDOR p  ON p.IdProveedor = c.IdProveedor
    INNER JOIN dbo.TIENDA    t  ON t.IdTienda    = c.IdTienda
    INNER JOIN dbo.USUARIO   u  ON u.IdUsuario   = c.IdUsuario
    LEFT  JOIN dbo.CompraOrdenCompra coc ON coc.IdCompra    = c.IdCompra
    LEFT  JOIN dbo.OrdenCompra       oc  ON oc.IdOrdenCompra = coc.IdOrdenCompra
    WHERE c.Activo = 1
      AND CONVERT(DATE, c.FechaRegistro) BETWEEN @FechaInicio AND @FechaFin
      AND p.IdProveedor = IIF(@IdProveedor = 0, p.IdProveedor, @IdProveedor)
      AND t.IdTienda    = IIF(@IdTienda    = 0, t.IdTienda,    @IdTienda)
      AND (@Estado = 'Todos' OR c.Estado = @Estado)
    ORDER BY c.IdCompra DESC;
END
GO
PRINT 'OK: usp_ObtenerListaCompraRevision actualizado con NecesitaNC y MontoNotaCredito'
