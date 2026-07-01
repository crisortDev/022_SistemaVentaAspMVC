-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 47: Renovar timbrado fiscal vencido en DATOS_TRIBUTARIOS
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
--
-- El script 38 solo actualizaba VencimientoTimbrado si Establecimiento estaba
-- vacío, dejando el registro existente con fecha vencida.
-- Este script actualiza el timbrado incondicionalmente para pruebas.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- Ver estado actual antes de modificar
SELECT NumeroTimbrado, VencimientoTimbrado, Establecimiento, PuntoExpedicion, SecuenciaActual
FROM dbo.DATOS_TRIBUTARIOS;
GO

-- Actualizar timbrado (incondicionalmente)
UPDATE dbo.DATOS_TRIBUTARIOS
SET NumeroTimbrado      = 12958745,
    VencimientoTimbrado = '2027-12-31',
    Establecimiento     = '001',
    PuntoExpedicion     = '001';

PRINT 'OK: Timbrado actualizado. Vencimiento: 2027-12-31';
GO

-- Verificar
SELECT NumeroTimbrado, VencimientoTimbrado, Establecimiento, PuntoExpedicion, SecuenciaActual
FROM dbo.DATOS_TRIBUTARIOS;
GO
