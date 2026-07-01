-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 81b: Fix usp_rptRentabilidadProducto + Menú Rentabilidad
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- Corrige:
--   1. CATEGORIA.Nombre → CATEGORIA.Descripcion  (columna real de la tabla)
--   2. Menú: busca el IdMenu de Reporte por controlador existente,
--            no por nombre (más robusto ante variaciones de nombre)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Corregir usp_rptRentabilidadProducto ─────────────────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_rptRentabilidadProducto]
    @IdTienda     INT  = 0,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL,
    @IdCategoria  INT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)));
    SET @FechaFin    = ISNULL(@FechaFin,    CAST(GETDATE() AS DATE));

    SELECT
        p.IdProducto,
        p.Codigo                                                        AS Codigo,
        p.Nombre                                                        AS Producto,
        -- CATEGORIA usa Descripcion, no Nombre
        ISNULL(cat.Descripcion, '—')                                   AS Categoria,
        t.Nombre                                                        AS Tienda,
        ISNULL(pt.Stock, 0)                                            AS StockActual,

        -- Costo Promedio Ponderado actual
        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)                AS CostoPromedio,

        -- Precio de venta vigente
        ISNULL(
            (SELECT TOP 1 pv.PrecioVenta
             FROM   dbo.PRECIO_VENTA pv
             WHERE  pv.IdProducto   = p.IdProducto
               AND  pv.FechaInicio <= GETDATE()
               AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
             ORDER  BY pv.FechaInicio DESC),
            CEILING(
                ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(cat.PorcentajeGanancia, 0) / 100.0)
            )
        )                                                               AS PrecioVentaVigente,

        -- Unidades vendidas en el período
        ISNULL(SUM(dv.Cantidad), 0)                                    AS UnidadesVendidas,

        -- Ingresos totales
        ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)                  AS IngresosTotales,

        -- Costo total según CPP
        ISNULL(SUM(dv.Cantidad), 0)
        * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)             AS CostoTotalVentas,

        -- Utilidad Bruta
        ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)
        - ISNULL(SUM(dv.Cantidad), 0)
          * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)           AS UtilidadBruta,

        -- Margen Bruto %
        CASE
            WHEN ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0) = 0 THEN 0
            ELSE CAST(
                (
                    (ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)
                     - ISNULL(SUM(dv.Cantidad), 0)
                       * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra))
                    / NULLIF(SUM(dv.Cantidad * dv.PrecioUnidad), 0) * 100.0
                ) AS DECIMAL(5,2))
        END                                                             AS MargenBrutoPct,

        -- Valor inventario al CPP
        ISNULL(pt.Stock, 0)
        * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)             AS ValorInventarioCPP

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p    ON p.IdProducto    = pt.IdProducto
    INNER JOIN dbo.TIENDA          t    ON t.IdTienda      = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       cat  ON cat.IdCategoria = p.IdCategoria
    LEFT  JOIN dbo.DETALLE_VENTA   dv   ON dv.IdProducto  = p.IdProducto
                                       AND dv.Activo      = 1
    LEFT  JOIN dbo.VENTA           v    ON v.IdVenta      = dv.IdVenta
                                       AND v.Estado       = 'Activa'
                                       AND v.IdTienda     = pt.IdTienda
                                       AND CAST(v.FechaRegistro AS DATE)
                                           BETWEEN @FechaInicio AND @FechaFin

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1
      AND  (@IdTienda    = 0 OR pt.IdTienda    = @IdTienda)
      AND  (@IdCategoria = 0 OR p.IdCategoria  = @IdCategoria)

    GROUP BY
        p.IdProducto, p.Codigo, p.Nombre, p.IvaPorcentaje,
        cat.Descripcion, cat.PorcentajeGanancia,
        t.Nombre,
        pt.Stock, pt.CostoPromedio, pt.PrecioUnidadCompra

    ORDER BY UtilidadBruta DESC;
END
GO
PRINT 'OK: usp_rptRentabilidadProducto corregido (Descripcion + columnas separadas).';
GO

-- ─── 2. Menú: buscar IdMenu por submenús existentes del controlador Reporte ───
DECLARE @IdMenuRpt INT;

-- Primero intentar por nombre exacto
SELECT @IdMenuRpt = IdMenu FROM dbo.MENU WHERE Nombre = 'Reporte';

-- Si no existe, buscarlo por los submenús ya registrados del controlador Reporte
IF @IdMenuRpt IS NULL
    SELECT TOP 1 @IdMenuRpt = IdMenu
    FROM   dbo.SUBMENU
    WHERE  Controlador = 'Reporte';

-- Mostrar qué nombre tiene realmente el menú encontrado
IF @IdMenuRpt IS NOT NULL
    PRINT 'OK: Menú Reporte encontrado (IdMenu = ' + CAST(@IdMenuRpt AS VARCHAR) +
          '): ' + (SELECT Nombre FROM dbo.MENU WHERE IdMenu = @IdMenuRpt);
ELSE
    PRINT 'WARN: No se encontró menú para el controlador Reporte. Creando...';

-- Crear el menú si definitivamente no existe
IF @IdMenuRpt IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Activo)
    VALUES ('Reporte', 'fas fa-chart-bar', 1);
    SET @IdMenuRpt = SCOPE_IDENTITY();
    PRINT 'OK: Menú "Reporte" creado (IdMenu = ' + CAST(@IdMenuRpt AS VARCHAR) + ').';
END

-- Insertar submenú Rentabilidad
DECLARE @IdSmRent INT;

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
    WHERE  Controlador = 'Reporte' AND Vista = 'Rentabilidad'
)
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuRpt, 'Rentabilidad (CPP)', 'Reporte', 'Rentabilidad', 'fas fa-chart-line', 35, 1);
    SET @IdSmRent = SCOPE_IDENTITY();
    PRINT 'OK: Submenú "Rentabilidad (CPP)" creado (IdSubMenu = ' + CAST(@IdSmRent AS VARCHAR) + ').';
END
ELSE
BEGIN
    SELECT @IdSmRent = IdSubMenu
    FROM   dbo.SUBMENU
    WHERE  Controlador = 'Reporte' AND Vista = 'Rentabilidad';
    PRINT 'INFO: Submenú "Rentabilidad (CPP)" ya existía (IdSubMenu = ' + CAST(@IdSmRent AS VARCHAR) + ').';
END

-- Asignar permisos (roles 1=SuperAdmin, 6=Gerente, 11=Administrador, 14=Supervisor)
DECLARE @rolesRent TABLE (IdRol INT);
INSERT INTO @rolesRent VALUES (1),(6),(11),(14);

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSmRent, 1, GETDATE()
FROM   @rolesRent r
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PERMISOS p
    WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmRent
);
PRINT 'OK: Permisos Rentabilidad asignados.';
GO

-- ─── Verificación final ───────────────────────────────────────────────────────
SELECT s.IdSubMenu, s.Nombre, s.Controlador, s.Vista, s.Icono, s.Orden, s.Activo
FROM   dbo.SUBMENU s
JOIN   dbo.MENU    m ON m.IdMenu = s.IdMenu
WHERE  s.Controlador = 'Reporte'
ORDER  BY s.Orden;
GO

PRINT '════ Script 81b completado ════';
GO
