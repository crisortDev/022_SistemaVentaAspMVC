-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 108: Caja con Punto de Expedición DNIT — ETAPA 1 (estructura + datos)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Requisitos cubiertos (módulo Caja):
--   #5  Código de caja           → PUNTO_CAJA.Codigo
--   #6  Estado de caja           → PUNTO_CAJA.EstadoOperativo (Activo/Inactivo)
--   #8  Punto de expedición DNIT → PUNTO_CAJA.PuntoExpedicion (001, 002...)
--   #9  Serie por punto exped.   → PUNTO_CAJA.SecuenciaActual (contador propio)
--
-- DISEÑO (según DNIT Paraguay):
--   • Establecimiento y Timbrado siguen en DATOS_TRIBUTARIOS (son del local).
--   • Cada PUNTO_CAJA (caja física) tiene su Punto de Expedición y su propia
--     secuencia → el número de factura queda EEE-PPP-NNNNNNN, único por caja.
--   • La sesión de caja (tabla CAJA) hereda el punto de expedición de su PUNTO_CAJA.
--
-- Esta etapa SOLO agrega columnas y carga datos. Los SP de numeración y la app
-- se ajustan en la etapa 2.  ⚠️ BACKUP antes.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ─── 1. Nuevas columnas en PUNTO_CAJA ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.PUNTO_CAJA') AND name='Codigo')
    ALTER TABLE dbo.PUNTO_CAJA ADD Codigo VARCHAR(20) NULL;          -- #5  ej: CJ-001
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.PUNTO_CAJA') AND name='PuntoExpedicion')
    ALTER TABLE dbo.PUNTO_CAJA ADD PuntoExpedicion VARCHAR(3) NULL;  -- #8  ej: 001
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.PUNTO_CAJA') AND name='SecuenciaActual')
    ALTER TABLE dbo.PUNTO_CAJA ADD SecuenciaActual INT NOT NULL DEFAULT 0;  -- #9
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.PUNTO_CAJA') AND name='EstadoOperativo')
    ALTER TABLE dbo.PUNTO_CAJA ADD EstadoOperativo VARCHAR(20) NOT NULL DEFAULT 'Activo';  -- #6
GO
PRINT 'OK: columnas Codigo, PuntoExpedicion, SecuenciaActual, EstadoOperativo aseguradas en PUNTO_CAJA.';
GO

-- ─── 2. La sesión CAJA hereda el punto de expedición usado al abrir ──────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.CAJA') AND name='PuntoExpedicion')
    ALTER TABLE dbo.CAJA ADD PuntoExpedicion VARCHAR(3) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.CAJA') AND name='CodigoCaja')
    ALTER TABLE dbo.CAJA ADD CodigoCaja VARCHAR(20) NULL;   -- #12 nomenclatura en comprobantes
GO
PRINT 'OK: columnas PuntoExpedicion y CodigoCaja aseguradas en CAJA.';
GO

-- ─── 3. Generar Código y Punto de Expedición a los puntos de caja existentes ────
--   Código   = 'CJ-' + IdPuntoCaja con 3 dígitos.
--   Punto exp = correlativo POR TIENDA (001, 002...) → así cada caja de una tienda
--               tiene punto de expedición distinto.
;WITH Num AS (
    SELECT IdPuntoCaja, IdTienda,
           ROW_NUMBER() OVER (PARTITION BY IdTienda ORDER BY IdPuntoCaja) AS rn
    FROM dbo.PUNTO_CAJA
)
UPDATE pc
    SET pc.Codigo          = ISNULL(pc.Codigo, 'CJ-' + RIGHT('000' + CAST(pc.IdPuntoCaja AS VARCHAR), 3)),
        pc.PuntoExpedicion = ISNULL(pc.PuntoExpedicion, RIGHT('000' + CAST(n.rn AS VARCHAR), 3)),
        pc.EstadoOperativo = ISNULL(NULLIF(pc.EstadoOperativo,''), 'Activo')
FROM dbo.PUNTO_CAJA pc
INNER JOIN Num n ON n.IdPuntoCaja = pc.IdPuntoCaja;
PRINT 'OK: Código y Punto de Expedición asignados a puntos de caja existentes.';
GO

-- ─── 4. Constraint: punto de expedición único por tienda ────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UQ_PuntoCaja_Tienda_PtoExp')
    CREATE UNIQUE INDEX UQ_PuntoCaja_Tienda_PtoExp
    ON dbo.PUNTO_CAJA (IdTienda, PuntoExpedicion)
    WHERE PuntoExpedicion IS NOT NULL;
GO
PRINT 'OK: índice único (IdTienda, PuntoExpedicion) creado.';
GO

-- ─── 5. Verificación ────────────────────────────────────────────────────────────
SELECT pc.IdPuntoCaja, t.Nombre AS Tienda, pc.Nombre AS Caja,
       pc.Codigo, pc.PuntoExpedicion, pc.SecuenciaActual,
       pc.EstadoOperativo, pc.Activo
FROM dbo.PUNTO_CAJA pc
INNER JOIN dbo.TIENDA t ON t.IdTienda = pc.IdTienda
ORDER BY pc.IdTienda, pc.PuntoExpedicion;
GO

PRINT '════ Script 108 (Etapa 1 Caja) completado ════';
GO
