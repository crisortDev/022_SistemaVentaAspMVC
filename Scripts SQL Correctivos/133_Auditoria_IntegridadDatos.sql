-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 133: Auditoría de Integridad de Datos — Sistema de Ventas
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-11
--
-- Propósito: detectar registros huérfanos, cabeceras sin detalle,
--            detalles sin cabecera, totales inconsistentes, estados
--            inválidos y relaciones rotas en todos los módulos.
--
-- SOLO LECTURA — no modifica ningún dato.
-- Ejecutar sección por sección o todo junto; cada bloque imprime su título.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO
SET NOCOUNT ON;

-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: PRODUCTOS
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: PRODUCTOS ══════════════════════';

-- P-1: Productos sin categoría válida
PRINT '-- [P-1] Productos sin categoría válida';
SELECT p.IdProducto, p.Codigo, p.Nombre, p.IdCategoria
FROM   dbo.PRODUCTO p
WHERE  NOT EXISTS (SELECT 1 FROM dbo.CATEGORIA c WHERE c.IdCategoria = p.IdCategoria)
ORDER  BY p.IdProducto;

-- P-2: Productos sin precio de venta activo
PRINT '-- [P-2] Productos sin precio de venta activo';
SELECT p.IdProducto, p.Codigo, p.Nombre
FROM   dbo.PRODUCTO p
WHERE  NOT EXISTS (
    SELECT 1 FROM dbo.PRECIO_VENTA pv
    WHERE  pv.IdProducto = p.IdProducto AND pv.Activo = 1
)
AND p.Activo = 1
ORDER  BY p.IdProducto;

-- P-3: PRODUCTO_TIENDA con producto inexistente
PRINT '-- [P-3] PRODUCTO_TIENDA con producto inexistente';
SELECT pt.IdProductoTienda, pt.IdProducto, pt.IdTienda
FROM   dbo.PRODUCTO_TIENDA pt
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = pt.IdProducto)
ORDER  BY pt.IdProductoTienda;

-- P-4: PRODUCTO_TIENDA con tienda inexistente
PRINT '-- [P-4] PRODUCTO_TIENDA con tienda inexistente';
SELECT pt.IdProductoTienda, pt.IdProducto, pt.IdTienda
FROM   dbo.PRODUCTO_TIENDA pt
WHERE  NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = pt.IdTienda)
ORDER  BY pt.IdProductoTienda;

-- P-5: Stock negativo
PRINT '-- [P-5] Stock negativo en PRODUCTO_TIENDA';
SELECT pt.IdProductoTienda, p.Codigo, p.Nombre, t.Nombre AS Tienda, pt.Stock
FROM   dbo.PRODUCTO_TIENDA pt
JOIN   dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
JOIN   dbo.TIENDA   t ON t.IdTienda   = pt.IdTienda
WHERE  pt.Stock < 0
ORDER  BY pt.Stock;

-- P-6: Stock mayor que StockMaximo (si StockMaximo > 0)
PRINT '-- [P-6] Stock mayor que StockMaximo';
SELECT pt.IdProductoTienda, p.Codigo, p.Nombre, t.Nombre AS Tienda,
       pt.Stock, pt.StockMaximo
FROM   dbo.PRODUCTO_TIENDA pt
JOIN   dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
JOIN   dbo.TIENDA   t ON t.IdTienda   = pt.IdTienda
WHERE  pt.StockMaximo > 0 AND pt.Stock > pt.StockMaximo
ORDER  BY (pt.Stock - pt.StockMaximo) DESC;

-- P-7: StockMinimo mayor o igual que StockMaximo (configuración inválida)
PRINT '-- [P-7] StockMinimo >= StockMaximo (configuración inválida)';
SELECT pt.IdProductoTienda, p.Codigo, p.Nombre, t.Nombre AS Tienda,
       pt.StockMinimo, pt.StockMaximo
FROM   dbo.PRODUCTO_TIENDA pt
JOIN   dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
JOIN   dbo.TIENDA   t ON t.IdTienda   = pt.IdTienda
WHERE  pt.StockMaximo > 0 AND pt.StockMinimo >= pt.StockMaximo
ORDER  BY pt.IdProductoTienda;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: VENTAS
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: VENTAS ══════════════════════';

-- V-1: Ventas activas sin líneas de detalle
PRINT '-- [V-1] VENTA sin DETALLE_VENTA';
SELECT v.IdVenta, v.FechaRegistro, v.TotalCosto, v.Estado
FROM   dbo.VENTA v
WHERE  NOT EXISTS (SELECT 1 FROM dbo.DETALLE_VENTA dv WHERE dv.IdVenta = v.IdVenta)
  AND  v.Estado <> 'Anulada'
ORDER  BY v.IdVenta;

-- V-2: DETALLE_VENTA huérfano (sin venta padre)
PRINT '-- [V-2] DETALLE_VENTA sin VENTA padre';
SELECT dv.IdDetalleVenta, dv.IdVenta, dv.IdProducto, dv.Cantidad
FROM   dbo.DETALLE_VENTA dv
WHERE  NOT EXISTS (SELECT 1 FROM dbo.VENTA v WHERE v.IdVenta = dv.IdVenta)
ORDER  BY dv.IdVenta;

-- V-3: Total de venta != suma del detalle (diferencia > 1 guaraní, tolerancia de redondeo)
PRINT '-- [V-3] VENTA.TotalCosto no coincide con SUM(DETALLE_VENTA.ImporteTotal)';
SELECT v.IdVenta, v.FechaRegistro, v.TotalCosto AS TotalCabecera,
       SUM(dv.ImporteTotal) AS TotalDetalle,
       v.TotalCosto - SUM(dv.ImporteTotal) AS Diferencia
FROM   dbo.VENTA v
JOIN   dbo.DETALLE_VENTA dv ON dv.IdVenta = v.IdVenta
WHERE  v.Estado <> 'Anulada'
GROUP  BY v.IdVenta, v.FechaRegistro, v.TotalCosto
HAVING ABS(v.TotalCosto - SUM(dv.ImporteTotal)) > 1
ORDER  BY ABS(v.TotalCosto - SUM(dv.ImporteTotal)) DESC;

-- V-4: Ventas con IdOrdenVenta que no existe en ORDEN_VENTA
PRINT '-- [V-4] VENTA con IdOrdenVenta inválido';
SELECT v.IdVenta, v.FechaRegistro, v.IdOrdenVenta
FROM   dbo.VENTA v
WHERE  v.IdOrdenVenta IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.ORDEN_VENTA ov WHERE ov.IdOrdenVenta = v.IdOrdenVenta)
ORDER  BY v.IdVenta;

-- V-5: Ventas con estado inválido
PRINT '-- [V-5] VENTA con Estado fuera del dominio válido';
SELECT v.IdVenta, v.FechaRegistro, v.Estado
FROM   dbo.VENTA v
WHERE  v.Estado NOT IN ('Activa','Anulada','Credito')
ORDER  BY v.IdVenta;

-- V-6: ORDEN_VENTA sin líneas de detalle
PRINT '-- [V-6] ORDEN_VENTA sin DETALLE_ORDEN_VENTA';
SELECT ov.IdOrdenVenta, ov.FechaRegistro, ov.Estado
FROM   dbo.ORDEN_VENTA ov
WHERE  NOT EXISTS (SELECT 1 FROM dbo.DETALLE_ORDEN_VENTA dov WHERE dov.IdOrdenVenta = ov.IdOrdenVenta)
  AND  ov.Estado <> 'Anulada'
ORDER  BY ov.IdOrdenVenta;

-- V-7: DETALLE_ORDEN_VENTA huérfano
PRINT '-- [V-7] DETALLE_ORDEN_VENTA sin ORDEN_VENTA padre';
SELECT dov.IdDetalleOV, dov.IdOrdenVenta, dov.IdProducto
FROM   dbo.DETALLE_ORDEN_VENTA dov
WHERE  NOT EXISTS (SELECT 1 FROM dbo.ORDEN_VENTA ov WHERE ov.IdOrdenVenta = dov.IdOrdenVenta)
ORDER  BY dov.IdOrdenVenta;

-- V-8: NOTA_CREDITO_VENTA sin venta padre
PRINT '-- [V-8] NOTA_CREDITO_VENTA sin VENTA padre';
SELECT ncv.IdNCVenta, ncv.IdVenta, ncv.Monto
FROM   dbo.NOTA_CREDITO_VENTA ncv
WHERE  NOT EXISTS (SELECT 1 FROM dbo.VENTA v WHERE v.IdVenta = ncv.IdVenta)
ORDER  BY ncv.IdVenta;

-- V-9: COMPROBANTE_COBRO sin venta padre
PRINT '-- [V-9] COMPROBANTE_COBRO sin VENTA padre';
SELECT cc.IdComprobanteCobro, cc.IdVenta
FROM   dbo.COMPROBANTE_COBRO cc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.VENTA v WHERE v.IdVenta = cc.IdVenta)
ORDER  BY cc.IdVenta;

-- V-10: Ventas con IVA desglosado inconsistente
PRINT '-- [V-10] VENTA con IVA desglosado inconsistente';
SELECT v.IdVenta, v.FechaRegistro, v.TotalCosto,
       v.Exento10, v.Exento5, v.Exento0,
       v.IVA10, v.IVA5,
       (v.Exento10 + v.Exento5 + v.Exento0 + v.IVA10 + v.IVA5) AS SumaPartes,
       v.TotalCosto - (v.Exento10 + v.Exento5 + v.Exento0 + v.IVA10 + v.IVA5) AS Diferencia
FROM   dbo.VENTA v
WHERE  v.Estado <> 'Anulada'
  AND  ABS(v.TotalCosto - (v.Exento10 + v.Exento5 + v.Exento0 + v.IVA10 + v.IVA5)) > 1
ORDER  BY ABS(v.TotalCosto - (v.Exento10 + v.Exento5 + v.Exento0 + v.IVA10 + v.IVA5)) DESC;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: COMPRAS / ÓRDENES DE COMPRA
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: COMPRAS ══════════════════════';

-- C-1: COMPRA sin líneas de detalle
PRINT '-- [C-1] COMPRA sin DETALLE_COMPRA';
SELECT c.IdCompra, c.FechaRegistro, c.Estado, c.TotalCosto
FROM   dbo.COMPRA c
WHERE  NOT EXISTS (SELECT 1 FROM dbo.DETALLE_COMPRA dc WHERE dc.IdCompra = c.IdCompra)
  AND  c.Estado <> 'Anulada'
ORDER  BY c.IdCompra;

-- C-2: DETALLE_COMPRA huérfano
PRINT '-- [C-2] DETALLE_COMPRA sin COMPRA padre';
SELECT dc.IdDetalleCompra, dc.IdCompra, dc.IdProducto, dc.Cantidad
FROM   dbo.DETALLE_COMPRA dc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = dc.IdCompra)
ORDER  BY dc.IdCompra;

-- C-3: OrdenCompra sin líneas de detalle
PRINT '-- [C-3] ORDEN_COMPRA sin DetalleOrdenCompra';
SELECT oc.IdOrdenCompra, oc.FechaRegistro, oc.Estado
FROM   dbo.OrdenCompra oc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.DetalleOrdenCompra doc WHERE doc.IdOrdenCompra = oc.IdOrdenCompra)
  AND  oc.Estado NOT IN ('Anulada','Rechazada')
  AND  ISNULL(oc.Activo, 1) = 1
ORDER  BY oc.IdOrdenCompra;

-- C-4: DetalleOrdenCompra huérfano
PRINT '-- [C-4] DetalleOrdenCompra sin OrdenCompra padre';
SELECT doc.IdDetalleOrdenCompra, doc.IdOrdenCompra, doc.IdProducto
FROM   dbo.DetalleOrdenCompra doc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.OrdenCompra oc WHERE oc.IdOrdenCompra = doc.IdOrdenCompra)
ORDER  BY doc.IdOrdenCompra;

-- C-5: NOTA_CREDITO sin compra padre
PRINT '-- [C-5] NOTA_CREDITO sin COMPRA padre';
SELECT nc.IdNC, nc.IdCompra, nc.Estado, nc.Monto
FROM   dbo.NOTA_CREDITO nc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = nc.IdCompra)
ORDER  BY nc.IdCompra;

-- C-6: COMPRA con estado inválido
PRINT '-- [C-6] COMPRA con Estado fuera del dominio válido';
SELECT c.IdCompra, c.FechaRegistro, c.Estado
FROM   dbo.COMPRA c
WHERE  c.Estado NOT IN ('Pendiente','Confirmada','Anulada')
ORDER  BY c.IdCompra;

-- C-7: OrdenCompra con estado inválido
PRINT '-- [C-7] OrdenCompra con Estado fuera del dominio válido';
SELECT oc.IdOrdenCompra, oc.FechaRegistro, oc.Estado
FROM   dbo.OrdenCompra oc
WHERE  oc.Estado NOT IN ('Pendiente','Aprobada','Rechazada','Facturada','Cerrada','Anulada')
  AND  ISNULL(oc.Activo, 1) = 1
ORDER  BY oc.IdOrdenCompra;

-- C-8: CompraOrdenCompra con vínculos rotos
PRINT '-- [C-8] CompraOrdenCompra con Compra o OrdenCompra inexistente';
SELECT coc.IdCompra, coc.IdOrdenCompra
FROM   dbo.CompraOrdenCompra coc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = coc.IdCompra)
    OR NOT EXISTS (SELECT 1 FROM dbo.OrdenCompra oc WHERE oc.IdOrdenCompra = coc.IdOrdenCompra)
ORDER  BY coc.IdCompra;

-- C-9: HISTORIAL_ESTADO_COMPRA huérfano
PRINT '-- [C-9] HISTORIAL_ESTADO_COMPRA sin COMPRA padre';
SELECT h.IdHistorial, h.IdCompra, h.EstadoNuevo, h.FechaTransicion
FROM   dbo.HISTORIAL_ESTADO_COMPRA h
WHERE  NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = h.IdCompra)
ORDER  BY h.IdCompra;

-- C-10: HISTORIAL_ESTADO_OC huérfano
PRINT '-- [C-10] HISTORIAL_ESTADO_OC sin OrdenCompra padre';
SELECT h.IdHistorial, h.IdOrdenCompra, h.EstadoNuevo, h.FechaTransicion
FROM   dbo.HISTORIAL_ESTADO_OC h
WHERE  NOT EXISTS (SELECT 1 FROM dbo.OrdenCompra oc WHERE oc.IdOrdenCompra = h.IdOrdenCompra)
ORDER  BY h.IdOrdenCompra;

-- C-11: COMPRA confirmada sin IdUsuarioConfirma
PRINT '-- [C-11] COMPRA Confirmada sin IdUsuarioConfirma (auditoría incompleta)';
SELECT c.IdCompra, c.FechaRegistro, c.Estado
FROM   dbo.COMPRA c
WHERE  c.Estado = 'Confirmada' AND c.IdUsuarioConfirma IS NULL
ORDER  BY c.IdCompra;

-- C-12: NOTA_CREDITO Pendiente con más de 30 días (morosa)
PRINT '-- [C-12] NOTA_CREDITO Pendiente con más de 30 días sin recibir (morosa)';
SELECT nc.IdNC, nc.IdCompra, nc.Monto, nc.FechaRegistro,
       DATEDIFF(DAY, nc.FechaRegistro, GETDATE()) AS DiasTranscurridos
FROM   dbo.NOTA_CREDITO nc
WHERE  nc.Estado = 'Pendiente'
  AND  DATEDIFF(DAY, nc.FechaRegistro, GETDATE()) > 30
ORDER  BY DiasTranscurridos DESC;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: INVENTARIO (Bajas, Traslados, Toma Física)
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: INVENTARIO ══════════════════════';

-- I-1: INVENTARIO (toma física) sin líneas de detalle
PRINT '-- [I-1] INVENTARIO sin DETALLE_INVENTARIO';
SELECT i.IdInventario, i.Numero, i.FechaRegistro, i.Estado
FROM   dbo.INVENTARIO i
WHERE  NOT EXISTS (SELECT 1 FROM dbo.DETALLE_INVENTARIO di WHERE di.IdInventario = i.IdInventario)
  AND  i.Estado <> 'Rechazado'
ORDER  BY i.IdInventario;

-- I-2: DETALLE_INVENTARIO huérfano
PRINT '-- [I-2] DETALLE_INVENTARIO sin INVENTARIO padre';
SELECT di.IdDetalleInventario, di.IdInventario, di.IdProducto
FROM   dbo.DETALLE_INVENTARIO di
WHERE  NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO inv WHERE inv.IdInventario = di.IdInventario)
ORDER  BY di.IdInventario;

-- I-3: DETALLE_INVENTARIO con producto inexistente
PRINT '-- [I-3] DETALLE_INVENTARIO con producto inexistente';
SELECT di.IdDetalleInventario, di.IdInventario, di.IdProducto
FROM   dbo.DETALLE_INVENTARIO di
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = di.IdProducto)
ORDER  BY di.IdProducto;

-- I-4: INVENTARIO con estado inválido
PRINT '-- [I-4] INVENTARIO con Estado inválido';
SELECT i.IdInventario, i.Numero, i.Estado
FROM   dbo.INVENTARIO i
WHERE  i.Estado NOT IN ('Pendiente','Aprobado','Rechazado')
ORDER  BY i.IdInventario;

-- I-5: INVENTARIO Aprobado sin IdUsuarioAprueba
PRINT '-- [I-5] INVENTARIO Aprobado sin IdUsuarioAprueba (auditoría incompleta)';
SELECT i.IdInventario, i.Numero, i.FechaRegistro, i.Estado
FROM   dbo.INVENTARIO i
WHERE  i.Estado = 'Aprobado' AND i.IdUsuarioAprueba IS NULL
ORDER  BY i.IdInventario;

-- I-6: HISTORIAL_MOVIMIENTO (bajas) con producto inexistente
PRINT '-- [I-6] HISTORIAL_MOVIMIENTO (Baja) con producto inexistente';
SELECT h.IdHistorial, h.idProducto, h.Estado, h.EstadoAprobacion
FROM   dbo.HISTORIAL_MOVIMIENTO h
WHERE  h.Estado = 'Baja'
  AND  NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = h.idProducto)
ORDER  BY h.IdHistorial;

-- I-7: HISTORIAL_MOVIMIENTO (bajas) con tienda inexistente
PRINT '-- [I-7] HISTORIAL_MOVIMIENTO (Baja) con tienda inexistente';
SELECT h.IdHistorial, h.IdTienda, h.EstadoAprobacion
FROM   dbo.HISTORIAL_MOVIMIENTO h
WHERE  h.Estado = 'Baja'
  AND  h.IdTienda IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = h.IdTienda)
ORDER  BY h.IdHistorial;

-- I-8: Bajas Aprobadas sin IdUsuarioAprueba
PRINT '-- [I-8] Baja Aprobada sin IdUsuarioAprueba (auditoría incompleta)';
SELECT h.IdHistorial, h.idProducto, h.Cantidad, h.FechaMovimiento
FROM   dbo.HISTORIAL_MOVIMIENTO h
WHERE  h.Estado = 'Baja' AND h.EstadoAprobacion = 'Aprobada'
  AND  h.IdUsuarioAprueba IS NULL
ORDER  BY h.IdHistorial;

-- I-9: Bajas con EstadoAprobacion inválido
PRINT '-- [I-9] Baja con EstadoAprobacion inválido';
SELECT h.IdHistorial, h.EstadoAprobacion
FROM   dbo.HISTORIAL_MOVIMIENTO h
WHERE  h.Estado = 'Baja'
  AND  h.EstadoAprobacion NOT IN ('Pendiente','Aprobada','Rechazada')
ORDER  BY h.IdHistorial;

-- I-10: TRASLADO con producto inexistente
PRINT '-- [I-10] TRASLADO con producto inexistente';
SELECT t.IdTraslado, t.IdProducto, t.IdTiendaOrigen, t.IdTiendaDestino
FROM   dbo.TRASLADO t
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = t.IdProducto)
ORDER  BY t.IdTraslado;

-- I-11: TRASLADO con tienda origen o destino inexistente
PRINT '-- [I-11] TRASLADO con tienda inexistente';
SELECT t.IdTraslado, t.IdTiendaOrigen, t.IdTiendaDestino, t.EstadoAprobacion
FROM   dbo.TRASLADO t
WHERE  NOT EXISTS (SELECT 1 FROM dbo.TIENDA ti WHERE ti.IdTienda = t.IdTiendaOrigen)
    OR NOT EXISTS (SELECT 1 FROM dbo.TIENDA ti WHERE ti.IdTienda = t.IdTiendaDestino)
ORDER  BY t.IdTraslado;

-- I-12: TRASLADO con EstadoAprobacion inválido
PRINT '-- [I-12] TRASLADO con EstadoAprobacion inválido';
SELECT t.IdTraslado, t.EstadoAprobacion, t.FechaTraslado
FROM   dbo.TRASLADO t
WHERE  t.EstadoAprobacion NOT IN ('Pendiente','Aprobado','Rechazado')
ORDER  BY t.IdTraslado;

-- I-13: TRASLADO Aprobado sin IdUsuarioAprueba
PRINT '-- [I-13] TRASLADO Aprobado sin IdUsuarioAprueba (auditoría incompleta)';
SELECT t.IdTraslado, t.IdProducto, t.Cantidad, t.FechaTraslado
FROM   dbo.TRASLADO t
WHERE  t.EstadoAprobacion = 'Aprobado' AND t.IdUsuarioAprueba IS NULL
  AND  t.FechaAprobacion IS NOT NULL
ORDER  BY t.IdTraslado;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: CAJA
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: CAJA ══════════════════════';

-- K-1: CAJA sin PUNTO_CAJA válido
PRINT '-- [K-1] CAJA sin PUNTO_CAJA válido';
SELECT c.IdCaja, c.IdUsuario, c.FechaApertura, c.IdPuntoCaja
FROM   dbo.CAJA c
WHERE  c.IdPuntoCaja IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.PUNTO_CAJA pc WHERE pc.IdPuntoCaja = c.IdPuntoCaja)
ORDER  BY c.IdCaja;

-- K-2: CAJA sin usuario válido
PRINT '-- [K-2] CAJA sin USUARIO válido';
SELECT c.IdCaja, c.IdUsuario, c.FechaApertura
FROM   dbo.CAJA c
WHERE  NOT EXISTS (SELECT 1 FROM dbo.USUARIO u WHERE u.IdUsuario = c.IdUsuario)
ORDER  BY c.IdCaja;

-- K-3: CAJA sin tienda válida
PRINT '-- [K-3] CAJA sin TIENDA válida';
SELECT c.IdCaja, c.IdTienda, c.FechaApertura
FROM   dbo.CAJA c
WHERE  NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = c.IdTienda)
ORDER  BY c.IdCaja;

-- K-4: PUNTO_CAJA sin tienda válida
PRINT '-- [K-4] PUNTO_CAJA sin TIENDA válida';
SELECT pc.IdPuntoCaja, pc.IdTienda, pc.Codigo
FROM   dbo.PUNTO_CAJA pc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = pc.IdTienda)
ORDER  BY pc.IdPuntoCaja;

-- K-5: COBRO_CXC con comprobante o forma de cobro inexistente
PRINT '-- [K-5] COBRO_CXC con ComprobanteCobro inexistente';
SELECT cc.IdCobroCxc, cc.IdCompCobro, cc.IdFormaCobro
FROM   dbo.COBRO_CXC cc
WHERE  cc.IdCompCobro IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.COMPROBANTE_COBRO cp WHERE cp.IdComprobanteCobro = cc.IdCompCobro)
ORDER  BY cc.IdCobroCxc;

-- K-6: VENTA sin CAJA cuando debería tenerla (TipoFlujo Directa activa)
PRINT '-- [K-6] VENTA activa con IdCaja NULL (posible venta sin caja asociada)';
SELECT v.IdVenta, v.FechaRegistro, v.TotalCosto, v.TipoFlujo, v.IdCaja
FROM   dbo.VENTA v
WHERE  v.IdCaja IS NULL
  AND  v.Estado = 'Activa'
  AND  v.TipoFlujo = 'Directa'
ORDER  BY v.IdVenta;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: USUARIOS Y PERMISOS
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: USUARIOS / PERMISOS ══════════════════════';

-- U-1: USUARIO sin ROL válido
PRINT '-- [U-1] USUARIO sin ROL válido';
SELECT u.IdUsuario, u.Nombres, u.Apellidos, u.IdRol
FROM   dbo.USUARIO u
WHERE  NOT EXISTS (SELECT 1 FROM dbo.ROL r WHERE r.IdRol = u.IdRol)
ORDER  BY u.IdUsuario;

-- U-2: USUARIO sin TIENDA válida (cuando tiene IdTienda asignado)
PRINT '-- [U-2] USUARIO con IdTienda inválido';
SELECT u.IdUsuario, u.Nombres, u.Apellidos, u.IdTienda
FROM   dbo.USUARIO u
WHERE  u.IdTienda IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = u.IdTienda)
ORDER  BY u.IdUsuario;

-- U-3: PERMISOS con SubMenu inexistente
PRINT '-- [U-3] PERMISOS con SubMenu inexistente';
SELECT p.IdPermisos, p.IdRol, p.IdSubMenu, p.Activo
FROM   dbo.PERMISOS p
WHERE  NOT EXISTS (SELECT 1 FROM dbo.SUBMENU s WHERE s.IdSubMenu = p.IdSubMenu)
ORDER  BY p.IdSubMenu;

-- U-4: PERMISOS con ROL inexistente
PRINT '-- [U-4] PERMISOS con ROL inexistente';
SELECT p.IdPermisos, p.IdRol, p.IdSubMenu
FROM   dbo.PERMISOS p
WHERE  NOT EXISTS (SELECT 1 FROM dbo.ROL r WHERE r.IdRol = p.IdRol)
ORDER  BY p.IdRol;

-- U-5: SUBMENU con MENU padre inexistente
PRINT '-- [U-5] SUBMENU con MENU padre inexistente';
SELECT s.IdSubMenu, s.Nombre, s.IdMenu
FROM   dbo.SUBMENU s
WHERE  s.IdMenu IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.MENU m WHERE m.IdMenu = s.IdMenu)
ORDER  BY s.IdSubMenu;

-- U-6: Roles activos sin ningún permiso asignado
PRINT '-- [U-6] ROL sin ningún permiso activo';
SELECT r.IdRol, r.Descripcion
FROM   dbo.ROL r
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = r.IdRol AND p.Activo = 1)
  AND  ISNULL(r.Activo, 1) = 1
ORDER  BY r.IdRol;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  MÓDULO: CLIENTES Y PROVEEDORES
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ MÓDULO: CLIENTES / PROVEEDORES ══════════════════════';

-- CP-1: VENTA con cliente inexistente (cuando tiene IdCliente)
PRINT '-- [CP-1] VENTA con IdCliente inválido';
SELECT v.IdVenta, v.FechaRegistro, v.IdCliente
FROM   dbo.VENTA v
WHERE  v.IdCliente IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.CLIENTE c WHERE c.IdCliente = v.IdCliente)
ORDER  BY v.IdVenta;

-- CP-2: COMPRA con proveedor inexistente
PRINT '-- [CP-2] COMPRA con IdProveedor inválido';
SELECT c.IdCompra, c.FechaRegistro, c.IdProveedor
FROM   dbo.COMPRA c
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PROVEEDOR p WHERE p.IdProveedor = c.IdProveedor)
ORDER  BY c.IdCompra;

-- CP-3: OrdenCompra con proveedor inexistente
PRINT '-- [CP-3] OrdenCompra con IdProveedor inválido';
SELECT oc.IdOrdenCompra, oc.FechaRegistro, oc.IdProveedor
FROM   dbo.OrdenCompra oc
WHERE  NOT EXISTS (SELECT 1 FROM dbo.PROVEEDOR p WHERE p.IdProveedor = oc.IdProveedor)
  AND  ISNULL(oc.Activo, 1) = 1
ORDER  BY oc.IdOrdenCompra;


-- ════════════════════════════════════════════════════════════════════════════════
-- ██  RESUMEN EJECUTIVO
-- ════════════════════════════════════════════════════════════════════════════════
PRINT ''; PRINT '══════════════════════ RESUMEN EJECUTIVO ══════════════════════';

SELECT 'P-1 Productos sin categoría'                         AS Verificacion, COUNT(*) AS CantidadProblemas FROM dbo.PRODUCTO p WHERE NOT EXISTS (SELECT 1 FROM dbo.CATEGORIA c WHERE c.IdCategoria = p.IdCategoria)
UNION ALL SELECT 'P-2 Productos sin precio activo',          COUNT(*) FROM dbo.PRODUCTO p WHERE NOT EXISTS (SELECT 1 FROM dbo.PRECIO_VENTA pv WHERE pv.IdProducto = p.IdProducto AND pv.Activo = 1) AND p.Activo = 1
UNION ALL SELECT 'P-3 PRODUCTO_TIENDA producto inválido',    COUNT(*) FROM dbo.PRODUCTO_TIENDA pt WHERE NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = pt.IdProducto)
UNION ALL SELECT 'P-4 PRODUCTO_TIENDA tienda inválida',      COUNT(*) FROM dbo.PRODUCTO_TIENDA pt WHERE NOT EXISTS (SELECT 1 FROM dbo.TIENDA t WHERE t.IdTienda = pt.IdTienda)
UNION ALL SELECT 'P-5 Stock negativo',                       COUNT(*) FROM dbo.PRODUCTO_TIENDA WHERE Stock < 0
UNION ALL SELECT 'P-6 Stock > StockMaximo',                  COUNT(*) FROM dbo.PRODUCTO_TIENDA WHERE StockMaximo > 0 AND Stock > StockMaximo
UNION ALL SELECT 'P-7 StockMin >= StockMax',                 COUNT(*) FROM dbo.PRODUCTO_TIENDA WHERE StockMaximo > 0 AND StockMinimo >= StockMaximo
UNION ALL SELECT 'V-1 VENTA sin detalle',                    COUNT(*) FROM dbo.VENTA v WHERE NOT EXISTS (SELECT 1 FROM dbo.DETALLE_VENTA dv WHERE dv.IdVenta = v.IdVenta) AND v.Estado <> 'Anulada'
UNION ALL SELECT 'V-2 DETALLE_VENTA huérfano',               COUNT(*) FROM dbo.DETALLE_VENTA dv WHERE NOT EXISTS (SELECT 1 FROM dbo.VENTA v WHERE v.IdVenta = dv.IdVenta)
UNION ALL SELECT 'V-3 TotalCosto != suma detalle',           COUNT(*) FROM (SELECT v.IdVenta FROM dbo.VENTA v JOIN dbo.DETALLE_VENTA dv ON dv.IdVenta = v.IdVenta WHERE v.Estado <> 'Anulada' GROUP BY v.IdVenta, v.TotalCosto HAVING ABS(v.TotalCosto - SUM(dv.ImporteTotal)) > 1) x
UNION ALL SELECT 'V-6 ORDEN_VENTA sin detalle',              COUNT(*) FROM dbo.ORDEN_VENTA ov WHERE NOT EXISTS (SELECT 1 FROM dbo.DETALLE_ORDEN_VENTA dov WHERE dov.IdOrdenVenta = ov.IdOrdenVenta) AND ov.Estado <> 'Anulada'
UNION ALL SELECT 'C-1 COMPRA sin detalle',                   COUNT(*) FROM dbo.COMPRA c WHERE NOT EXISTS (SELECT 1 FROM dbo.DETALLE_COMPRA dc WHERE dc.IdCompra = c.IdCompra) AND c.Estado <> 'Anulada'
UNION ALL SELECT 'C-2 DETALLE_COMPRA huérfano',              COUNT(*) FROM dbo.DETALLE_COMPRA dc WHERE NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = dc.IdCompra)
UNION ALL SELECT 'C-3 OrdenCompra sin detalle',              COUNT(*) FROM dbo.OrdenCompra oc WHERE NOT EXISTS (SELECT 1 FROM dbo.DetalleOrdenCompra doc WHERE doc.IdOrdenCompra = oc.IdOrdenCompra) AND oc.Estado NOT IN ('Anulada','Rechazada') AND ISNULL(oc.Activo,1)=1
UNION ALL SELECT 'C-5 NOTA_CREDITO huérfana',                COUNT(*) FROM dbo.NOTA_CREDITO nc WHERE NOT EXISTS (SELECT 1 FROM dbo.COMPRA c WHERE c.IdCompra = nc.IdCompra)
UNION ALL SELECT 'C-12 NC morosa (+30 días)',                 COUNT(*) FROM dbo.NOTA_CREDITO WHERE Estado = 'Pendiente' AND DATEDIFF(DAY, FechaRegistro, GETDATE()) > 30
UNION ALL SELECT 'I-1 INVENTARIO sin detalle',               COUNT(*) FROM dbo.INVENTARIO i WHERE NOT EXISTS (SELECT 1 FROM dbo.DETALLE_INVENTARIO di WHERE di.IdInventario = i.IdInventario) AND i.Estado <> 'Rechazado'
UNION ALL SELECT 'I-2 DETALLE_INVENTARIO huérfano',          COUNT(*) FROM dbo.DETALLE_INVENTARIO di WHERE NOT EXISTS (SELECT 1 FROM dbo.INVENTARIO inv WHERE inv.IdInventario = di.IdInventario)
UNION ALL SELECT 'I-6 Baja con producto inválido',           COUNT(*) FROM dbo.HISTORIAL_MOVIMIENTO h WHERE h.Estado = 'Baja' AND NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = h.idProducto)
UNION ALL SELECT 'I-10 TRASLADO producto inválido',          COUNT(*) FROM dbo.TRASLADO t WHERE NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.IdProducto = t.IdProducto)
UNION ALL SELECT 'I-11 TRASLADO tienda inválida',            COUNT(*) FROM dbo.TRASLADO t WHERE NOT EXISTS (SELECT 1 FROM dbo.TIENDA ti WHERE ti.IdTienda = t.IdTiendaOrigen) OR NOT EXISTS (SELECT 1 FROM dbo.TIENDA ti WHERE ti.IdTienda = t.IdTiendaDestino)
UNION ALL SELECT 'K-1 CAJA sin PUNTO_CAJA',                  COUNT(*) FROM dbo.CAJA c WHERE c.IdPuntoCaja IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.PUNTO_CAJA pc WHERE pc.IdPuntoCaja = c.IdPuntoCaja)
UNION ALL SELECT 'U-1 USUARIO sin ROL',                      COUNT(*) FROM dbo.USUARIO u WHERE NOT EXISTS (SELECT 1 FROM dbo.ROL r WHERE r.IdRol = u.IdRol)
UNION ALL SELECT 'U-3 PERMISOS con SubMenu inválido',        COUNT(*) FROM dbo.PERMISOS p WHERE NOT EXISTS (SELECT 1 FROM dbo.SUBMENU s WHERE s.IdSubMenu = p.IdSubMenu)
UNION ALL SELECT 'CP-1 VENTA con Cliente inválido',          COUNT(*) FROM dbo.VENTA v WHERE v.IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.CLIENTE c WHERE c.IdCliente = v.IdCliente)
UNION ALL SELECT 'CP-2 COMPRA con Proveedor inválido',       COUNT(*) FROM dbo.COMPRA c WHERE NOT EXISTS (SELECT 1 FROM dbo.PROVEEDOR p WHERE p.IdProveedor = c.IdProveedor)
ORDER BY 1;

PRINT ''; PRINT '════ Script 133 (Auditoría Integridad) completado ════';
GO
