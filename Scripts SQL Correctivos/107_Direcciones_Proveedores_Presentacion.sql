-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 107: Prolijar direcciones de proveedores ACTIVOS (presentación / defensa)
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Corrige Direccion / Ciudad / Barrio / Calle / Referencia con datos de prueba
-- ("calle test", "B-test", repetición de Cruz Azul/Frente a Ferretería, etc.)
-- para los 6 proveedores activos con compras reales.
-- No toca los desactivados (4,5,6,7).
--
-- ⚠️ BACKUP antes. Revisá/ajustá los valores a gusto.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- HP Paraguay S.A.
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Av. Mariscal López 3550',
        Ciudad    = 'Asunción',
        Barrio    = 'Villa Morra',
        Calle     = 'Mariscal López',
        Referencia= 'Edificio Torre 1, planta baja'
    WHERE IdProveedor = 1;

    -- Xiaomi Distribución S.A.
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Av. España 1245',
        Ciudad    = 'Asunción',
        Barrio    = 'Recoleta',
        Calle     = 'España',
        Referencia= 'Casi Brasil'
    WHERE IdProveedor = 2;

    -- Todo Electrónica S.R.L.
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Av. Eusebio Ayala 2100',
        Ciudad    = 'Asunción',
        Barrio    = 'San Pablo',
        Calle     = 'Eusebio Ayala',
        Referencia= 'Frente al shopping'
    WHERE IdProveedor = 3;

    -- Green Tech Import S.A.
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Av. Aviadores del Chaco 1500',
        Ciudad    = 'Asunción',
        Barrio    = 'Mburucuyá',
        Calle     = 'Aviadores del Chaco',
        Referencia= 'Cerca del World Trade Center'
    WHERE IdProveedor = 8;

    -- Distribuidora Capiatá S.R.L.
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Ruta 2 Km 20',
        Ciudad    = 'Capiatá',
        Barrio    = 'Centro',
        Calle     = 'Ruta Mariscal Estigarribia',
        Referencia= 'A lado de la municipalidad'
    WHERE IdProveedor = 10;

    -- Electro Import S.A.  (tenía "test" en todo)
    UPDATE dbo.PROVEEDOR SET
        Direccion = 'Av. Fernando de la Mora 850',
        Ciudad    = 'Fernando de la Mora',
        Barrio    = 'Zona Norte',
        Calle     = 'Fernando de la Mora',
        Referencia= 'Frente a la plaza'
    WHERE IdProveedor = 15;

    PRINT '>> Direcciones de proveedores activos actualizadas.';
    COMMIT TRANSACTION;
    PRINT '════ Script 107 completado ════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO

-- ── Verificación ───────────────────────────────────────────────────────────────
SELECT IdProveedor, RazonSocial, RUC, Ciudad, Direccion, Barrio, Calle, Referencia
FROM dbo.PROVEEDOR
WHERE Activo = 1
ORDER BY RazonSocial;
GO
