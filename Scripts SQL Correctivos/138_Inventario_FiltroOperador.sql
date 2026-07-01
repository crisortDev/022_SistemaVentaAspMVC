-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 138: Inventario — Agregar IdTienda al resultado del Supervisor
--             y ajustar filtro de operadores para asignación
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-23
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- Agrega i.IdTienda al SELECT para que el JS pueda filtrar operadores por sucursal
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerInventariosSupervisor
    @IdTienda INT = 0,
    @Estado   VARCHAR(30) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.IdInventario,
        i.IdTienda,                                               -- ← nuevo
        i.Numero,
        i.FechaRegistro,
        i.FechaInicio,
        i.FechaFinalizacion,
        i.Estado,
        i.Observacion,
        i.MotivoRechazo,
        t.Nombre                                          AS NombreTienda,
        ISNULL(u.Nombres + ' ' + u.Apellidos, 'Sistema') AS Supervisor,
        ISNULL(ua.Nombres + ' ' + ua.Apellidos, '—')     AS Aprobador,
        i.FechaAprobacion,
        STUFF((
            SELECT ', ' + ISNULL(uo.Nombres + ' ' + uo.Apellidos, CAST(ia.IdOperador AS VARCHAR))
            FROM dbo.INVENTARIO_ASIGNACION ia
            LEFT JOIN dbo.USUARIO uo ON uo.IdUsuario = ia.IdOperador
            WHERE ia.IdInventario = i.IdInventario
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, '')            AS Operadores,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario), 0)
            AS CantItems,
        ISNULL((SELECT COUNT(*) FROM dbo.DETALLE_INVENTARIO d WHERE d.IdInventario=i.IdInventario AND d.Diferencia<>0), 0)
            AS CantDiferencias
    FROM dbo.INVENTARIO i
    JOIN dbo.TIENDA t ON t.IdTienda = i.IdTienda
    LEFT JOIN dbo.USUARIO u  ON u.IdUsuario  = i.IdUsuarioRegistro
    LEFT JOIN dbo.USUARIO ua ON ua.IdUsuario = i.IdUsuarioAprueba
    WHERE (@IdTienda = 0 OR i.IdTienda = @IdTienda)
      AND (@Estado = '' OR i.Estado = @Estado)
    ORDER BY
        CASE i.Estado
            WHEN 'Pendiente de Aprobación' THEN 0
            WHEN 'En Progreso'             THEN 1
            WHEN 'En Corrección'           THEN 2
            WHEN 'Rechazado'               THEN 3
            WHEN 'Abierto'                 THEN 4
            ELSE 5
        END,
        i.FechaRegistro DESC;
END
GO
PRINT 'OK: usp_ObtenerInventariosSupervisor (con IdTienda)';
GO

PRINT '════ Script 138 completado ════';
GO
