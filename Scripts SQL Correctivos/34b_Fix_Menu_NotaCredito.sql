-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 34b: Registrar submenú "Gestión de NC" — versión corregida
--             (sin columna Orden, sin cruce de batches con @variable)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- Ver qué columnas tiene SUBMENU (para diagnóstico)
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_NAME = 'SUBMENU'
 ORDER BY ORDINAL_POSITION;
GO

-- Ver menús disponibles (para confirmar el nombre del grupo Compras)
SELECT IdMenu, Nombre FROM dbo.MENU ORDER BY Nombre;
GO

-- Insertar el submenú en un solo batch (sin GO intermedios para mantener la variable)
DECLARE @IdMenuCompras INT;

SELECT TOP 1 @IdMenuCompras = IdMenu
  FROM dbo.MENU
 WHERE Nombre LIKE '%Compra%'
 ORDER BY IdMenu;

IF @IdMenuCompras IS NULL
BEGIN
    PRINT 'ERROR: No se encontró el menú de Compras. Revisá el SELECT de arriba.';
    RETURN;
END

PRINT 'IdMenu Compras = ' + CAST(@IdMenuCompras AS VARCHAR);

IF NOT EXISTS (
    SELECT 1 FROM dbo.SUBMENU
     WHERE Controlador = 'NotaCredito'
       AND Vista       = 'Index'
)
BEGIN
    INSERT INTO dbo.SUBMENU
        (IdMenu, Nombre, Controlador, Vista, Icono, Activo)
    VALUES
        (@IdMenuCompras,
         'Gestión de NC',
         'NotaCredito',
         'Index',
         'fas fa-file-invoice-dollar',
         1);

    PRINT 'OK: Submenú "Gestión de NC" creado.';
END
ELSE
    PRINT 'INFO: Submenú "Gestión de NC" ya existe.';

-- Verificar resultado
SELECT IdSubMenu, Nombre, Controlador, Vista, Icono, Activo
  FROM dbo.SUBMENU
 WHERE IdMenu = @IdMenuCompras
 ORDER BY IdSubMenu;
GO
