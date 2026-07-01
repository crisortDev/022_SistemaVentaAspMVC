-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 105: Limpieza cosmética de proveedores (presentación / defensa)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- 1. Desactiva (Activo=0) los proveedores de PRUEBA que NO tienen compras
--    confirmadas → dejan de aparecer en el reporte (filtra p.Activo=1).
-- 2. Renombra "TEST_OC_PROVEEDOR" (sí tiene compras reales) a un nombre presentable
--    y le corrige el RUC de prueba.
--
-- No borra nada (los desactivados quedan en la base, solo ocultos).
-- ⚠️ BACKUP antes. PASO 1 diagnóstico, PASO 2 aplicar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: DIAGNÓSTICO — proveedores sin compras confirmadas ───────────────────
SELECT
    p.IdProveedor, p.RazonSocial, p.RUC, p.Activo,
    (SELECT COUNT(*) FROM dbo.COMPRA c
      WHERE c.IdProveedor = p.IdProveedor AND c.Estado = 'Confirmada') AS ComprasConfirmadas
FROM dbo.PROVEEDOR p
ORDER BY ComprasConfirmadas, p.IdProveedor;
GO

-- ── PASO 2: APLICAR (descomentar tras revisar el PASO 1) ───────────────────────
/*
BEGIN TRY
    BEGIN TRANSACTION;

    -- 2a) Desactivar proveedores SIN compras confirmadas (datos de prueba)
    UPDATE p
        SET p.Activo = 0
    FROM dbo.PROVEEDOR p
    WHERE p.Activo = 1
      AND NOT EXISTS (
            SELECT 1 FROM dbo.COMPRA c
            WHERE c.IdProveedor = p.IdProveedor AND c.Estado = 'Confirmada'
      );
    PRINT '>> Proveedores de prueba sin compras desactivados: ' + CAST(@@ROWCOUNT AS VARCHAR);

    -- 2b) Renombrar el proveedor de prueba que SÍ tiene compras reales (IdProveedor 15)
    UPDATE dbo.PROVEEDOR
        SET RazonSocial = 'ELECTRO IMPORT S.A.',
            RUC         = '80045678-9',
            Correo      = 'ventas@electroimport.com.py',
            Telefono    = '021-445566'
    WHERE IdProveedor = 15;
    PRINT '>> Proveedor 15 renombrado a nombre presentable.';

    COMMIT TRANSACTION;
    PRINT '════ Script 105 completado ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO
*/

-- ── PASO 3: VERIFICACIÓN — proveedores activos que quedan ──────────────────────
-- SELECT IdProveedor, RazonSocial, RUC, Activo FROM dbo.PROVEEDOR WHERE Activo = 1 ORDER BY RazonSocial;
-- GO
