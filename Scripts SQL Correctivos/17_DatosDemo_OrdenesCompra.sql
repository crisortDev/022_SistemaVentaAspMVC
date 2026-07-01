-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 17 (v2): Datos de Demo — Órdenes de Compra en estado Pendiente
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-06
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── Mostrar datos disponibles para referencia ─────────────────────────────────
PRINT '━━━ Datos disponibles en la BD ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
SELECT TOP 5 IdProveedor, RazonSocial FROM dbo.PROVEEDOR WHERE Activo = 1 ORDER BY IdProveedor;
SELECT TOP 3 IdTienda,    Nombre       FROM dbo.TIENDA     WHERE Activo = 1 ORDER BY IdTienda;
SELECT TOP 6 IdUsuario,   Nombres + ' ' + Apellidos AS NombreCompleto, IdRol
  FROM dbo.USUARIO WHERE Activo = 1 ORDER BY IdRol, IdUsuario;
SELECT TOP 6 IdProducto,  Codigo, Nombre FROM dbo.PRODUCTO WHERE Activo = 1 ORDER BY IdProducto;
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- INSERTAR 4 ÓRDENES DE COMPRA
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''
PRINT '━━━ Insertando Órdenes de Compra ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

DECLARE
    @IdProv1   INT,
    @IdProv2   INT,
    @IdTienda  INT,
    @IdUsrOper INT,
    @IdProd1   INT,
    @IdProd2   INT,
    @IdProd3   INT,
    @NumBase   INT,
    @IdOC      INT;

-- ── Capturar IDs reales de la BD ──────────────────────────────────────────────
SELECT TOP 1 @IdProv1 = IdProveedor
  FROM dbo.PROVEEDOR WHERE Activo = 1 ORDER BY IdProveedor;

SELECT TOP 1 @IdProv2 = IdProveedor
  FROM dbo.PROVEEDOR WHERE Activo = 1 AND IdProveedor <> ISNULL(@IdProv1,0) ORDER BY IdProveedor;
IF @IdProv2 IS NULL SET @IdProv2 = @IdProv1;

SELECT TOP 1 @IdTienda = IdTienda
  FROM dbo.TIENDA WHERE Activo = 1 ORDER BY IdTienda;

-- Preferimos un usuario que NO sea supervisor/admin para el registro
SELECT TOP 1 @IdUsrOper = IdUsuario
  FROM dbo.USUARIO WHERE Activo = 1 AND IdRol NOT IN (1,11,14) ORDER BY IdUsuario;
IF @IdUsrOper IS NULL
    SELECT TOP 1 @IdUsrOper = IdUsuario FROM dbo.USUARIO WHERE Activo = 1 ORDER BY IdUsuario;

-- Tres productos distintos
SELECT TOP 1 @IdProd1 = IdProducto FROM dbo.PRODUCTO WHERE Activo = 1 ORDER BY IdProducto;
SELECT TOP 1 @IdProd2 = IdProducto FROM dbo.PRODUCTO
  WHERE Activo = 1 AND IdProducto <> ISNULL(@IdProd1,0) ORDER BY IdProducto;
SELECT TOP 1 @IdProd3 = IdProducto FROM dbo.PRODUCTO
  WHERE Activo = 1 AND IdProducto NOT IN (ISNULL(@IdProd1,0), ISNULL(@IdProd2,0)) ORDER BY IdProducto;
IF @IdProd2 IS NULL SET @IdProd2 = @IdProd1;
IF @IdProd3 IS NULL SET @IdProd3 = @IdProd1;

-- Número OC base (evita colisiones con OC ya existentes)
SELECT @NumBase = ISNULL(MAX(IdOrdenCompra), 0) + 1 FROM dbo.OrdenCompra;

PRINT '  Proveedor 1  : ' + CAST(ISNULL(@IdProv1,  0) AS VARCHAR);
PRINT '  Proveedor 2  : ' + CAST(ISNULL(@IdProv2,  0) AS VARCHAR);
PRINT '  Tienda       : ' + CAST(ISNULL(@IdTienda, 0) AS VARCHAR);
PRINT '  Usr Operativo: ' + CAST(ISNULL(@IdUsrOper,0) AS VARCHAR);
PRINT '  Producto 1   : ' + CAST(ISNULL(@IdProd1,  0) AS VARCHAR);
PRINT '  Producto 2   : ' + CAST(ISNULL(@IdProd2,  0) AS VARCHAR);
PRINT '  Producto 3   : ' + CAST(ISNULL(@IdProd3,  0) AS VARCHAR);

-- ─────────────────────────────────────────────────────────────────────────────
-- OC #1 — Flujo completo: Aprobar → Recepción → Confirmar
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO dbo.OrdenCompra
    (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
     FechaOrden, FechaEntregaEstimada, Observacion,
     TotalEstimado, TotalEstimadoIva,
     Estado, MotivoRechazo, Activo, FechaRegistro)
VALUES
    ('OC-' + RIGHT('0000' + CAST(@NumBase AS VARCHAR), 4),
     @IdProv1, @IdTienda, @IdUsrOper, NULL,
     GETDATE(), DATEADD(DAY, 7, GETDATE()),
     'Demo: flujo completo — Aprobar → Recepción → Confirmar',
     750000, 75000,
     'Pendiente', NULL, 1, GETDATE());
SET @IdOC = SCOPE_IDENTITY();

INSERT INTO dbo.DetalleOrdenCompra
    (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
     PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
     Activo, FechaRegistro)
VALUES
    (@IdOC, @IdProd1, 10, 0, 50000, 10, 500000, 50000, 1, GETDATE()),
    (@IdOC, @IdProd2,  5, 0, 50000, 10, 250000, 25000, 1, GETDATE());

PRINT '  OC #1 creada  ID=' + CAST(@IdOC AS VARCHAR) + '  → Aprobar → Recepción → Confirmar';

-- ─────────────────────────────────────────────────────────────────────────────
-- OC #2 — Flujo de Rechazo
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO dbo.OrdenCompra
    (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
     FechaOrden, FechaEntregaEstimada, Observacion,
     TotalEstimado, TotalEstimadoIva,
     Estado, MotivoRechazo, Activo, FechaRegistro)
VALUES
    ('OC-' + RIGHT('0000' + CAST(@NumBase + 1 AS VARCHAR), 4),
     @IdProv1, @IdTienda, @IdUsrOper, NULL,
     GETDATE(), DATEADD(DAY, 5, GETDATE()),
     'Demo: probar flujo de RECHAZO',
     240000, 24000,
     'Pendiente', NULL, 1, GETDATE());
SET @IdOC = SCOPE_IDENTITY();

INSERT INTO dbo.DetalleOrdenCompra
    (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
     PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
     Activo, FechaRegistro)
VALUES
    (@IdOC, @IdProd3, 3, 0, 80000, 10, 240000, 24000, 1, GETDATE());

PRINT '  OC #2 creada  ID=' + CAST(@IdOC AS VARCHAR) + '  → Probar RECHAZO';

-- ─────────────────────────────────────────────────────────────────────────────
-- OC #3 — Flujo de Anulación
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO dbo.OrdenCompra
    (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
     FechaOrden, FechaEntregaEstimada, Observacion,
     TotalEstimado, TotalEstimadoIva,
     Estado, MotivoRechazo, Activo, FechaRegistro)
VALUES
    ('OC-' + RIGHT('0000' + CAST(@NumBase + 2 AS VARCHAR), 4),
     @IdProv2, @IdTienda, @IdUsrOper, NULL,
     GETDATE(), DATEADD(DAY, 3, GETDATE()),
     'Demo: probar flujo de ANULACIÓN',
     420000, 42000,
     'Pendiente', NULL, 1, GETDATE());
SET @IdOC = SCOPE_IDENTITY();

INSERT INTO dbo.DetalleOrdenCompra
    (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
     PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
     Activo, FechaRegistro)
VALUES
    (@IdOC, @IdProd1, 4, 0, 50000, 10, 200000, 20000, 1, GETDATE()),
    (@IdOC, @IdProd2, 2, 0, 50000, 10, 100000, 10000, 1, GETDATE()),
    (@IdOC, @IdProd3, 1, 0, 80000, 10, 120000, 12000, 1, GETDATE());

PRINT '  OC #3 creada  ID=' + CAST(@IdOC AS VARCHAR) + '  → Probar ANULACIÓN';

-- ─────────────────────────────────────────────────────────────────────────────
-- OC #4 — Extra: segundo proveedor / recepción con diferencia (NC)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO dbo.OrdenCompra
    (NumeroOrden, IdProveedor, IdTienda, IdUsuarioRegistro, IdUsuarioAprobador,
     FechaOrden, FechaEntregaEstimada, Observacion,
     TotalEstimado, TotalEstimadoIva,
     Estado, MotivoRechazo, Activo, FechaRegistro)
VALUES
    ('OC-' + RIGHT('0000' + CAST(@NumBase + 3 AS VARCHAR), 4),
     @IdProv2, @IdTienda, @IdUsrOper, NULL,
     GETDATE(), DATEADD(DAY, 14, GETDATE()),
     'Demo: recepción con diferencia → genera Nota de Crédito',
     400000, 40000,
     'Pendiente', NULL, 1, GETDATE());
SET @IdOC = SCOPE_IDENTITY();

INSERT INTO dbo.DetalleOrdenCompra
    (IdOrdenCompra, IdProducto, Cantidad, CantidadFacturada,
     PrecioUnitario, IvaPorcentaje, TotalLinea, TotalLineaIva,
     Activo, FechaRegistro)
VALUES
    (@IdOC, @IdProd2, 8, 0, 50000, 10, 400000, 40000, 1, GETDATE());

PRINT '  OC #4 creada  ID=' + CAST(@IdOC AS VARCHAR) + '  → Aprobar → Recepción parcial → NC';

-- ── Resultado final ───────────────────────────────────────────────────────────
PRINT ''
PRINT '━━━ Verificación ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
SELECT
    oc.IdOrdenCompra,
    oc.NumeroOrden,
    p.RazonSocial  AS Proveedor,
    t.Nombre       AS Tienda,
    u.Nombres + ' ' + u.Apellidos AS UsuarioRegistro,
    CONVERT(VARCHAR, oc.FechaOrden, 103)           AS FechaOrden,
    CONVERT(VARCHAR, oc.FechaEntregaEstimada, 103) AS FechaEntrega,
    oc.TotalEstimado,
    oc.Estado,
    COUNT(d.IdDetalleOrdenCompra) AS Lineas
FROM dbo.OrdenCompra oc
JOIN dbo.PROVEEDOR   p ON p.IdProveedor = oc.IdProveedor
JOIN dbo.TIENDA      t ON t.IdTienda    = oc.IdTienda
JOIN dbo.USUARIO     u ON u.IdUsuario   = oc.IdUsuarioRegistro
LEFT JOIN dbo.DetalleOrdenCompra d ON d.IdOrdenCompra = oc.IdOrdenCompra
WHERE CAST(oc.FechaRegistro AS DATE) = CAST(GETDATE() AS DATE)
  AND oc.Estado = 'Pendiente'
GROUP BY oc.IdOrdenCompra, oc.NumeroOrden, p.RazonSocial,
         t.Nombre, u.Nombres, u.Apellidos,
         oc.FechaOrden, oc.FechaEntregaEstimada,
         oc.TotalEstimado, oc.Estado
ORDER BY oc.IdOrdenCompra;
GO

PRINT ''
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT 'SCRIPT 17 COMPLETADO — 4 OC creadas en estado Pendiente'
PRINT '════════════════════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'Flujos sugeridos:'
PRINT '  OC #1  Aprobar → Recepcion → Revision → Confirmar'
PRINT '  OC #2  Rechazar (con motivo tipificado)'
PRINT '  OC #3  Anular directamente'
PRINT '  OC #4  Aprobar → Recepcion parcial → Nota de Credito'
PRINT ''
PRINT 'RECORDAR: el que registra la factura NO puede ser el que la confirma (O&M)'
