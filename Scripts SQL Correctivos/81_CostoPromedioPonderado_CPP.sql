-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 81: Costo Promedio Ponderado (CPP) — Inventario Permanente Móvil
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-23
--
-- Objetivo:
--   Implementar el método CPP (Costo Promedio Ponderado / Inventario Permanente
--   por Costo Promedio Móvil) para productos en electrónica.
--
-- Cambios:
--   1. ALTER TABLE PRODUCTO_TIENDA: agrega CostoPromedio DECIMAL(18,2)
--   2. Inicializa CostoPromedio = PrecioUnidadCompra para filas existentes
--   3. usp_ConfirmarCompraEImpactarStock: calcula CPP en cada confirmación
--          Fórmula: NuevoCPP = (Stock * CPP + Cantidad * PrecioCompra)
--                              / (Stock + Cantidad)
--   4. usp_ObtenerProductoTienda: devuelve CostoPromedio
--   5. usp_rptRentabilidadProducto: reporte de margen bruto por producto
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Columna CostoPromedio en PRODUCTO_TIENDA ─────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.PRODUCTO_TIENDA')
      AND  name      = 'CostoPromedio'
)
BEGIN
    ALTER TABLE dbo.PRODUCTO_TIENDA
    ADD CostoPromedio DECIMAL(18,2) NULL;

    PRINT 'OK: Columna CostoPromedio agregada a PRODUCTO_TIENDA.';
END
ELSE
    PRINT 'INFO: Columna CostoPromedio ya existía.';
GO

-- ─── 2. Inicializar CPP para filas existentes ─────────────────────────────────
--   Usar PrecioUnidadCompra como punto de partida para el historial existente.
UPDATE dbo.PRODUCTO_TIENDA
SET    CostoPromedio = PrecioUnidadCompra
WHERE  CostoPromedio IS NULL
  AND  PrecioUnidadCompra IS NOT NULL
  AND  PrecioUnidadCompra > 0;

PRINT 'OK: CostoPromedio inicializado con PrecioUnidadCompra en filas existentes.';
GO

-- ─── 3. usp_ConfirmarCompraEImpactarStock con cálculo CPP ────────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ConfirmarCompraEImpactarStock]
    @IdCompra      INT,
    @IdUsuario     INT  = 0,
    @EsSuperAdmin  BIT  = 0,
    @Resultado     BIT           OUTPUT,
    @Mensaje       NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda          INT,
                @EstadoRecepcion   VARCHAR(20),
                @EstadoActual      VARCHAR(20),
                @IdUsuarioRegistro INT;

        SELECT @IdTienda          = IdTienda,
               @EstadoRecepcion   = EstadoRecepcion,
               @EstadoActual      = Estado,
               @IdUsuarioRegistro = IdUsuario
          FROM dbo.COMPRA
         WHERE IdCompra = @IdCompra;

        -- Validar que la compra exista
        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        -- Validar estado de recepción
        IF @EstadoRecepcion <> 'EnRecepcion'
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Solo se puede confirmar una compra en estado EnRecepcion. '
                           + 'Estado actual: ' + ISNULL(@EstadoRecepcion, '?');
            ROLLBACK; RETURN;
        END

        -- Validar NC pendiente antes de confirmar
        IF ISNULL((SELECT MontoNotaCredito FROM dbo.COMPRA WHERE IdCompra = @IdCompra), 0) = 0
           AND EXISTS (
               SELECT 1 FROM dbo.DETALLE_COMPRA
                WHERE IdCompra = @IdCompra
                  AND Activo   = 1
                  AND ISNULL(CantidadRecibida, Cantidad) < Cantidad
           )
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Existen diferencias de cantidades entre lo pedido y lo recibido. '
                           + 'Genere la Nota de Crédito correspondiente antes de confirmar la compra.';
            ROLLBACK; RETURN;
        END

        -- Validar segregación O&M
        IF @EsSuperAdmin = 0 AND @IdUsuario > 0 AND @IdUsuario = @IdUsuarioRegistro
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'El usuario que registró la factura no puede confirmarla (segregación de funciones).';
            ROLLBACK; RETURN;
        END

        -- Validar stock máximo (solo si StockMaximo > 0)
        DECLARE @ProductoSuperaMax VARCHAR(500) = '';

        SELECT @ProductoSuperaMax = @ProductoSuperaMax +
               p.Nombre + ' (actual: '  + CAST(ISNULL(pt.Stock, 0)  AS VARCHAR) +
               ', a recibir: '          + CAST(ISNULL(dc.CantidadRecibida, dc.Cantidad) AS VARCHAR) +
               ', máximo: '             + CAST(pt.StockMaximo AS VARCHAR) + ') | '
          FROM dbo.DETALLE_COMPRA dc
         INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = dc.IdProducto
                                          AND pt.IdTienda   = @IdTienda
         INNER JOIN dbo.PRODUCTO p         ON p.IdProducto  = dc.IdProducto
         WHERE dc.IdCompra    = @IdCompra
           AND dc.Activo      = 1
           AND pt.StockMaximo > 0
           AND ISNULL(pt.Stock, 0) + ISNULL(dc.CantidadRecibida, dc.Cantidad) > pt.StockMaximo;

        IF LEN(@ProductoSuperaMax) > 0
        BEGIN
            SET @Resultado = 0;
            SET @Mensaje   = 'Confirmar superaría el stock máximo en: ' + @ProductoSuperaMax;
            ROLLBACK; RETURN;
        END

        -- ─── Calcular líneas a recepcionar (Aceptada + NC) ───────────────────
        ;WITH Recepcionado AS (
            SELECT
                IdProducto,
                SUM(ISNULL(CantidadRecibida, Cantidad)) AS CantidadEntrada,
                -- Precio promedio ponderado de esta recepción
                -- (por si el mismo producto llega en varias líneas de la misma compra)
                CAST(
                    SUM(ISNULL(CantidadRecibida, Cantidad) * ISNULL(PrecioUnitarioCompra, 0))
                    / NULLIF(SUM(ISNULL(CantidadRecibida, Cantidad)), 0)
                AS DECIMAL(18,2)) AS PrecioCompraPromedio
            FROM dbo.DETALLE_COMPRA
            WHERE IdCompra    = @IdCompra
              AND Activo      = 1
              AND EstadoLinea IN ('Aceptada', 'NC')
            GROUP BY IdProducto
        )

        -- ─── Impactar stock + recalcular CPP en una sola pasada ──────────────
        UPDATE pt
        SET
            -- a) Actualizar stock
            Stock         = ISNULL(pt.Stock, 0) + r.CantidadEntrada,
            Iniciado      = 1,

            -- b) Recalcular CostoPromedio Ponderado
            --    Si stock actual + CPP actuales no existen → CPP = precio de esta compra
            --    Fórmula: (StockActual * CPP + CantidadEntrada * PrecioCompra)
            --             ─────────────────────────────────────────────────────
            --                   StockActual + CantidadEntrada
            CostoPromedio = CAST(
                CASE
                    -- Sin stock previo o CPP no inicializado: CPP = precio de esta compra
                    WHEN ISNULL(pt.Stock, 0) <= 0 OR ISNULL(pt.CostoPromedio, 0) = 0
                        THEN r.PrecioCompraPromedio
                    -- CPP ponderado normal
                    ELSE
                        (ISNULL(pt.Stock, 0) * ISNULL(pt.CostoPromedio, r.PrecioCompraPromedio)
                         + r.CantidadEntrada * r.PrecioCompraPromedio)
                        / (ISNULL(pt.Stock, 0) + r.CantidadEntrada)
                END
            AS DECIMAL(18,2)),

            -- c) Actualizar también PrecioUnidadCompra con el último precio recibido
            --    (referencia del último costo, distinto al CPP acumulado)
            PrecioUnidadCompra = r.PrecioCompraPromedio

        FROM dbo.PRODUCTO_TIENDA pt
        INNER JOIN Recepcionado r ON pt.IdProducto = r.IdProducto
        WHERE pt.IdTienda = @IdTienda;

        -- ── Actualizar estado de la compra ────────────────────────────────────
        UPDATE dbo.COMPRA
           SET EstadoRecepcion   = 'Confirmada',
               Estado            = 'Confirmada',
               FechaConfirmacion = GETDATE(),
               IdUsuarioConfirma = CASE WHEN @IdUsuario > 0 THEN @IdUsuario ELSE IdUsuarioConfirma END
         WHERE IdCompra = @IdCompra;

        -- ── Historial ─────────────────────────────────────────────────────────
        IF @IdUsuario > 0 AND EXISTS (SELECT 1 FROM dbo.USUARIO WHERE IdUsuario = @IdUsuario)
        BEGIN
            INSERT INTO dbo.HISTORIAL_ESTADO_COMPRA
                (IdCompra, EstadoAnterior, EstadoNuevo, IdUsuario, Observacion)
            VALUES
                (@IdCompra,
                 ISNULL(@EstadoActual, 'Pendiente'),
                 'Confirmada',
                 @IdUsuario,
                 CASE WHEN @EsSuperAdmin = 1
                      THEN 'Confirmación por SuperAdmin'
                      ELSE 'Confirmación de factura, stock e impacto CPP' END);
        END

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Compra confirmada. Stock y Costo Promedio Ponderado actualizados.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error al confirmar: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_ConfirmarCompraEImpactarStock actualizado con cálculo CPP.';
GO

-- ─── 4. usp_ObtenerProductoTienda: incluir CostoPromedio en el SELECT ────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerProductoTienda]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pt.IdProductoTienda,
        p.IdProducto,
        p.Codigo                          AS CodigoProducto,
        p.Nombre                          AS NombreProducto,
        p.Descripcion                     AS DescripcionProducto,
        t.IdTienda,
        t.RUC,
        t.Nombre                          AS NombreTienda,
        t.Direccion                       AS DireccionTienda,

        -- Último precio de compra (referencia)
        pt.PrecioUnidadCompra,

        -- ★ Costo Promedio Ponderado (CPP) — el costo real del inventario
        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)  AS CostoPromedio,

        -- Costo con IVA incluido
        CEILING(
            pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje / 100.0)
        )                                 AS PrecioCompraIvaIncluido,

        -- Precio de venta sugerido por margen de categoría (IVA incluido)
        CEILING(
            ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
            * (1.0 + p.IvaPorcentaje        / 100.0)
            * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
        )                                 AS PrecioSugerido,

        -- Porcentaje de ganancia de la categoría
        ISNULL(c.PorcentajeGanancia, 0)   AS PorcentajeGanancia,

        -- Precio de venta efectivo
        ISNULL(
            (
                SELECT TOP 1 pv.PrecioVenta
                FROM   dbo.PRECIO_VENTA pv
                WHERE  pv.IdProducto   = p.IdProducto
                  AND  pv.FechaInicio <= GETDATE()
                  AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                ORDER  BY pv.FechaInicio DESC
            ),
            CEILING(
                ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
                * (1.0 + p.IvaPorcentaje        / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                 AS PrecioVenta,

        ISNULL(
            (
                SELECT TOP 1 pv.PrecioVenta
                FROM   dbo.PRECIO_VENTA pv
                WHERE  pv.IdProducto   = p.IdProducto
                  AND  pv.FechaInicio <= GETDATE()
                  AND  (pv.FechaFin IS NULL OR pv.FechaFin >= GETDATE())
                ORDER  BY pv.FechaInicio DESC
            ),
            CEILING(
                ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)
                * (1.0 + p.IvaPorcentaje        / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 0) / 100.0)
            )
        )                                 AS PrecioVentaIvaIncluido,

        pt.Stock,
        p.IvaPorcentaje                   AS Porcentaje,
        pt.Iniciado

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p  ON p.IdProducto  = pt.IdProducto
    INNER JOIN dbo.TIENDA          t  ON t.IdTienda    = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       c  ON c.IdCategoria = p.IdCategoria

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1

    ORDER BY p.Nombre;
END
GO
PRINT 'OK: usp_ObtenerProductoTienda actualizado — incluye CostoPromedio.';
GO

-- ─── 5. usp_rptRentabilidadProducto — Reporte de margen bruto por producto ───
CREATE OR ALTER PROCEDURE [dbo].[usp_rptRentabilidadProducto]
    @IdTienda     INT          = 0,      -- 0 = todas las tiendas
    @FechaInicio  DATE         = NULL,
    @FechaFin     DATE         = NULL,
    @IdCategoria  INT          = 0       -- 0 = todas las categorías
AS
BEGIN
    SET NOCOUNT ON;

    SET @FechaInicio = ISNULL(@FechaInicio, DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)));
    SET @FechaFin    = ISNULL(@FechaFin,    CAST(GETDATE() AS DATE));

    SELECT
        p.IdProducto,
        p.Codigo                                                       AS Codigo,
        p.Nombre                                                       AS Producto,
        cat.Nombre                                                     AS Categoria,
        t.Nombre                                                       AS Tienda,
        pt.Stock                                                       AS StockActual,

        -- Costo Promedio Ponderado actual
        ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)                AS CostoPromedio,

        -- Precio de venta vigente (IVA incluido)
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
        )                                                              AS PrecioVentaVigente,

        -- Unidades vendidas en el período
        ISNULL(SUM(dv.Cantidad), 0)                                    AS UnidadesVendidas,

        -- Ingresos totales del período (precio de venta * cantidad)
        ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)                  AS IngresosTotales,

        -- Costo total de ventas según CPP
        ISNULL(
            SUM(dv.Cantidad)
            * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra),
            0
        )                                                              AS CostoTotalVentas,

        -- Utilidad Bruta = Ingresos − Costo CPP (sin IVA en ambos lados)
        ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)
        - ISNULL(
            SUM(dv.Cantidad)
            * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra),
            0
        )                                                              AS UtilidadBruta,

        -- Margen Bruto % = UtilidadBruta / Ingresos * 100
        CASE
            WHEN ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0) = 0 THEN 0
            ELSE CAST(
                (
                    (ISNULL(SUM(dv.Cantidad * dv.PrecioUnidad), 0)
                     - ISNULL(SUM(dv.Cantidad) * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra), 0))
                    / SUM(dv.Cantidad * dv.PrecioUnidad) * 100.0
                ) AS DECIMAL(5,2))
        END                                                            AS MargenBrutoPct,

        -- Valor del inventario actual según CPP
        ISNULL(pt.Stock, 0)
        * ISNULL(pt.CostoPromedio, pt.PrecioUnidadCompra)             AS ValorInventarioCPP

    FROM       dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO        p    ON p.IdProducto   = pt.IdProducto
    INNER JOIN dbo.TIENDA          t    ON t.IdTienda     = pt.IdTienda
    LEFT  JOIN dbo.CATEGORIA       cat  ON cat.IdCategoria = p.IdCategoria
    LEFT  JOIN dbo.DETALLE_VENTA   dv   ON dv.IdProducto  = p.IdProducto
                                       AND dv.Activo      = 1
    LEFT  JOIN dbo.VENTA           v    ON v.IdVenta      = dv.IdVenta
                                       AND v.Estado       = 'Activa'
                                       AND v.IdTienda     = pt.IdTienda
                                       AND CAST(v.FechaRegistro AS DATE) BETWEEN @FechaInicio AND @FechaFin

    WHERE  p.Activo  = 1
      AND  pt.Activo = 1
      AND  (@IdTienda   = 0 OR pt.IdTienda   = @IdTienda)
      AND  (@IdCategoria = 0 OR p.IdCategoria = @IdCategoria)

    GROUP BY
        p.IdProducto, p.Codigo, p.Nombre, p.IvaPorcentaje,
        cat.Nombre, cat.PorcentajeGanancia,
        t.Nombre,
        pt.Stock, pt.CostoPromedio, pt.PrecioUnidadCompra

    ORDER BY UtilidadBruta DESC;
END
GO
PRINT 'OK: usp_rptRentabilidadProducto creado.';
GO

-- ─── 6. Menú: Reporte de Rentabilidad (CPP) ─────────────────────────────────
DECLARE @IdMenuRpt INT;
SELECT @IdMenuRpt = IdMenu FROM dbo.MENU WHERE Nombre = 'Reporte';

IF @IdMenuRpt IS NULL
BEGIN
    PRINT 'ERROR: No existe el menú "Reporte". Verificar tabla MENU.';
END
ELSE
BEGIN
    DECLARE @IdSmRent INT;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.SUBMENU
        WHERE Controlador = 'Reporte' AND Vista = 'Rentabilidad'
    )
    BEGIN
        INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
        VALUES (@IdMenuRpt, 'Rentabilidad (CPP)', 'Reporte', 'Rentabilidad', 'fas fa-chart-line', 35, 1);
        SET @IdSmRent = SCOPE_IDENTITY();
        PRINT 'OK: Submenú "Rentabilidad (CPP)" creado (IdSubMenu = ' + CAST(@IdSmRent AS VARCHAR) + ').';
    END
    ELSE
    BEGIN
        SELECT @IdSmRent = IdSubMenu FROM dbo.SUBMENU
        WHERE Controlador = 'Reporte' AND Vista = 'Rentabilidad';
        PRINT 'INFO: Submenú "Rentabilidad (CPP)" ya existía.';
    END

    -- Roles: 1=SuperAdmin, 6=Gerente, 11=Administrador, 14=Supervisor (igual que NC y Proveedores)
    DECLARE @rolesRent TABLE (IdRol INT);
    INSERT INTO @rolesRent VALUES (1),(6),(11),(14);

    INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
    SELECT r.IdRol, @IdSmRent, 1, GETDATE()
    FROM   @rolesRent r
    WHERE  NOT EXISTS (
        SELECT 1 FROM dbo.PERMISOS p
        WHERE  p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmRent
    );
    PRINT 'OK: Permisos Rentabilidad (CPP) asignados.';
END
GO

PRINT '════ Script 81 completado — CPP + Menú Rentabilidad ════';
GO
