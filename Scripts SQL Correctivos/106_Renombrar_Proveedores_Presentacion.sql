-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 106: Renombrar proveedores con datos prolijos (presentación / defensa)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Deja nombres, RUC (formato paraguayo xxxxxxxx-x), teléfono y correo presentables
-- para los proveedores ACTIVOS con compras reales. No toca compras ni montos.
--
-- ⚠️ BACKUP antes. Revisá los valores propuestos antes de ejecutar.
--    Ajustá cualquier nombre/RUC a tu gusto.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- IdProveedor 1 — antes "PROVEEDOR HP"
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'HP Paraguay S.A.',
        RUC         = '80012345-1',
        Telefono    = '021-201100',
        Correo      = 'ventas@hp.com.py'
    WHERE IdProveedor = 1;

    -- IdProveedor 2 — antes "PROVEEDOR XIAOMI"
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'Xiaomi Distribución S.A.',
        RUC         = '80023456-2',
        Telefono    = '021-202200',
        Correo      = 'ventas@xiaomi.com.py'
    WHERE IdProveedor = 2;

    -- IdProveedor 3 — antes "PROVEEDOR TODO ELECTRONICA"
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'Todo Electrónica S.R.L.',
        RUC         = '80034567-3',
        Telefono    = '021-203300',
        Correo      = 'ventas@todoelectronica.com.py'
    WHERE IdProveedor = 3;

    -- IdProveedor 8 — antes "Green " (con espacio)
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'Green Tech Import S.A.',
        RUC         = '80056789-8',
        Telefono    = '021-204400',
        Correo      = 'ventas@greentech.com.py'
    WHERE IdProveedor = 8;

    -- IdProveedor 10 — antes "Proveedor Capiata"
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'Distribuidora Capiatá S.R.L.',
        RUC         = '80067890-1',
        Telefono    = '021-205500',
        Correo      = 'ventas@distcapiata.com.py'
    WHERE IdProveedor = 10;

    -- IdProveedor 15 — ya estaba ok, se asegura formato
    UPDATE dbo.PROVEEDOR SET
        RazonSocial = 'Electro Import S.A.',
        RUC         = '80045678-9',
        Telefono    = '021-445566',
        Correo      = 'ventas@electroimport.com.py'
    WHERE IdProveedor = 15;

    -- Limpieza general de espacios en todos
    UPDATE dbo.PROVEEDOR SET RazonSocial = LTRIM(RTRIM(RazonSocial));

    PRINT '>> Proveedores renombrados correctamente.';
    COMMIT TRANSACTION;
    PRINT '════ Script 106 completado ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO

-- ── Verificación ───────────────────────────────────────────────────────────────
SELECT IdProveedor, RazonSocial, RUC, Telefono, Correo, Activo
FROM dbo.PROVEEDOR
WHERE Activo = 1
ORDER BY RazonSocial;
GO
