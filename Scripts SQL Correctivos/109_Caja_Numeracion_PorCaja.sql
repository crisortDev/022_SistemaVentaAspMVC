-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 109: Caja — ETAPA 2 (numeración por caja + abrir/cerrar + comprobantes)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31  ·  Depende del script 108.
--
-- Cubre:
--   #7  Abrir caja seleccionando el PUNTO_CAJA disponible
--   #8/#9 Numeración EEE-PPP-NNNNNNN con el Punto de Expedición y secuencia de la caja
--   #10 Monto de apertura puede ser 0
--   #11 Datos para comprobante de cierre (operaciones de la sesión)
--   #12 La sesión guarda CodigoCaja y PuntoExpedicion (para el comprobante)
--
-- ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. usp_GenerarNumeroFactura — ahora numera por CAJA (punto de expedición propio)
--    @IdCaja opcional: si viene, usa el PuntoExpedicion y la secuencia de esa caja.
--    Si no viene (NULL), cae al comportamiento global de DATOS_TRIBUTARIOS (compat).
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_GenerarNumeroFactura]
    @NumeroFactura VARCHAR(20) OUTPUT,
    @IdCaja        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Estab VARCHAR(3), @Punto VARCHAR(3), @Nueva INT, @IdPuntoCaja INT;

    -- Establecimiento y validación de timbrado salen de DATOS_TRIBUTARIOS (del local)
    SELECT TOP 1 @Estab = Establecimiento FROM dbo.DATOS_TRIBUTARIOS;

    IF EXISTS (SELECT 1 FROM dbo.DATOS_TRIBUTARIOS WHERE VencimientoTimbrado < CAST(GETDATE() AS DATE))
    BEGIN
        SET @NumeroFactura = NULL;   -- timbrado vencido
        RETURN;
    END

    -- ¿Tenemos caja? → numeración por punto de expedición de la caja
    IF @IdCaja IS NOT NULL
        SELECT @IdPuntoCaja = IdPuntoCaja FROM dbo.CAJA WHERE IdCaja = @IdCaja;

    IF @IdPuntoCaja IS NOT NULL
    BEGIN
        UPDATE dbo.PUNTO_CAJA
            SET SecuenciaActual = SecuenciaActual + 1
        WHERE IdPuntoCaja = @IdPuntoCaja;

        SELECT @Nueva = SecuenciaActual, @Punto = PuntoExpedicion
        FROM dbo.PUNTO_CAJA WHERE IdPuntoCaja = @IdPuntoCaja;
    END
    ELSE
    BEGIN
        -- Compatibilidad: numeración global (DATOS_TRIBUTARIOS)
        UPDATE dbo.DATOS_TRIBUTARIOS SET SecuenciaActual = SecuenciaActual + 1;
        SELECT @Nueva = SecuenciaActual, @Punto = PuntoExpedicion FROM dbo.DATOS_TRIBUTARIOS;
    END

    SET @NumeroFactura = @Estab + '-' + @Punto + '-' + RIGHT('0000000' + CAST(@Nueva AS VARCHAR), 7);
END
GO
PRINT 'OK: usp_GenerarNumeroFactura — numera por caja cuando recibe @IdCaja.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. usp_AbrirCaja — elegir PUNTO_CAJA, hereda código/punto, permite monto 0
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_AbrirCaja
    @IdTienda       INT,
    @IdUsuario      INT,
    @MontoApertura  DECIMAL(18,2),
    @IdPuntoCaja    INT,                      -- #7  caja física elegida
    @Resultado      BIT           OUTPUT,
    @Mensaje        NVARCHAR(300) OUTPUT,
    @IdCaja         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- El punto de caja debe existir, ser de la tienda y estar Activo
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

        -- No permitir dos sesiones abiertas sobre la MISMA caja física
        IF EXISTS (SELECT 1 FROM dbo.CAJA WHERE IdPuntoCaja = @IdPuntoCaja AND Estado = 'Abierta')
        BEGIN SET @Resultado=0; SET @Mensaje='Esta caja ya está abierta. Ciérrela primero.'; SET @IdCaja=0; ROLLBACK; RETURN; END

        -- #10  El monto de apertura puede ser 0 (solo no negativo)
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
PRINT 'OK: usp_AbrirCaja — selección de caja, hereda punto/código, permite monto 0.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. usp_ObtenerCajasDisponibles — para el combo "seleccionar caja al abrir" (#7)
--    Lista cajas Activas de la tienda que NO tengan una sesión abierta.
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerCajasDisponibles
    @IdTienda INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pc.IdPuntoCaja,
        pc.Codigo,
        pc.Nombre,
        pc.PuntoExpedicion,
        t.Nombre AS NombreTienda
    FROM dbo.PUNTO_CAJA pc
    INNER JOIN dbo.TIENDA t ON t.IdTienda = pc.IdTienda
    WHERE pc.IdTienda = @IdTienda
      AND pc.EstadoOperativo = 'Activo'
      AND NOT EXISTS (SELECT 1 FROM dbo.CAJA c
                      WHERE c.IdPuntoCaja = pc.IdPuntoCaja AND c.Estado = 'Abierta')
    ORDER BY pc.PuntoExpedicion;
END
GO
PRINT 'OK: usp_ObtenerCajasDisponibles creado.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. usp_ObtenerComprobanteCierre — datos del cierre + operaciones de la sesión (#11)
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerComprobanteCierre
    @IdCaja INT
AS
BEGIN
    SET NOCOUNT ON;

    -- RS1: cabecera del cierre
    SELECT
        c.IdCaja, c.CodigoCaja, c.PuntoExpedicion,
        t.Nombre                                   AS NombreTienda,
        ua.Nombres + ' ' + ua.Apellidos            AS UsuarioApertura,
        uc.Nombres + ' ' + uc.Apellidos            AS UsuarioCierre,
        FORMAT(c.FechaApertura, 'dd/MM/yyyy HH:mm') AS FechaApertura,
        FORMAT(c.FechaCierre,   'dd/MM/yyyy HH:mm') AS FechaCierre,
        c.MontoApertura, c.MontoSistema, c.MontoContado, c.Diferencia,
        c.Estado, ISNULL(c.Observacion,'')          AS Observacion
    FROM dbo.CAJA c
    INNER JOIN dbo.TIENDA  t  ON t.IdTienda  = c.IdTienda
    INNER JOIN dbo.USUARIO ua ON ua.IdUsuario = c.IdUsuario
    LEFT  JOIN dbo.USUARIO uc ON uc.IdUsuario = c.IdUsuarioCierre
    WHERE c.IdCaja = @IdCaja;

    -- RS2: operaciones (ventas contado de la sesión)
    SELECT
        v.Codigo                                   AS Comprobante,
        v.NumeroFactura,
        FORMAT(v.FechaRegistro, 'dd/MM/yyyy HH:mm') AS Fecha,
        v.TotalCosto                               AS Monto,
        ISNULL(fc.Nombre, 'Efectivo')              AS FormaCobro
    FROM dbo.VENTA v
    LEFT JOIN dbo.FORMA_COBRO fc ON fc.IdFormaCobro = v.IdFormaCobro
    WHERE v.IdCaja = @IdCaja
      AND v.Estado = 'Activa'
    ORDER BY v.FechaRegistro;
END
GO
PRINT 'OK: usp_ObtenerComprobanteCierre creado.';
GO

PRINT '════ Script 109 (Etapa 2 Caja) completado ════';
GO
