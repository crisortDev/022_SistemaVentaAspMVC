-- ════════════════════════════════════════════════════════════════════════════════
-- FIX 38c — Correcciones post-ejecución de 38c
-- 1. Agregar columna Orden a MENU y SUBMENU (no existía) → reinsertar menús
-- 2. Corregir demo OV-00000002 (PrecioUnidadVenta=NULL → usar precio por margen)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1a. Agregar Orden a MENU (si no existe) ───────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.MENU') AND name = 'Orden'
)
BEGIN
    ALTER TABLE dbo.MENU ADD Orden INT NULL;
    PRINT 'OK: Columna Orden agregada a MENU.';
END
ELSE
    PRINT 'INFO: MENU ya tiene columna Orden.';
GO

-- ── 1b. Agregar Orden a SUBMENU (si no existe) ────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SUBMENU') AND name = 'Orden'
)
BEGIN
    ALTER TABLE dbo.SUBMENU ADD Orden INT NULL;
    PRINT 'OK: Columna Orden agregada a SUBMENU.';
END
ELSE
    PRINT 'INFO: SUBMENU ya tiene columna Orden.';
GO

-- ── 2. Insertar / actualizar menús Venta y Caja ───────────────────────────────
DECLARE @IdMenuVenta INT, @IdMenuCaja INT;
SELECT @IdMenuVenta = IdMenu FROM dbo.MENU WHERE Nombre IN ('Venta','Ventas');
SELECT @IdMenuCaja  = IdMenu FROM dbo.MENU WHERE Nombre IN ('Caja','ConsultarCajaCompra');

IF @IdMenuVenta IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Orden, Activo)
    VALUES ('Venta', 'fa-shopping-cart', 3, 1);
    SET @IdMenuVenta = SCOPE_IDENTITY();
    PRINT 'OK: Menú Venta creado.';
END
ELSE
BEGIN
    UPDATE dbo.MENU SET Orden = 3 WHERE IdMenu = @IdMenuVenta;
    PRINT 'INFO: Menú Venta ya existía — Orden actualizado.';
END

IF @IdMenuCaja IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Orden, Activo)
    VALUES ('Caja', 'fa-cash-register', 4, 1);
    SET @IdMenuCaja = SCOPE_IDENTITY();
    PRINT 'OK: Menú Caja creado.';
END
ELSE
BEGIN
    UPDATE dbo.MENU SET Orden = 4 WHERE IdMenu = @IdMenuCaja;
    PRINT 'INFO: Menú Caja ya existía — Orden actualizado.';
END
GO

-- ── 3. Insertar SUBMENUs (idempotente) ────────────────────────────────────────
DECLARE @IdMenuVenta INT, @IdMenuCaja INT;
SELECT @IdMenuVenta = IdMenu FROM dbo.MENU WHERE Nombre IN ('Venta','Ventas');
SELECT @IdMenuCaja  = IdMenu FROM dbo.MENU WHERE Nombre IN ('Caja','ConsultarCajaCompra');

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Registrar Venta Directa')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Registrar Venta Directa', 'Venta', 'Crear', 'fa-bolt', 1, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Consultar Ventas')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Consultar Ventas', 'Venta', 'Consultar', 'fa-list', 2, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Registrar Pre-venta')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Registrar Pre-venta', 'OrdenVenta', 'Crear', 'fa-file-invoice', 3, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Consultar Pre-ventas')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Consultar Pre-ventas', 'OrdenVenta', 'Consultar', 'fa-clipboard-list', 4, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='ComprobanteCobro' AND Nombre='Comprobantes de Cobro')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuCaja, 'Comprobantes de Cobro', 'ComprobanteCobro', 'Index', 'fa-receipt', 1, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='NotaCreditoVenta' AND Nombre='Notas de Crédito Venta')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Notas de Crédito Venta', 'NotaCreditoVenta', 'Index', 'fa-file-contract', 5, 1);

PRINT 'OK: SUBMENUs módulo ventas verificados/insertados.';
GO

-- ── 4. Corregir pre-venta OV-00000002 (precio por margen) ────────────────────
-- OV-00000001 ya se creó OK. OV-00000002 falló porque PrecioUnidadVenta = NULL.
-- Ahora calculamos el precio con la fórmula de margen de categoría (igual que script 39).
IF NOT EXISTS (SELECT 1 FROM dbo.ORDEN_VENTA WHERE NumeroOV='OV-00000002')
BEGIN
    DECLARE @IdCliente3 INT, @IdProducto1b INT, @IdProducto2b INT;
    DECLARE @IdUsuarioRepos2 INT;
    DECLARE @PrecioP1b DECIMAL(18,2), @PrecioP2b DECIMAL(18,2);

    SELECT TOP 1 @IdCliente3 = IdCliente FROM dbo.CLIENTE WHERE NumeroDocumento = '80012345-1';
    SELECT TOP 1 @IdUsuarioRepos2 = IdUsuario FROM dbo.USUARIO WHERE IdRol=7 AND Activo=1;
    IF @IdUsuarioRepos2 IS NULL
        SELECT TOP 1 @IdUsuarioRepos2 = IdUsuario FROM dbo.USUARIO WHERE Activo=1;

    -- Productos con stock en tienda 1 (ordenados por IdProducto)
    SELECT TOP 1 @IdProducto1b = pt.IdProducto
    FROM dbo.PRODUCTO_TIENDA pt
    WHERE pt.IdTienda=1 AND pt.Stock>0 AND pt.Activo=1
    ORDER BY pt.IdProducto;

    SELECT TOP 1 @IdProducto2b = pt.IdProducto
    FROM dbo.PRODUCTO_TIENDA pt
    WHERE pt.IdTienda=1 AND pt.Stock>0 AND pt.Activo=1
      AND pt.IdProducto <> ISNULL(@IdProducto1b,0)
    ORDER BY pt.IdProducto;

    -- Precio con margen de categoría (igual que usp_ObtenerProductoTienda del script 39)
    SELECT TOP 1 @PrecioP1b =
        CEILING(pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 20) / 100.0))
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdProducto = @IdProducto1b AND pt.IdTienda = 1;

    SELECT TOP 1 @PrecioP2b =
        CEILING(pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 20) / 100.0))
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdProducto = @IdProducto2b AND pt.IdTienda = 1;

    -- Fallback por si PrecioUnidadCompra también es 0
    IF ISNULL(@PrecioP1b, 0) = 0 SET @PrecioP1b = 100000;
    IF ISNULL(@PrecioP2b, 0) = 0 SET @PrecioP2b = 150000;

    DECLARE @TotalOV2 DECIMAL(18,2) = @PrecioP1b + @PrecioP2b;

    INSERT INTO dbo.ORDEN_VENTA
        (NumeroOV,IdTienda,IdCliente,IdUsuarioRegistro,TotalEstimado,IVA10,IVA5,Exento0,
         Estado,Observacion,FechaVencimiento,Activo)
    VALUES
        ('OV-00000002',1,@IdCliente3,@IdUsuarioRepos2,
         @TotalOV2, @TotalOV2*10.0/110.0, 0, 0,
         'Pendiente','Compra corporativa — aprobación pendiente del área financiera',
         DATEADD(DAY,3,CAST(GETDATE() AS DATE)), 1);

    DECLARE @IdOV2 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.DETALLE_ORDEN_VENTA
        (IdOrdenVenta,IdProducto,Cantidad,PrecioUnidad,IvaPorcentaje,TotalLinea,TotalLineaIva)
    VALUES (@IdOV2, @IdProducto1b, 1, @PrecioP1b, 10, @PrecioP1b, @PrecioP1b*1.10);

    INSERT INTO dbo.DETALLE_ORDEN_VENTA
        (IdOrdenVenta,IdProducto,Cantidad,PrecioUnidad,IvaPorcentaje,TotalLinea,TotalLineaIva)
    VALUES (@IdOV2, @IdProducto2b, 1, @PrecioP2b, 10, @PrecioP2b, @PrecioP2b*1.10);

    PRINT 'OK: Pre-venta OV-00000002 creada (precio por margen de categoría).';
END
ELSE
    PRINT 'INFO: OV-00000002 ya existe.';
GO

-- ── 5. También actualizar 38c para futuros usos ──────────────────────────────
-- (38b y 38c ya fueron corregidos en archivo. Este script sólo aplica parches en BD)

PRINT '';
PRINT '════════════════════════════════════════════════════════════';
PRINT 'Fix 38c completado. Verificar menús y pre-ventas en BD.';
PRINT 'Ejecutar a continuación: 39_PrecioVentaPorMargenCategoria.sql';
PRINT '════════════════════════════════════════════════════════════';
GO
