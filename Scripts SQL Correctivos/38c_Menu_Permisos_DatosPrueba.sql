-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 38c: Menú + Permisos + Datos de prueba — Módulo de Ventas
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Insertar SUBMENUs del módulo ventas
-- 2. Permisos por rol (matriz segregación de funciones ventas)
-- 3. Datos de prueba: clientes, pre-ventas pendientes, ventas de demo
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. SUBMENUs — Módulo Ventas
-- ══════════════════════════════════════════════════════════════════════════════
-- Identificar IdMenu de Venta y Caja
DECLARE @IdMenuVenta INT, @IdMenuCaja INT;
SELECT @IdMenuVenta = IdMenu FROM dbo.MENU WHERE Nombre = 'Venta' OR Nombre = 'Ventas';
SELECT @IdMenuCaja  = IdMenu FROM dbo.MENU WHERE Nombre = 'Caja'  OR Nombre = 'ConsultarCajaCompra';

-- Si no existe menú Venta, crearlo
IF @IdMenuVenta IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Activo) VALUES ('Venta','fa-shopping-cart', 1);
    SET @IdMenuVenta = SCOPE_IDENTITY();
    PRINT 'OK: Menú Venta creado.';
END

-- Si no existe menú Caja, crearlo
IF @IdMenuCaja IS NULL
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Activo) VALUES ('Caja','fa-cash-register', 1);
    SET @IdMenuCaja = SCOPE_IDENTITY();
    PRINT 'OK: Menú Caja creado.';
END
GO

DECLARE @IdMenuVenta INT, @IdMenuCaja INT, @IdMenuNC INT;
SELECT @IdMenuVenta = IdMenu FROM dbo.MENU WHERE Nombre IN ('Venta','Ventas');
SELECT @IdMenuCaja  = IdMenu FROM dbo.MENU WHERE Nombre IN ('Caja','ConsultarCajaCompra');

-- Menú NC Venta (puede ir bajo Venta o separado)
SELECT @IdMenuNC = IdMenu FROM dbo.MENU WHERE Nombre = 'Venta' OR Nombre = 'Ventas';

-- ── Registrar Venta Directa ──────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Registrar Venta Directa')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Registrar Venta Directa', 'Venta', 'Crear', 'fa-bolt', 1, 1);

-- ── Consultar Ventas ─────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='Venta' AND Nombre='Consultar Ventas')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Consultar Ventas', 'Venta', 'Consultar', 'fa-list', 2, 1);

-- ── Registrar Pre-venta ──────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Registrar Pre-venta')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Registrar Pre-venta', 'OrdenVenta', 'Crear', 'fa-file-invoice', 3, 1);

-- ── Consultar Pre-ventas ─────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='OrdenVenta' AND Nombre='Consultar Pre-ventas')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Consultar Pre-ventas', 'OrdenVenta', 'Consultar', 'fa-clipboard-list', 4, 1);

-- ── Comprobantes de Cobro (bajo Caja) ────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='ComprobanteCobro' AND Nombre='Comprobantes de Cobro')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuCaja, 'Comprobantes de Cobro', 'ComprobanteCobro', 'Index', 'fa-receipt', 1, 1);

-- ── Notas de Crédito Venta (bajo Venta) ─────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE Controlador='NotaCreditoVenta' AND Nombre='Notas de Crédito Venta')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo)
    VALUES (@IdMenuVenta, 'Notas de Crédito Venta', 'NotaCreditoVenta', 'Index', 'fa-file-contract', 5, 1);

PRINT 'OK: SUBMENUs módulo ventas insertados.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. PERMISOS por rol
-- ══════════════════════════════════════════════════════════════════════════════
-- Roles: 7=REPOSITOR, 4=CAJERO, 6=Encargado, 11=SUPERVISOR, 1=ADMINISTRADOR, 14=SUPERADMIN

DECLARE @smVentaDirecta   INT, @smConsVenta     INT,
        @smRegOV          INT, @smConsOV        INT,
        @smCC             INT, @smNCV           INT;

SELECT @smVentaDirecta = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Venta'            AND Nombre='Registrar Venta Directa';
SELECT @smConsVenta    = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='Venta'            AND Nombre='Consultar Ventas';
SELECT @smRegOV        = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta'       AND Nombre='Registrar Pre-venta';
SELECT @smConsOV       = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='OrdenVenta'       AND Nombre='Consultar Pre-ventas';
SELECT @smCC           = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='ComprobanteCobro' AND Nombre='Comprobantes de Cobro';
SELECT @smNCV          = IdSubMenu FROM dbo.SUBMENU WHERE Controlador='NotaCreditoVenta' AND Nombre='Notas de Crédito Venta';

CREATE TABLE #PermVenta (IdRol INT, IdSubMenu INT, Activo BIT);

-- Registrar Venta Directa: CAJERO✓ Encargado✓ ADMIN✓ SA✓ | REPOS✗ SUPER✗
IF @smVentaDirecta IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smVentaDirecta,0),(4,@smVentaDirecta,1),(6,@smVentaDirecta,1),
    (11,@smVentaDirecta,0),(1,@smVentaDirecta,1),(14,@smVentaDirecta,1);

-- Consultar Ventas: todos ✓
IF @smConsVenta IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smConsVenta,1),(4,@smConsVenta,1),(6,@smConsVenta,1),
    (11,@smConsVenta,1),(1,@smConsVenta,1),(14,@smConsVenta,1);

-- Registrar Pre-venta: REPOS✓ CAJERO✓ ADMIN✓ SA✓ | Encarg✗ SUPER✗
IF @smRegOV IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smRegOV,1),(4,@smRegOV,1),(6,@smRegOV,0),
    (11,@smRegOV,0),(1,@smRegOV,1),(14,@smRegOV,1);

-- Consultar Pre-ventas: todos ✓
IF @smConsOV IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smConsOV,1),(4,@smConsOV,1),(6,@smConsOV,1),
    (11,@smConsOV,1),(1,@smConsOV,1),(14,@smConsOV,1);

-- Comprobantes de Cobro: CAJERO✓ Encargado✓ SUPER✓ ADMIN✓ SA✓ | REPOS✗
IF @smCC IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smCC,0),(4,@smCC,1),(6,@smCC,1),
    (11,@smCC,1),(1,@smCC,1),(14,@smCC,1);

-- NC Venta: Encargado✓ SUPER✓ ADMIN✓ SA✓ | REPOS✗ CAJERO✗
IF @smNCV IS NOT NULL INSERT INTO #PermVenta VALUES
    (7,@smNCV,0),(4,@smNCV,0),(6,@smNCV,1),
    (11,@smNCV,1),(1,@smNCV,1),(14,@smNCV,1);

-- Aplicar: UPDATE existentes + INSERT faltantes
UPDATE p SET p.Activo = pv.Activo
FROM dbo.PERMISOS p JOIN #PermVenta pv ON pv.IdRol=p.IdRol AND pv.IdSubMenu=p.IdSubMenu;

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT pv.IdRol, pv.IdSubMenu, pv.Activo, GETDATE()
FROM #PermVenta pv
WHERE NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol=pv.IdRol AND p.IdSubMenu=pv.IdSubMenu);

DROP TABLE #PermVenta;
PRINT 'OK: Permisos módulo ventas aplicados.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. MOTIVOS NOTA CRÉDITO VENTA (reutilizar tabla MOTIVO_NOTA_CREDITO)
-- ══════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM dbo.MOTIVO_NOTA_CREDITO WHERE Descripcion = 'Devolución por producto defectuoso')
    INSERT INTO dbo.MOTIVO_NOTA_CREDITO (Descripcion) VALUES ('Devolución por producto defectuoso');
IF NOT EXISTS (SELECT 1 FROM dbo.MOTIVO_NOTA_CREDITO WHERE Descripcion = 'Error en precio cobrado')
    INSERT INTO dbo.MOTIVO_NOTA_CREDITO (Descripcion) VALUES ('Error en precio cobrado');
IF NOT EXISTS (SELECT 1 FROM dbo.MOTIVO_NOTA_CREDITO WHERE Descripcion = 'Producto incorrecto entregado')
    INSERT INTO dbo.MOTIVO_NOTA_CREDITO (Descripcion) VALUES ('Producto incorrecto entregado');
IF NOT EXISTS (SELECT 1 FROM dbo.MOTIVO_NOTA_CREDITO WHERE Descripcion = 'Cancelación de venta por cliente')
    INSERT INTO dbo.MOTIVO_NOTA_CREDITO (Descripcion) VALUES ('Cancelación de venta por cliente');
PRINT 'OK: Motivos NC Venta insertados.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. DATOS DE PRUEBA
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 4.1 Clientes de prueba ───────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE NumeroDocumento = '1234567')
    INSERT INTO dbo.CLIENTE (TipoDocumento,NumeroDocumento,Nombre,Direccion,Telefono,Activo,FechaRegistro)
    VALUES ('CI','1234567','María González','Avda. España 1234','0981-111222',1,GETDATE());

IF NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE NumeroDocumento = '2345678')
    INSERT INTO dbo.CLIENTE (TipoDocumento,NumeroDocumento,Nombre,Direccion,Telefono,Activo,FechaRegistro)
    VALUES ('CI','2345678','Roberto Aquino','Calle 3 de Febrero 567','0971-333444',1,GETDATE());

IF NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE NumeroDocumento = '80012345-1')
    INSERT INTO dbo.CLIENTE (TipoDocumento,NumeroDocumento,Nombre,Direccion,Telefono,Activo,FechaRegistro)
    VALUES ('RUC','80012345-1','TechSolutions S.A.','Mcal. López 890','021-555666',1,GETDATE());

IF NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE NumeroDocumento = '3456789')
    INSERT INTO dbo.CLIENTE (TipoDocumento,NumeroDocumento,Nombre,Direccion,Telefono,Activo,FechaRegistro)
    VALUES ('CI','3456789','Ana Ramírez','Ytororo 234','0991-777888',1,GETDATE());

-- Cliente genérico "consumidor final" para ventas rápidas
IF NOT EXISTS (SELECT 1 FROM dbo.CLIENTE WHERE NumeroDocumento = '0000000')
    INSERT INTO dbo.CLIENTE (TipoDocumento,NumeroDocumento,Nombre,Direccion,Telefono,Activo,FechaRegistro)
    VALUES ('CI','0000000','Consumidor Final','-','-',1,GETDATE());

PRINT 'OK: Clientes de prueba insertados.';
GO

-- ── 4.2 Pre-ventas de prueba (Tienda 1) ─────────────────────────────────────
DECLARE @IdCliente1 INT, @IdCliente2 INT, @IdCliente3 INT;
DECLARE @IdProducto1 INT, @IdProducto2 INT;
DECLARE @IdUsuarioRepos INT;

SELECT TOP 1 @IdCliente1 = IdCliente FROM dbo.CLIENTE WHERE NumeroDocumento = '1234567';
SELECT TOP 1 @IdCliente2 = IdCliente FROM dbo.CLIENTE WHERE NumeroDocumento = '2345678';
SELECT TOP 1 @IdCliente3 = IdCliente FROM dbo.CLIENTE WHERE NumeroDocumento = '80012345-1';

-- Tomar los primeros dos productos con stock en tienda 1
SELECT TOP 1 @IdProducto1 = IdProducto FROM dbo.PRODUCTO_TIENDA WHERE IdTienda=1 AND Stock>0 AND Activo=1 ORDER BY IdProducto;
SELECT TOP 1 @IdProducto2 = IdProducto FROM dbo.PRODUCTO_TIENDA WHERE IdTienda=1 AND Stock>0 AND Activo=1 AND IdProducto<>ISNULL(@IdProducto1,0) ORDER BY IdProducto;

SELECT TOP 1 @IdUsuarioRepos = IdUsuario FROM dbo.USUARIO WHERE IdRol=7 AND IdTienda=2 AND Activo=1; -- Federico
IF @IdUsuarioRepos IS NULL
    SELECT TOP 1 @IdUsuarioRepos = IdUsuario FROM dbo.USUARIO WHERE IdTienda=1 AND Activo=1;

-- Pre-venta 1: pendiente para hoy (cliente asignado)
IF @IdProducto1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ORDEN_VENTA WHERE NumeroOV='OV-00000001')
BEGIN
    DECLARE @PrecioP1 DECIMAL(18,2);
        SELECT TOP 1 @PrecioP1 =
        CEILING(pt.PrecioUnidadCompra
                * (1.0 + p.IvaPorcentaje / 100.0)
                * (1.0 + ISNULL(c.PorcentajeGanancia, 20) / 100.0))
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdProducto = @IdProducto1 AND pt.IdTienda = 1;

    INSERT INTO dbo.ORDEN_VENTA
        (NumeroOV,IdTienda,IdCliente,IdUsuarioRegistro,TotalEstimado,IVA10,IVA5,Exento0,
         Estado,Observacion,FechaVencimiento,Activo)
    VALUES
        ('OV-00000001',1,@IdCliente1,@IdUsuarioRepos,
         @PrecioP1 * 2 * 1.10,
         @PrecioP1 * 2 * 10.0/110.0, 0, 0,
         'Pendiente','Cliente solicitó presupuesto para compra de equipos',
         CAST(GETDATE() AS DATE), 1);

    DECLARE @IdOV1 INT = SCOPE_IDENTITY();
    INSERT INTO dbo.DETALLE_ORDEN_VENTA (IdOrdenVenta,IdProducto,Cantidad,PrecioUnidad,IvaPorcentaje,TotalLinea,TotalLineaIva)
    VALUES (@IdOV1, @IdProducto1, 2, @PrecioP1, 10, @PrecioP1*2, @PrecioP1*2*1.10);
    PRINT 'OK: Pre-venta OV-00000001 creada.';
END

-- Pre-venta 2: pendiente (empresa, dos productos)
IF @IdProducto1 IS NOT NULL AND @IdProducto2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ORDEN_VENTA WHERE NumeroOV='OV-00000002')
BEGIN
    DECLARE @PrecioP1b DECIMAL(18,2), @PrecioP2 DECIMAL(18,2);
    SELECT TOP 1 @PrecioP1b =
        CEILING(pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje/100.0) * (1.0 + ISNULL(c.PorcentajeGanancia,20)/100.0))
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdProducto = @IdProducto1 AND pt.IdTienda = 1;

    SELECT TOP 1 @PrecioP2  =
        CEILING(pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje/100.0) * (1.0 + ISNULL(c.PorcentajeGanancia,20)/100.0))
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
    LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
    WHERE pt.IdProducto = @IdProducto2 AND pt.IdTienda = 1;

    IF ISNULL(@PrecioP1b, 0) = 0 SET @PrecioP1b = 100000;
    IF ISNULL(@PrecioP2,  0) = 0 SET @PrecioP2  = 150000;

    DECLARE @TotalOV2 DECIMAL(18,2) = @PrecioP1b*1.10 + @PrecioP2*1.10;

    INSERT INTO dbo.ORDEN_VENTA
        (NumeroOV,IdTienda,IdCliente,IdUsuarioRegistro,TotalEstimado,IVA10,IVA5,Exento0,
         Estado,Observacion,FechaVencimiento,Activo)
    VALUES
        ('OV-00000002',1,@IdCliente3,@IdUsuarioRepos,
         @TotalOV2, @TotalOV2*10.0/110.0, 0, 0,
         'Pendiente','Compra corporativa — aprobación pendiente del área financiera',
         DATEADD(DAY,3,CAST(GETDATE() AS DATE)), 1);

    DECLARE @IdOV2 INT = SCOPE_IDENTITY();
    INSERT INTO dbo.DETALLE_ORDEN_VENTA (IdOrdenVenta,IdProducto,Cantidad,PrecioUnidad,IvaPorcentaje,TotalLinea,TotalLineaIva)
    VALUES (@IdOV2,@IdProducto1,1,@PrecioP1b,10,@PrecioP1b,@PrecioP1b*1.10);
    INSERT INTO dbo.DETALLE_ORDEN_VENTA (IdOrdenVenta,IdProducto,Cantidad,PrecioUnidad,IvaPorcentaje,TotalLinea,TotalLineaIva)
    VALUES (@IdOV2,@IdProducto2,1,@PrecioP2,10,@PrecioP2,@PrecioP2*1.10);
    PRINT 'OK: Pre-venta OV-00000002 creada.';
END
GO

-- ── 4.3 Venta directa de demo ya facturada ───────────────────────────────────
DECLARE @IdClienteDemo INT, @IdProd1 INT, @PrecioDemo DECIMAL(18,2);
DECLARE @IdUserCajero INT;

SELECT TOP 1 @IdClienteDemo = IdCliente FROM dbo.CLIENTE WHERE NumeroDocumento='2345678';
SELECT TOP 1 @IdProd1 = IdProducto FROM dbo.PRODUCTO_TIENDA WHERE IdTienda=1 AND Stock>0 AND Activo=1 ORDER BY IdProducto;
SELECT TOP 1 @PrecioDemo =
    CEILING(pt.PrecioUnidadCompra * (1.0 + p.IvaPorcentaje/100.0) * (1.0 + ISNULL(c.PorcentajeGanancia,20)/100.0))
FROM dbo.PRODUCTO_TIENDA pt
INNER JOIN dbo.PRODUCTO  p ON p.IdProducto  = pt.IdProducto
LEFT  JOIN dbo.CATEGORIA c ON c.IdCategoria = p.IdCategoria
WHERE pt.IdProducto = @IdProd1 AND pt.IdTienda = 1;
IF ISNULL(@PrecioDemo, 0) = 0 SET @PrecioDemo = 100000;
SELECT TOP 1 @IdUserCajero = IdUsuario FROM dbo.USUARIO WHERE IdRol=4 AND IdTienda=1 AND Activo=1; -- Juan

IF @IdProd1 IS NOT NULL AND @IdUserCajero IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.VENTA WHERE NumeroFactura='001-001-0000001')
BEGIN
    DECLARE @TotalDemo DECIMAL(18,2) = @PrecioDemo * 1.10;
    DECLARE @IVA10Demo DECIMAL(18,2) = @PrecioDemo * 10.0/110.0;

    -- Actualizar secuencia DATOS_TRIBUTARIOS
    UPDATE dbo.DATOS_TRIBUTARIOS SET SecuenciaActual = 1;

    INSERT INTO dbo.VENTA
        (Codigo,ValorCodigo,IdTienda,IdUsuario,IdCliente,TipoDocumento,
         TotalCosto,ImporteRecibido,ImporteCambio,Activo,FechaRegistro,
         NumeroFactura,NumeroTimbrado,VencimientoTimbrado,
         Estado,TipoFlujo,IdFormaCobro,IVA10,IVA5,Exento0)
    VALUES
        ('000001',1,1,@IdUserCajero,@IdClienteDemo,'Factura',
         @TotalDemo,@TotalDemo,0,1,GETDATE(),
         '001-001-0000001','12958745','2027-12-31',
         'Activa','Directa',1,@IVA10Demo,0,0);

    DECLARE @IdVentaDemo INT = SCOPE_IDENTITY();

    INSERT INTO dbo.DETALLE_VENTA (IdVenta,IdProducto,Cantidad,PrecioUnidad,ImporteTotal,Activo,FechaRegistro,IvaPorcentaje,MontoIva)
    VALUES (@IdVentaDemo,@IdProd1,1,@PrecioDemo,@TotalDemo,1,GETDATE(),10,@IVA10Demo);

    UPDATE dbo.PRODUCTO_TIENDA SET Stock = Stock - 1 WHERE IdProducto=@IdProd1 AND IdTienda=1;

    INSERT INTO dbo.COMPROBANTE_COBRO (NumeroCobro,IdVenta,IdTienda,IdUsuario,IdFormaCobro,MontoTotal,MontoRecibido,MontoCambio,Estado)
    VALUES ('CC-00000001',@IdVentaDemo,1,@IdUserCajero,1,@TotalDemo,@TotalDemo,0,'Cobrado');

    PRINT 'OK: Venta demo 001-001-0000001 creada con comprobante de cobro.';
END
GO

PRINT '';
PRINT '════════════════════════════════════════════════════════════';
PRINT 'Script 38c completado — Menú, permisos y datos de prueba OK.';
PRINT 'Ejecutar a continuación: Rebuild del proyecto C#';
PRINT '════════════════════════════════════════════════════════════';
GO
