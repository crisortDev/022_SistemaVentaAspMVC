-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 38: Cambios de tablas — Módulo de Ventas completo
-- ─────────────────────────────────────────────────────────────────────────────
-- Acciones:
--   1. ALTER TABLE VENTA         → Estado, TipoFlujo, IdOrdenVenta, IdFormaCobro,
--                                   Exento10, Exento5, Exento0, IVA10, IVA5,
--                                   MotivoAnulacion, FechaAnulacion, IdUsuarioAnula
--   2. ALTER TABLE DETALLE_VENTA → IvaPorcentaje, MontoIva
--   3. ALTER TABLE DATOS_TRIBUTARIOS → SecuenciaActual, Establecimiento, PuntoExpedicion
--   4. CREATE TABLE ORDEN_VENTA
--   5. CREATE TABLE DETALLE_ORDEN_VENTA
--   6. CREATE TABLE COMPROBANTE_COBRO
--   7. CREATE TABLE NOTA_CREDITO_VENTA
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. VENTA — agregar columnas
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'Estado')
    ALTER TABLE dbo.VENTA ADD Estado VARCHAR(20) NOT NULL DEFAULT 'Activa';
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'TipoFlujo')
    ALTER TABLE dbo.VENTA ADD TipoFlujo VARCHAR(20) NOT NULL DEFAULT 'Directa';
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IdOrdenVenta')
    ALTER TABLE dbo.VENTA ADD IdOrdenVenta INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IdFormaCobro')
    ALTER TABLE dbo.VENTA ADD IdFormaCobro INT NULL;
GO

-- IVA desglosado (Paraguay: 10%, 5%, exento)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'Exento10')
    ALTER TABLE dbo.VENTA ADD Exento10 DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'Exento5')
    ALTER TABLE dbo.VENTA ADD Exento5 DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'Exento0')
    ALTER TABLE dbo.VENTA ADD Exento0 DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IVA10')
    ALTER TABLE dbo.VENTA ADD IVA10 DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IVA5')
    ALTER TABLE dbo.VENTA ADD IVA5 DECIMAL(18,2) NOT NULL DEFAULT 0;
GO

-- Anulación
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'MotivoAnulacion')
    ALTER TABLE dbo.VENTA ADD MotivoAnulacion VARCHAR(500) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'FechaAnulacion')
    ALTER TABLE dbo.VENTA ADD FechaAnulacion DATETIME NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VENTA') AND name = 'IdUsuarioAnula')
    ALTER TABLE dbo.VENTA ADD IdUsuarioAnula INT NULL;
GO

PRINT 'OK: VENTA — columnas nuevas agregadas.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. DETALLE_VENTA — IVA por línea
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA') AND name = 'IvaPorcentaje')
    ALTER TABLE dbo.DETALLE_VENTA ADD IvaPorcentaje DECIMAL(5,2) NOT NULL DEFAULT 10;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DETALLE_VENTA') AND name = 'MontoIva')
    ALTER TABLE dbo.DETALLE_VENTA ADD MontoIva DECIMAL(18,2) NOT NULL DEFAULT 0;
GO

PRINT 'OK: DETALLE_VENTA — IvaPorcentaje y MontoIva agregados.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. DATOS_TRIBUTARIOS — campos para numeración correlativa formato SET
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DATOS_TRIBUTARIOS') AND name = 'SecuenciaActual')
    ALTER TABLE dbo.DATOS_TRIBUTARIOS ADD SecuenciaActual INT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DATOS_TRIBUTARIOS') AND name = 'Establecimiento')
    ALTER TABLE dbo.DATOS_TRIBUTARIOS ADD Establecimiento VARCHAR(3) NOT NULL DEFAULT '001';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.DATOS_TRIBUTARIOS') AND name = 'PuntoExpedicion')
    ALTER TABLE dbo.DATOS_TRIBUTARIOS ADD PuntoExpedicion VARCHAR(3) NOT NULL DEFAULT '001';
GO

-- Inicializar registro vigente si no existe
IF NOT EXISTS (SELECT 1 FROM dbo.DATOS_TRIBUTARIOS)
BEGIN
    INSERT INTO dbo.DATOS_TRIBUTARIOS (NumeroFactura, NumeroTimbrado, VencimientoTimbrado, SecuenciaActual, Establecimiento, PuntoExpedicion)
    VALUES ('001-001-0000000', 12958745, '2027-12-31', 0, '001', '001');
    PRINT 'OK: DATOS_TRIBUTARIOS — registro inicial insertado.';
END
ELSE
BEGIN
    -- Actualizar el registro existente con los nuevos campos si faltan
    UPDATE dbo.DATOS_TRIBUTARIOS
    SET NumeroTimbrado   = 12958745,
        VencimientoTimbrado = '2027-12-31',
        Establecimiento  = '001',
        PuntoExpedicion  = '001'
    WHERE Establecimiento IS NULL OR Establecimiento = '';
    PRINT 'OK: DATOS_TRIBUTARIOS — campos actualizados.';
END
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. ORDEN_VENTA (Pre-venta / Presupuesto)
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.ORDEN_VENTA') AND type = 'U')
BEGIN
    CREATE TABLE dbo.ORDEN_VENTA (
        IdOrdenVenta        INT IDENTITY(1,1) NOT NULL,
        NumeroOV            VARCHAR(20)       NOT NULL,
        IdTienda            INT               NOT NULL,
        IdCliente           INT               NULL,        -- puede no tener cliente al crear
        IdUsuarioRegistro   INT               NOT NULL,
        TotalEstimado       DECIMAL(18,2)     NOT NULL DEFAULT 0,
        IVA10               DECIMAL(18,2)     NOT NULL DEFAULT 0,
        IVA5                DECIMAL(18,2)     NOT NULL DEFAULT 0,
        Exento0             DECIMAL(18,2)     NOT NULL DEFAULT 0,
        Estado              VARCHAR(20)       NOT NULL DEFAULT 'Pendiente',
        Observacion         VARCHAR(500)      NULL,
        FechaRegistro       DATETIME          NOT NULL DEFAULT GETDATE(),
        FechaVencimiento    DATE              NULL,          -- cuando vence el presupuesto
        FechaFacturado      DATETIME          NULL,
        IdUsuarioFactura    INT               NULL,
        IdVenta             INT               NULL,          -- FK a VENTA cuando se convierte
        MotivoAnulacion     VARCHAR(500)      NULL,
        FechaAnulacion      DATETIME          NULL,
        Activo              BIT               NOT NULL DEFAULT 1,
        CONSTRAINT PK_ORDEN_VENTA PRIMARY KEY CLUSTERED (IdOrdenVenta ASC)
    );
    PRINT 'OK: ORDEN_VENTA creada.';
END
ELSE
    PRINT 'INFO: ORDEN_VENTA ya existe.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. DETALLE_ORDEN_VENTA
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.DETALLE_ORDEN_VENTA') AND type = 'U')
BEGIN
    CREATE TABLE dbo.DETALLE_ORDEN_VENTA (
        IdDetalleOV     INT IDENTITY(1,1) NOT NULL,
        IdOrdenVenta    INT               NOT NULL,
        IdProducto      INT               NOT NULL,
        Cantidad        INT               NOT NULL,
        PrecioUnidad    DECIMAL(18,2)     NOT NULL,
        IvaPorcentaje   DECIMAL(5,2)      NOT NULL DEFAULT 10,
        TotalLinea      DECIMAL(18,2)     NOT NULL,
        TotalLineaIva   DECIMAL(18,2)     NOT NULL,
        Activo          BIT               NOT NULL DEFAULT 1,
        FechaRegistro   DATETIME          NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_DETALLE_OV PRIMARY KEY CLUSTERED (IdDetalleOV ASC),
        CONSTRAINT FK_DOV_OV FOREIGN KEY (IdOrdenVenta) REFERENCES dbo.ORDEN_VENTA(IdOrdenVenta)
    );
    PRINT 'OK: DETALLE_ORDEN_VENTA creada.';
END
ELSE
    PRINT 'INFO: DETALLE_ORDEN_VENTA ya existe.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. COMPROBANTE_COBRO
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.COMPROBANTE_COBRO') AND type = 'U')
BEGIN
    CREATE TABLE dbo.COMPROBANTE_COBRO (
        IdComprobanteCobro  INT IDENTITY(1,1) NOT NULL,
        NumeroCobro         VARCHAR(20)       NOT NULL,
        IdVenta             INT               NOT NULL,
        IdTienda            INT               NOT NULL,
        IdUsuario           INT               NOT NULL,
        IdFormaCobro        INT               NOT NULL DEFAULT 1,
        MontoTotal          DECIMAL(18,2)     NOT NULL,
        MontoRecibido       DECIMAL(18,2)     NOT NULL,
        MontoCambio         DECIMAL(18,2)     NOT NULL DEFAULT 0,
        Estado              VARCHAR(20)       NOT NULL DEFAULT 'Cobrado',
        FechaRegistro       DATETIME          NOT NULL DEFAULT GETDATE(),
        Activo              BIT               NOT NULL DEFAULT 1,
        CONSTRAINT PK_COMPROBANTE_COBRO PRIMARY KEY CLUSTERED (IdComprobanteCobro ASC),
        CONSTRAINT FK_CC_VENTA  FOREIGN KEY (IdVenta)  REFERENCES dbo.VENTA(IdVenta),
        CONSTRAINT UQ_CC_Venta  UNIQUE (IdVenta)
    );
    PRINT 'OK: COMPROBANTE_COBRO creada.';
END
ELSE
    PRINT 'INFO: COMPROBANTE_COBRO ya existe.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. NOTA_CREDITO_VENTA
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.NOTA_CREDITO_VENTA') AND type = 'U')
BEGIN
    CREATE TABLE dbo.NOTA_CREDITO_VENTA (
        IdNCVenta           INT IDENTITY(1,1) NOT NULL,
        NumeroNCV           VARCHAR(20)       NULL,
        IdVenta             INT               NOT NULL,
        IdMotivoNC          INT               NOT NULL,
        Monto               DECIMAL(18,2)     NOT NULL,
        Estado              VARCHAR(20)       NOT NULL DEFAULT 'Pendiente',
        Observacion         VARCHAR(500)      NULL,
        IdUsuarioRegistro   INT               NOT NULL,
        FechaRegistro       DATETIME          NOT NULL DEFAULT GETDATE(),
        IdUsuarioAprueba    INT               NULL,
        FechaAprobacion     DATETIME          NULL,
        MotivoRechazo       VARCHAR(500)      NULL,
        Activo              BIT               NOT NULL DEFAULT 1,
        CONSTRAINT PK_NCV PRIMARY KEY CLUSTERED (IdNCVenta ASC),
        CONSTRAINT FK_NCV_VENTA FOREIGN KEY (IdVenta) REFERENCES dbo.VENTA(IdVenta),
        CONSTRAINT UQ_NCV_Venta UNIQUE (IdVenta)   -- una NC por venta
    );
    PRINT 'OK: NOTA_CREDITO_VENTA creada.';
END
ELSE
    PRINT 'INFO: NOTA_CREDITO_VENTA ya existe.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- FK opcionales (si no existen)
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_VENTA_ORDEN_VENTA')
    ALTER TABLE dbo.VENTA ADD CONSTRAINT FK_VENTA_ORDEN_VENTA
        FOREIGN KEY (IdOrdenVenta) REFERENCES dbo.ORDEN_VENTA(IdOrdenVenta);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_VENTA_FORMA_COBRO')
    ALTER TABLE dbo.VENTA ADD CONSTRAINT FK_VENTA_FORMA_COBRO
        FOREIGN KEY (IdFormaCobro) REFERENCES dbo.FORMA_COBRO(IdFormaCobro);
GO

-- Insertar formas de cobro si no existen
IF NOT EXISTS (SELECT 1 FROM dbo.FORMA_COBRO)
BEGIN
    INSERT INTO dbo.FORMA_COBRO (Descripcion) VALUES ('Efectivo');
    INSERT INTO dbo.FORMA_COBRO (Descripcion) VALUES ('Tarjeta de Débito');
    INSERT INTO dbo.FORMA_COBRO (Descripcion) VALUES ('Tarjeta de Crédito');
    INSERT INTO dbo.FORMA_COBRO (Descripcion) VALUES ('Transferencia');
    INSERT INTO dbo.FORMA_COBRO (Descripcion) VALUES ('QR / Billetera Digital');
    PRINT 'OK: FORMA_COBRO — datos insertados.';
END
GO

PRINT '';
PRINT '════════════════════════════════════════════════════════════';
PRINT 'Script 38 completado — Tablas módulo ventas listas.';
PRINT 'Ejecutar a continuación: 38b_StoredProcedures_Ventas.sql';
PRINT '════════════════════════════════════════════════════════════';
GO
