-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 37b: Distribución de usuarios entre sucursales para demo
-- ─────────────────────────────────────────────────────────────────────────────
-- Resultado final:
--
--  TIENDA 1 — Compu Space Central
--    Lilian   (17) Encargado      → aprueba OC / confirma compras
--    Juan     (4)  CAJERO         → carga OC / recepción
--    Pepe     (5)  CAJERO         → carga OC / recepción
--
--  TIENDA 2 — Compu Space Sucursal
--    Jorge    (3)  ADMINISTRADOR  → aprueba OC / confirma compras + acceso amplio
--    Federico (16) REPOSITOR      → carga OC / recepción / solo vista
--
--  GLOBAL (sin tienda fija)
--    Cristian (1)  SUPERADMIN     → acceso total a todo
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- Tienda 1: Lilian, Juan, Pepe (ya están en IdTienda=1 — confirmar)
UPDATE dbo.USUARIO SET IdTienda = 1 WHERE IdUsuario IN (17, 4, 5);
PRINT 'OK: Tienda 1 → Lilian (Encargado), Juan (CAJERO), Pepe (CAJERO)';

-- Tienda 2: Jorge y Federico
UPDATE dbo.USUARIO SET IdTienda = 2 WHERE IdUsuario IN (3, 16);
PRINT 'OK: Tienda 2 → Jorge (ADMINISTRADOR), Federico (REPOSITOR)';

-- SuperAdmin sin tienda fija (NULL = global)
UPDATE dbo.USUARIO SET IdTienda = NULL WHERE IdUsuario = 1;
PRINT 'OK: Cristian (SUPERADMIN) → sin tienda fija (acceso global)';
GO

-- ── Resumen ───────────────────────────────────────────────────────────────────
PRINT '──────────────────────────────────────────────────────────────────'
PRINT 'TIENDA 1 — Compu Space Central'
PRINT '  cristian.a.ortega@hotmail.com  Lilian    Encargado      aprueba'
PRINT '  juan.perez@gmail.com           Juan      CAJERO         carga'
PRINT '  tiantega@gmail.com             Pepe      CAJERO         carga'
PRINT ''
PRINT 'TIENDA 2 — Compu Space Sucursal'
PRINT '  jorge@correo.com               Jorge     ADMINISTRADOR  aprueba'
PRINT '  crisarielorte@fpuna.edu.py     Federico  REPOSITOR      carga/vista'
PRINT ''
PRINT 'GLOBAL'
PRINT '  admin@gmail.com                Cristian  SUPERADMIN     todo'
PRINT '──────────────────────────────────────────────────────────────────'
PRINT 'Contraseña de todos: 123456'
PRINT 'Script 37b completado.'
GO
