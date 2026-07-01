-- ════════════════════════════════════════════════════════════════════════════════
-- 115b: Verificación rápida — ¿el RS2 de usp_ObtenerDetalleCaja devuelve "Estado"?
-- Si esta consulta muestra la columna Estado, el SP está correcto.
-- Si NO la muestra, hay que RE-EJECUTAR el script 115 (versión con v.Estado).
-- ════════════════════════════════════════════════════════════════════════════════
USE [DBVENTAS_WEB]
GO
EXEC dbo.usp_ObtenerDetalleCaja @IdCaja = 12;
GO
-- En el SEGUNDO conjunto de resultados, la última columna debe llamarse "Estado".
