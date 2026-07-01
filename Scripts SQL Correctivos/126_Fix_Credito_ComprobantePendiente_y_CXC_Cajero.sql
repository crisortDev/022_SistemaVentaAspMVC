-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 126: Fix ventas a crédito + habilitar CXC para Cajero
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-04
--
-- PROBLEMA 1:
--   usp_FacturarDesdeOrdenVenta (script 125) para Crédito no creaba un registro
--   en COMPROBANTE_COBRO con Estado='Pendiente'. Sin ese registro, la factura a
--   crédito no aparece en "Cuentas por Cobrar" (usp_ObtenerCuentasPorCobrar
--   filtra por cc.Estado='Pendiente').
--
-- FIX: Para Crédito → crear COMPROBANTE_COBRO con Estado='Pendiente', MontoRecibido=0.
--      Cuando el cliente pague → usp_CobrarCuentaPendiente actualiza Estado='Cobrado'.
--
-- PROBLEMA 2:
--   Cajero (IdRol=4) necesita acceso activo al submenú "Cuentas por Cobrar".
--   Script 83 lo creó, pero puede estar Activo=0 o no existir.
--
-- FLUJO COMPLETO DE VENTA A CRÉDITO:
--   1. Cajero factura pre-venta → Crédito → Factura emitida + stock reducido
--   2. Se crea COMPROBANTE_COBRO Estado='Pendiente' → aparece en CXC
--   3. El cajero puede cerrar su caja sin que afecte los créditos pendientes
--      (usp_CerrarCaja excluye créditos del MontoSistema)
--   4. El cliente viene a pagar → Cajero abre "Cuentas por Cobrar" →
--      registra el cobro → COBRO_CXC Estado='Cobrado'
--   5. Los cobros CXC de este turno SÍ se suman al MontoSistema al cerrar caja
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Habilitar "Cuentas por Cobrar" para Cajero (IdRol=4) ─────────────────
DECLARE @IdSubMenuCXC INT;
SELECT  @IdSubMenuCXC = IdSubMenu
FROM    dbo.SUBMENU
WHERE   Controlador = 'ComprobanteCobro' AND Nombre = 'Cuentas por Cobrar';

IF @IdSubMenuCXC IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.PERMISOS WHERE IdRol = 4 AND IdSubMenu = @IdSubMenuCXC)
        UPDATE dbo.PERMISOS SET Activo = 1 WHERE IdRol = 4 AND IdSubMenu = @IdSubMenuCXC;
    ELSE
        INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
        VALUES (4, @IdSubMenuCXC, 1, GETDATE());

    PRINT 'OK: Cajero (IdRol=4) — Cuentas por Cobrar habilitado (Activo=1).';
END
ELSE
    PRINT 'WARN: Submenú Cuentas por Cobrar no encontrado. Verificar SUBMENU.';
GO

-- ─── 2. Reparar créditos ya facturados sin COMPROBANTE_COBRO pendiente ────────
-- Crea registros pendientes para facturas a crédito que no tienen comprobante.
DECLARE @Reparados INT = 0;

INSERT INTO dbo.COMPROBANTE_COBRO
    (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
     MontoTotal, MontoRecibido, MontoCambio, Estado, FechaRegistro)
SELECT
    'CC-' + RIGHT('00000000' + CAST(
        ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO),0)
        + ROW_NUMBER() OVER (ORDER BY v.IdVenta) AS VARCHAR), 8),
    v.IdVenta,
    v.IdTienda,
    v.IdUsuario,
    v.IdFormaCobro,
    v.TotalCosto,  -- MontoTotal = lo que debe el cliente
    0,             -- MontoRecibido = 0 (aún no pagó)
    0,             -- MontoCambio   = 0
    'Pendiente',
    v.FechaRegistro
FROM dbo.VENTA v
WHERE v.Condicion = 'Crédito'
  AND v.Estado    = 'Activa'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.COMPROBANTE_COBRO cc
      WHERE cc.IdVenta = v.IdVenta
  );

SET @Reparados = @@ROWCOUNT;
PRINT 'OK: ' + CAST(@Reparados AS VARCHAR) + ' factura(s) a crédito sin comprobante → registros pendientes creados.';
GO

-- ─── 3. usp_FacturarDesdeOrdenVenta — crear COMPROBANTE_COBRO Pendiente ───────
CREATE OR ALTER PROCEDURE [dbo].[usp_FacturarDesdeOrdenVenta]
    @IdOrdenVenta    INT,
    @IdUsuarioCajero INT,
    @IdCliente       INT          = NULL,
    @IdFormaCobro    INT,
    @ImporteRecibido DECIMAL(18,2),
    @IdCaja          INT          = NULL,
    @Condicion       VARCHAR(20)  = 'Contado',
    @PlazoCredito    INT          = NULL,
    @IdRolUsuario    INT          = 0,
    @IdVentaGenerada INT          OUTPUT,
    @NumeroFactura   VARCHAR(20)  OUTPUT,
    @Resultado       BIT          OUTPUT,
    @Mensaje         NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @IdTienda      INT,
                @IdClienteOV    INT,
                @IdUsuarioReg   INT,
                @Timbrado       VARCHAR(20),
                @VencTimbrado   DATE,
                @Codigo         VARCHAR(20),
                @ValorCodigo    INT,
                @TotalCosto     DECIMAL(18,2),
                @IVA10Total     DECIMAL(18,2),
                @IVA5Total      DECIMAL(18,2),
                @Exento0Total   DECIMAL(18,2),
                @ImporteCambio  DECIMAL(18,2),
                @FechaVenc      DATE;

        SELECT @IdTienda = IdTienda, @IdClienteOV = IdCliente, @IdUsuarioReg = IdUsuarioRegistro
        FROM   dbo.ORDEN_VENTA
        WHERE  IdOrdenVenta = @IdOrdenVenta;

        IF @IdTienda IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='Orden de venta no encontrada.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        -- ── CONTROL 1: caja abierta obligatoria ──────────────────────────────
        IF @IdCaja IS NULL OR @IdCaja = 0
           OR NOT EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdCaja = @IdCaja AND Estado = 'Abierta')
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Debe tener una caja ABIERTA para facturar. Abra una caja e intente de nuevo.';
            SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        -- ── CONTROL 2: segregación de funciones ──────────────────────────────
        IF @IdUsuarioReg = @IdUsuarioCajero AND @IdRolUsuario NOT IN (1, 14)
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='El usuario que cargó la pre-venta no puede facturarla (segregación de funciones). Debe facturar otro cajero o un administrador.';
            SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        DECLARE @IdClienteFinal INT = ISNULL(NULLIF(@IdCliente,0), @IdClienteOV);

        IF EXISTS (SELECT 1 FROM dbo.VENTA WHERE IdOrdenVenta = @IdOrdenVenta AND Estado = 'Activa')
        BEGIN
            SET @Resultado=0; SET @Mensaje='Esta orden ya fue facturada.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END

        SELECT @Timbrado = CAST(NumeroTimbrado AS VARCHAR), @VencTimbrado = VencimientoTimbrado
        FROM dbo.DATOS_TRIBUTARIOS;

        EXEC dbo.usp_GenerarNumeroFactura @NumeroFactura OUTPUT, @IdCaja;
        IF @NumeroFactura IS NULL
        BEGIN
            SET @Resultado=0; SET @Mensaje='El timbrado fiscal está vencido o no hay timbrado vigente.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
            ROLLBACK; RETURN;
        END
        SET @Codigo      = 'V-' + @NumeroFactura;
        SET @ValorCodigo = ISNULL((SELECT MAX(ValorCodigo) FROM dbo.VENTA), 0) + 1;

        SELECT
            @TotalCosto  = SUM(ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0)),
            @IVA10Total  = SUM(CASE WHEN d.IvaPorcentaje = 10 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0) ELSE 0 END),
            @IVA5Total   = SUM(CASE WHEN d.IvaPorcentaje = 5  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0,  0) ELSE 0 END),
            @Exento0Total= SUM(CASE WHEN d.IvaPorcentaje = 0  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0) ELSE 0 END)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- ── Importe y cambio según condición ─────────────────────────────────
        IF @Condicion = 'Crédito'
        BEGIN
            -- Crédito: el cliente paga después → no hay cobro inmediato
            SET @ImporteRecibido = 0;
            SET @ImporteCambio   = 0;
            -- Calcular fecha de vencimiento según plazo
            IF ISNULL(@PlazoCredito, 0) > 0
                SET @FechaVenc = CAST(DATEADD(DAY, @PlazoCredito, GETDATE()) AS DATE);
        END
        ELSE
        BEGIN
            -- Contado: validar que el importe cubra el total
            IF @ImporteRecibido < @TotalCosto
            BEGIN
                SET @Resultado=0; SET @Mensaje='Importe recibido insuficiente.'; SET @IdVentaGenerada=0; SET @NumeroFactura='';
                ROLLBACK; RETURN;
            END
            SET @ImporteCambio = @ImporteRecibido - @TotalCosto;
        END

        -- ── Insertar VENTA ────────────────────────────────────────────────────
        INSERT INTO dbo.VENTA
            (Codigo, ValorCodigo, IdTienda, IdUsuario, IdCliente, TipoDocumento,
             TotalCosto, ImporteRecibido, ImporteCambio, Activo, FechaRegistro,
             NumeroFactura, NumeroTimbrado, VencimientoTimbrado,
             Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
             IVA10, IVA5, Exento0, IdCaja,
             Condicion, PlazoCredito, FechaVencimientoCredito)
        VALUES
            (@Codigo, @ValorCodigo, @IdTienda, @IdUsuarioCajero, @IdClienteFinal, 'Factura',
             @TotalCosto, @ImporteRecibido, @ImporteCambio, 1, GETDATE(),
             @NumeroFactura, @Timbrado, @VencTimbrado,
             'Activa', 'PreVenta', @IdOrdenVenta, @IdFormaCobro,
             @IVA10Total, @IVA5Total, @Exento0Total, @IdCaja,
             @Condicion, @PlazoCredito, @FechaVenc);

        SET @IdVentaGenerada = SCOPE_IDENTITY();

        -- ── Insertar DETALLE_VENTA ────────────────────────────────────────────
        INSERT INTO dbo.DETALLE_VENTA
            (IdVenta, IdProducto, Cantidad, PrecioUnidad, ImporteTotal,
             Activo, FechaRegistro, IvaPorcentaje, MontoIva, PorcentajeDescuento)
        SELECT
            @IdVentaGenerada,
            d.IdProducto,
            d.Cantidad,
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0), 2),
            ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad, 0),
            1, GETDATE(), d.IvaPorcentaje,
            CASE WHEN d.IvaPorcentaje = 10 THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 10.0/110.0, 0)
                 WHEN d.IvaPorcentaje = 5  THEN ROUND(d.PrecioUnidad * (1.0 - ISNULL(d.PorcentajeDescuento,0)/100.0) * d.Cantidad * 5.0/105.0,  0)
                 ELSE 0 END,
            ISNULL(d.PorcentajeDescuento, 0)
        FROM dbo.DETALLE_ORDEN_VENTA d
        WHERE d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1;

        -- ── Descontar stock ───────────────────────────────────────────────────
        UPDATE pt
           SET pt.Stock = pt.Stock - d.Cantidad
        FROM   dbo.PRODUCTO_TIENDA pt
        INNER  JOIN dbo.DETALLE_ORDEN_VENTA d ON d.IdProducto = pt.IdProducto
        WHERE  d.IdOrdenVenta = @IdOrdenVenta AND d.Activo = 1 AND pt.IdTienda = @IdTienda;

        -- ── Crear COMPROBANTE_COBRO según condición ───────────────────────────
        DECLARE @NumCC       INT = ISNULL((SELECT MAX(IdComprobanteCobro) FROM dbo.COMPROBANTE_COBRO),0)+1;
        DECLARE @NumeroCobro VARCHAR(20) = 'CC-'+RIGHT('00000000'+CAST(@NumCC AS VARCHAR),8);

        IF @Condicion = 'Contado'
        BEGIN
            -- Cobro inmediato → Estado 'Cobrado'
            INSERT INTO dbo.COMPROBANTE_COBRO
                (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
                 MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES
                (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
                 @TotalCosto, @ImporteRecibido, @ImporteCambio, 'Cobrado');
        END
        ELSE
        BEGIN
            -- Crédito → Estado 'Pendiente' (aparece en Cuentas por Cobrar)
            -- MontoRecibido=0 porque el cliente paga después.
            -- Cuando pague, usp_CobrarCuentaPendiente actualiza este registro.
            INSERT INTO dbo.COMPROBANTE_COBRO
                (NumeroCobro, IdVenta, IdTienda, IdUsuario, IdFormaCobro,
                 MontoTotal, MontoRecibido, MontoCambio, Estado)
            VALUES
                (@NumeroCobro, @IdVentaGenerada, @IdTienda, @IdUsuarioCajero, @IdFormaCobro,
                 @TotalCosto, 0, 0, 'Pendiente');
        END

        UPDATE dbo.ORDEN_VENTA SET Estado = 'Facturada' WHERE IdOrdenVenta = @IdOrdenVenta;

        SET @Resultado = 1;
        SET @Mensaje   = 'Venta registrada correctamente. Factura N° ' + @NumeroFactura + '.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0;
        SET @Mensaje   = 'Error: ' + ERROR_MESSAGE();
        SET @IdVentaGenerada = 0;
        SET @NumeroFactura = '';
    END CATCH
END
GO
PRINT 'OK: usp_FacturarDesdeOrdenVenta — Crédito crea COMPROBANTE_COBRO Pendiente → aparece en CXC.';
GO

-- ─── Verificación ─────────────────────────────────────────────────────────────
SELECT
    r.Descripcion AS Rol,
    s.Nombre      AS Submenu,
    CASE p.Activo WHEN 1 THEN 'Habilitado' ELSE 'Bloqueado' END AS Estado
FROM dbo.PERMISOS p
INNER JOIN dbo.SUBMENU s ON s.IdSubMenu = p.IdSubMenu
INNER JOIN dbo.ROL     r ON r.IdRol     = p.IdRol
WHERE s.Controlador = 'ComprobanteCobro'
  AND s.Nombre      = 'Cuentas por Cobrar'
  AND p.IdRol IN (4, 7, 14)
ORDER BY r.Descripcion;

SELECT 'Facturas crédito sin comprobante (deberían ser 0)' AS Verificacion,
       COUNT(*) AS Cantidad
FROM   dbo.VENTA v
WHERE  v.Condicion = 'Crédito' AND v.Estado = 'Activa'
  AND  NOT EXISTS (SELECT 1 FROM dbo.COMPROBANTE_COBRO cc WHERE cc.IdVenta = v.IdVenta);

PRINT '════ Script 126 completado ════';
GO
