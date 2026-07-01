-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 118: Una caja abierta por usuario + operaciones estrictas por IdCaja
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-03
--
-- A) usp_AbrirCaja: un usuario NO puede tener dos cajas abiertas a la vez
--    (vale para todos, incluso SuperAdmin). Debe cerrar la actual primero.
-- B) usp_ObtenerOperacionesCaja: filtra SOLO por v.IdCaja = @IdCaja.
--    Se elimina el fallback por fecha que hacía aparecer la misma venta en
--    dos cajas con turnos solapados.
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- A. usp_AbrirCaja — valida: caja física libre + usuario sin otra caja abierta
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_AbrirCaja
    @IdTienda       INT,
    @IdUsuario      INT,
    @MontoApertura  DECIMAL(18,2),
    @IdPuntoCaja    INT,
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT,
    @IdCaja         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @PtoExp VARCHAR(3), @CodCaja VARCHAR(20), @EstadoPC VARCHAR(20), @TiendaPC INT;
        SELECT @PtoExp = PuntoExpedicion, @CodCaja = Codigo,
               @EstadoPC = EstadoOperativo, @TiendaPC = IdTienda
        FROM dbo.PUNTO_CAJA WHERE IdPuntoCaja = @IdPuntoCaja;

        IF @PtoExp IS NULL
        BEGIN SET @Resultado=0; SET @Mensaje='La caja seleccionada no existe.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        IF @TiendaPC <> @IdTienda
        BEGIN SET @Resultado=0; SET @Mensaje='La caja no pertenece a esta sucursal.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        IF @EstadoPC <> 'Activo'
        BEGIN SET @Resultado=0; SET @Mensaje='La caja está inactiva. Elija otra.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        -- ── CONTROL 1: la caja física no debe estar ya abierta ────────────────
        IF EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdPuntoCaja = @IdPuntoCaja AND Estado = 'Abierta')
        BEGIN SET @Resultado=0; SET @Mensaje='Esta caja ya está abierta. Elija otra o ciérrela primero.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        -- ── CONTROL 2: el usuario no debe tener OTRA caja abierta ──────────────
        IF EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdUsuario = @IdUsuario AND Estado = 'Abierta')
        BEGIN
            SET @Resultado=0;
            SET @Mensaje='Ya tiene una caja abierta. Debe cerrarla antes de abrir otra.';
            SET @IdCaja=0; ROLLBACK; RETURN;
        END

        IF @MontoApertura < 0
        BEGIN SET @Resultado=0; SET @Mensaje='El monto de apertura no puede ser negativo.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        INSERT INTO dbo.CAJA
            (IdTienda, IdUsuario, MontoApertura, Estado, IdPuntoCaja, PuntoExpedicion, CodigoCaja)
        VALUES
            (@IdTienda, @IdUsuario, @MontoApertura, 'Abierta', @IdPuntoCaja, @PtoExp, @CodCaja);

        SET @IdCaja    = SCOPE_IDENTITY();
        SET @Resultado = 1;
        SET @Mensaje   = 'Caja ' + @CodCaja + ' (Punto ' + @PtoExp + ') abierta correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado=0; SET @IdCaja=0; SET @Mensaje='Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO
PRINT 'OK: usp_AbrirCaja — un usuario solo puede tener una caja abierta.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- B. usp_ObtenerOperacionesCaja — SOLO por IdCaja (sin fallback por fecha)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerOperacionesCaja
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: detalle operación por operación (solo ventas de ESTA caja)
    SELECT
        v.IdVenta,
        v.NumeroFactura,
        CONVERT(VARCHAR(19), v.FechaRegistro, 120)              AS FechaRegistro,
        ISNULL(c.Nombre, 'Consumidor Final')                    AS NombreCliente,
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))   AS FormaCobro,
        v.TotalCosto                                            AS Monto,
        ISNULL(cc.MontoRecibido, 0)                             AS MontoRecibido,
        ISNULL(cc.MontoCambio,   0)                             AS MontoCambio,
        u.Nombres + ' ' + u.Apellidos                           AS NombreCajero,
        v.Estado,
        ISNULL(v.Condicion, 'Contado')                          AS Condicion
    FROM   dbo.VENTA             v
    INNER  JOIN dbo.USUARIO      u  ON u.IdUsuario    = v.IdUsuario
    LEFT   JOIN dbo.CLIENTE      c  ON c.IdCliente    = v.IdCliente
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro = cc.IdFormaCobro
    WHERE  v.IdCaja = @IdCaja
      AND  v.Estado IN ('Activa', 'Anulada')
    ORDER  BY v.FechaRegistro;

    -- RS2: resumen por forma de cobro (solo ventas de ESTA caja)
    SELECT
        ISNULL(fc.Nombre, ISNULL(fc.Descripcion, 'Efectivo'))   AS FormaCobro,
        COUNT(v.IdVenta)  AS Cantidad,
        SUM(v.TotalCosto) AS TotalMonto
    FROM   dbo.VENTA             v
    LEFT   JOIN dbo.COMPROBANTE_COBRO cc ON cc.IdVenta    = v.IdVenta
    LEFT   JOIN dbo.FORMA_COBRO  fc ON fc.IdFormaCobro    = cc.IdFormaCobro
    WHERE  v.IdCaja = @IdCaja
      AND  v.Estado = 'Activa'
    GROUP  BY fc.Nombre, fc.Descripcion
    ORDER  BY TotalMonto DESC;
END
GO
PRINT 'OK: usp_ObtenerOperacionesCaja — filtra solo por IdCaja (sin duplicados).';
GO

PRINT '════ Script 118 completado ════';
GO
