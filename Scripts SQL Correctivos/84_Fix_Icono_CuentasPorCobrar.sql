-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 84: Corregir ícono del submenú "Cuentas por Cobrar"
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-25
--
-- Problema: El script 83 insertó el ícono como 'fa-hand-holding-usd' (sin prefijo
--           'fas'), pero el helper de menú lo usa directamente como class CSS.
--           El resultado es un ícono en blanco/roto.
-- Solución: Actualizar a 'fas fa-dollar-sign' (ícono más compatible y claro).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Corregir ícono (sin prefijo → con prefijo fas) ─────────────────────────
UPDATE dbo.SUBMENU
SET    Icono = 'fas fa-dollar-sign'
WHERE  Controlador = 'ComprobanteCobro'
  AND  Nombre      = 'Cuentas por Cobrar';

IF @@ROWCOUNT = 1
    PRINT 'OK: Ícono de "Cuentas por Cobrar" actualizado a ''fas fa-dollar-sign''.';
ELSE
    PRINT 'WARN: No se actualizó ningún registro — verificar que el submenú existe.';

-- ── 2. Verificación ──────────────────────────────────────────────────────────
SELECT
    IdSubMenu,
    Nombre,
    Controlador,
    Vista,
    Icono,
    Activo
FROM   dbo.SUBMENU
WHERE  Controlador = 'ComprobanteCobro';

PRINT '════ Script 84 completado ════';
GO
