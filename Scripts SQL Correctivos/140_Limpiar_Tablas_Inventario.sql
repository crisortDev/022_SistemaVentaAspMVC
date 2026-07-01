-- =====================================================================
-- Limpieza completa de tablas de Inventario (para pruebas)
-- Orden: hijos primero, luego padre (respeta FK)
-- =====================================================================

DELETE FROM dbo.ASIGNACION_INVENTARIO;
DELETE FROM dbo.DETALLE_INVENTARIO;
DELETE FROM dbo.INVENTARIO;

-- Reiniciar identidades
DBCC CHECKIDENT ('dbo.ASIGNACION_INVENTARIO', RESEED, 0);
DBCC CHECKIDENT ('dbo.DETALLE_INVENTARIO',    RESEED, 0);
DBCC CHECKIDENT ('dbo.INVENTARIO',            RESEED, 0);

SELECT 'Tablas limpiadas correctamente' AS Resultado;
