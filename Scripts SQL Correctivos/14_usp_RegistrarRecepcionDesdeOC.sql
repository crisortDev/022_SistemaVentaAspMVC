-- ============================================================
--  NUEVO SP: usp_RegistrarRecepcionDesdeOC
--
--  Reemplaza el flujo "Registrar Compra + Recepción" en uno solo.
--  A partir de una OC aprobada crea el registro COMPRA,
--  DETALLE_COMPRA y registra inmediatamente las cantidades
--  recibidas. Si alguna línea recibió menos de lo ordenado,
--  queda con EstadoLinea = 'NC'; si recibió igual, 'Aceptada'.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[usp_RegistrarRecepcionDesdeOC]
    @IdOrdenCompra         INT,
    @IdUsuario             INT,
    @NumeroFactura         NVARCHAR(50),
    @NumeroTimbrado        NVARCHAR(50),
    @FechaVencTimbrado     DATE,
    @FechaFactura          DATE,
    @FechaEntrega          DATETIME,
    @Detalle               XML,           -- <DETALLE><ITEM><IdDetalleOC>n</IdDetalleOC><CantidadRecibida>n</CantidadRecibida></ITEM></DETALLE>
    @IdCompra              INT           OUTPUT,
    @Resultado             BIT           OUTPUT,
    @Mensaje               NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT YMD;

    BEGIN TRY
        BEGIN TRAN;

        -- ── 1. Validar OC ─────────────────────────────────────────────────
        DECLARE @IdProveedor INT, @IdTienda INT, @EstadoOC VARCHAR(20);

        SELECT @IdProveedor = IdProveedor,
               @IdTienda    = IdTienda,
               @EstadoOC    = Estado
          FROM dbo.OrdenCompra
         WHERE IdOrdenCompra = @IdOrdenCompra;

        IF @IdProveedor IS NULL
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'Orden de Compra no encontrada.';
            ROLLBACK; RETURN;
        END

        IF @EstadoOC <> 'Aprobada'
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'Solo se puede recepcionar una OC en estado Aprobada. Estado actual: ' + @EstadoOC;
            ROLLBACK; RETURN;
        END

        -- ── 2. Validar fechas ──────────────────────────────────────────────
        IF @FechaEntrega < CAST(@FechaFactura AS DATETIME)
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'La Fecha de Entrega no puede ser anterior a la Fecha de Factura.';
            ROLLBACK; RETURN;
        END

        -- ── 3. Leer líneas del XML ─────────────────────────────────────────
        DECLARE @Lineas TABLE (
            IdDetalleOC      INT,
            CantidadRecibida INT
        );

        INSERT INTO @Lineas (IdDetalleOC, CantidadRecibida)
        SELECT T.c.value('(IdDetalleOC)[1]',      'INT'),
               T.c.value('(CantidadRecibida)[1]', 'INT')
          FROM @Detalle.nodes('//ITEM') AS T(c);

        IF (SELECT COUNT(*) FROM @Lineas) = 0
        BEGIN
            SET @Resultado = 0; SET @IdCompra = 0;
            SET @Mensaje = 'El XML no contiene líneas.';
            ROLLBACK; RETURN;
        END

        -- ── 4. Calcular TotalCosto desde cantidades recibidas × precio OC ──
        DECLARE @TotalCosto DECIMAL(18,2);

        SELECT @TotalCosto = SUM(l.CantidadRecibida * doc.PrecioUnitario)
          FROM @Lineas l
         INNER JOIN dbo.DetalleOrdenCompra doc ON doc.IdDetalleOrdenCompra = l.IdDetalleOC;

        -- ── 5. Crear COMPRA ────────────────────────────────────────────────
        INSERT INTO dbo.COMPRA (
            IdUsuario, IdProveedor, IdTienda, TotalCosto, TipoComprobante,
            Activo, FechaRegistro, NumeroFactura, NumeroTimbrado,
            VencimientoTimbrado, FechaFactura, FechaEntrega, EstadoRecepcion)
        VALUES (
            @IdUsuario, @IdProveedor, @IdTienda, @TotalCosto, 'Compra',
            1, GETDATE(),
            ISNULL(@NumeroFactura,  ''),
            ISNULL(@NumeroTimbrado, ''),
            @FechaVencTimbrado, @FechaFactura, @FechaEntrega,
            'EnRecepcion');

        SET @IdCompra = SCOPE_IDENTITY();

        -- ── 6. Crear DETALLE_COMPRA con cantidades recibidas ───────────────
        INSERT INTO dbo.DETALLE_COMPRA (
            IdCompra, IdProducto, Cantidad, CantidadRecibida,
            PrecioUnitarioCompra, TotalCosto, Activo, FechaRegistro, EstadoLinea)
        SELECT
            @IdCompra,
            doc.IdProducto,
            doc.Cantidad,                       -- Cantidad ordenada en OC
            l.CantidadRecibida,                 -- Lo que llegó físicamente
            doc.PrecioUnitario,
            l.CantidadRecibida * doc.PrecioUnitario,
            1,
            GETDATE(),
            CASE
                WHEN l.CantidadRecibida >= doc.Cantidad THEN 'Aceptada'
                WHEN l.CantidadRecibida  > 0            THEN 'NC'
                ELSE 'Rechazada'
            END
          FROM @Lineas l
         INNER JOIN dbo.DetalleOrdenCompra doc ON doc.IdDetalleOrdenCompra = l.IdDetalleOC;

        -- ── 7. Vincular Compra con OC ──────────────────────────────────────
        INSERT INTO dbo.CompraOrdenCompra (IdCompra, IdOrdenCompra, FechaVinculacion)
        VALUES (@IdCompra, @IdOrdenCompra, GETDATE());

        -- ── 8. Marcar OC como Facturada ────────────────────────────────────
        UPDATE dbo.OrdenCompra
           SET Estado = 'Facturada'
         WHERE IdOrdenCompra = @IdOrdenCompra;

        COMMIT;
        SET @Resultado = 1;
        SET @Mensaje   = 'Recepción registrada correctamente. Compra ID: ' + CAST(@IdCompra AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @IdCompra  = 0;
        SET @Resultado = 0;
        SET @Mensaje   = ERROR_MESSAGE();
    END CATCH
END
GO
