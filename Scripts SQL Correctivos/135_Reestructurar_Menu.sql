-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 135: Reestructuración de MENU / SUBMENU según propuesta del tutor
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-06-22
--
-- CAMBIOS:
--   1. ADD EsGrupo BIT a SUBMENU (para cabeceras visuales en el dropdown)
--   2. Crear menú INICIO (nuevo)
--   3. Renombrar / reordenar MENUs existentes
--   4. Mover submenús de Caja → Ventas
--   5. Mover submenús de Seguridad → Configuración
--   6. Insertar cabeceras de grupo (EsGrupo=1) en Ventas, Existencia, Configuración
--   7. Renombrar submenús según propuesta
--   8. Desactivar MENUs vacíos (Caja, Seguridad, Clientes)
--   9. Reescribir usp_ObtenerDetalleUsuario con EsGrupo en el XML
--
-- ⚠️ BACKUP antes de ejecutar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: Agregar columna EsGrupo a SUBMENU
-- ════════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.SUBMENU') AND name = 'EsGrupo')
BEGIN
    ALTER TABLE dbo.SUBMENU ADD EsGrupo BIT NOT NULL DEFAULT 0;
    PRINT 'OK: Columna EsGrupo agregada a SUBMENU.';
END
ELSE
    PRINT 'INFO: EsGrupo ya existe en SUBMENU.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: Crear menú INICIO (si no existe)
-- ════════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM dbo.MENU WHERE Nombre = 'Inicio')
BEGIN
    INSERT INTO dbo.MENU (Nombre, Icono, Orden, Activo)
    VALUES ('Inicio', 'fas fa-home', 0, 1);
    PRINT 'OK: Menú Inicio creado (IdMenu=' + CAST(SCOPE_IDENTITY() AS VARCHAR) + ').';
END
ELSE
    PRINT 'INFO: Menú Inicio ya existe.';
GO

-- Submenu Dashboard bajo Inicio
DECLARE @IdMenuInicio INT;
SELECT @IdMenuInicio = IdMenu FROM dbo.MENU WHERE Nombre = 'Inicio';

IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu = @IdMenuInicio AND Controlador = 'Home')
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (@IdMenuInicio, 'Dashboard', 'Home', 'Index', 'fas fa-tachometer-alt', 1, 1, 0);
    PRINT 'OK: Submenu Dashboard creado bajo Inicio.';
END

-- Permisos Dashboard para todos los roles activos
DECLARE @IdSmDash INT;
SELECT @IdSmDash = IdSubMenu FROM dbo.SUBMENU WHERE IdMenu = @IdMenuInicio AND Controlador = 'Home';

INSERT INTO dbo.PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
SELECT r.IdRol, @IdSmDash, 1, GETDATE()
FROM dbo.ROL r
WHERE r.Activo = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.PERMISOS p WHERE p.IdRol = r.IdRol AND p.IdSubMenu = @IdSmDash);
PRINT 'OK: Permisos Dashboard asignados a todos los roles.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3: Renombrar y reordenar MENUs existentes
-- ════════════════════════════════════════════════════════════════════════════════

-- Compras (IdMenu=3) → orden 2
UPDATE dbo.MENU SET Nombre='Compras', Icono='fas fa-shopping-cart', Orden=2
WHERE IdMenu = 3;

-- Ventas (IdMenu=4) → orden 3
UPDATE dbo.MENU SET Nombre='Ventas', Icono='fas fa-cash-register', Orden=3
WHERE IdMenu = 4;

-- Control de Inventario (IdMenu=8) → Existencia, orden 4
UPDATE dbo.MENU SET Nombre='Existencia', Icono='fas fa-boxes', Orden=4
WHERE IdMenu = 8;

-- Reportes (IdMenu=5) → orden 5
UPDATE dbo.MENU SET Nombre='Reportes', Icono='fas fa-chart-bar', Orden=5
WHERE IdMenu = 5;

-- Configuración (IdMenu=1) → orden 6
UPDATE dbo.MENU SET Nombre='Configuración', Icono='fas fa-cog', Orden=6
WHERE IdMenu = 1;

-- Desactivar menús que se fusionan: Caja(6), Seguridad(7), Clientes(2)
UPDATE dbo.MENU SET Activo=0 WHERE IdMenu IN (2, 6, 7);

PRINT 'OK: MENUs renombrados y reordenados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 4: Reestructurar submenús de COMPRAS (IdMenu=3)
-- ════════════════════════════════════════════════════════════════════════════════

-- Renombrar y reordenar items existentes
UPDATE dbo.SUBMENU SET Nombre='Proveedores',               Orden=1  WHERE IdSubMenu=7;
UPDATE dbo.SUBMENU SET Nombre='Registrar Orden de Compra', Orden=2  WHERE IdSubMenu=29;
UPDATE dbo.SUBMENU SET Nombre='Consultar Orden de Compra', Orden=3  WHERE IdSubMenu=30;
UPDATE dbo.SUBMENU SET Nombre='Aprobar Orden de Compra',   Orden=4  WHERE IdSubMenu=31;
UPDATE dbo.SUBMENU SET Nombre='Recepción de Compras',      Orden=5  WHERE IdSubMenu=33;
UPDATE dbo.SUBMENU SET Nombre='Revisión de Compras',       Orden=6  WHERE IdSubMenu=35;
UPDATE dbo.SUBMENU SET Nombre='Consultar Compras',         Orden=7  WHERE IdSubMenu=10;
UPDATE dbo.SUBMENU SET Nombre='Órdenes de Pago',           Orden=8  WHERE IdSubMenu=34;
UPDATE dbo.SUBMENU SET Nombre='Registrar Nota de Crédito', Orden=9  WHERE IdSubMenu=36;

PRINT 'OK: Submenús de Compras actualizados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 5: Reestructurar submenús de VENTAS (IdMenu=4) + mover Caja
-- ════════════════════════════════════════════════════════════════════════════════

-- Reordenar items ya existentes en Ventas
UPDATE dbo.SUBMENU SET Nombre='Clientes',              Orden=1   WHERE IdSubMenu=6;
UPDATE dbo.SUBMENU SET Nombre='Tiendas',               Orden=2   WHERE IdSubMenu=11;
UPDATE dbo.SUBMENU SET Nombre='Registrar Venta Directa',Orden=3  WHERE IdSubMenu=38;  -- Activo=0
UPDATE dbo.SUBMENU SET Nombre='Consultar Ventas',      Orden=4   WHERE IdSubMenu=39;
UPDATE dbo.SUBMENU SET Nombre='Registrar Pre-Venta',   Orden=5   WHERE IdSubMenu=40;
UPDATE dbo.SUBMENU SET Nombre='Consultar Pre-Ventas',  Orden=6   WHERE IdSubMenu=41;
UPDATE dbo.SUBMENU SET Nombre='Nota de Crédito Venta', Orden=7   WHERE IdSubMenu=43;

-- Insertar cabecera de grupo "Caja" en Ventas (si no existe)
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=4 AND EsGrupo=1 AND Nombre='Caja')
BEGIN
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (4, 'Caja', '', '', 'fas fa-cash-register', 8, 1, 1);
    PRINT 'OK: Cabecera de grupo Caja insertada en Ventas.';
END

-- Mover items de Caja (IdMenu=6) → Ventas (IdMenu=4)
UPDATE dbo.SUBMENU SET IdMenu=4, Orden=9  WHERE IdSubMenu=42;  -- Comprobantes de Cobro
UPDATE dbo.SUBMENU SET IdMenu=4, Orden=10 WHERE IdSubMenu=44;  -- Caja de Ventas
UPDATE dbo.SUBMENU SET IdMenu=4, Orden=11 WHERE IdSubMenu=46;  -- Gestión de Cajas
UPDATE dbo.SUBMENU SET IdMenu=4, Orden=12 WHERE IdSubMenu=50;  -- Cuentas por Cobrar

PRINT 'OK: Submenús de Ventas + Caja actualizados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 6: Reestructurar submenús de EXISTENCIA (IdMenu=8)
-- ════════════════════════════════════════════════════════════════════════════════

-- Cabecera "Stock"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=8 AND EsGrupo=1 AND Nombre='Stock')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (8, 'Stock', '', '', 'fas fa-layer-group', 1, 1, 1);

UPDATE dbo.SUBMENU SET Orden=2 WHERE IdSubMenu=28;  -- Stock por Tienda

-- Cabecera "Movimientos"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=8 AND EsGrupo=1 AND Nombre='Movimientos')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (8, 'Movimientos', '', '', 'fas fa-exchange-alt', 3, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Traslado de Tiendas', Orden=4 WHERE IdSubMenu=26;
UPDATE dbo.SUBMENU SET Nombre='Baja de Productos',   Orden=5 WHERE IdSubMenu=27;
UPDATE dbo.SUBMENU SET Nombre='Aprobar Bajas',        Orden=6 WHERE IdSubMenu=51;
UPDATE dbo.SUBMENU SET Nombre='Aprobar Traslados',    Orden=7 WHERE IdSubMenu=54;

-- Cabecera "Inventario"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=8 AND EsGrupo=1 AND Nombre='Inventario')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (8, 'Inventario', '', '', 'fas fa-clipboard-list', 8, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Toma de Inventario', Orden=9  WHERE IdSubMenu=52;
UPDATE dbo.SUBMENU SET Nombre='Inventarios',         Orden=10 WHERE IdSubMenu=53;

PRINT 'OK: Submenús de Existencia actualizados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 7: Reestructurar submenús de REPORTES (IdMenu=5)
-- ════════════════════════════════════════════════════════════════════════════════

UPDATE dbo.SUBMENU SET Nombre='Reporte de Ventas',           Orden=1  WHERE IdSubMenu=15;
UPDATE dbo.SUBMENU SET Nombre='Rentabilidad',                Orden=2  WHERE IdSubMenu=49;
UPDATE dbo.SUBMENU SET Nombre='Reporte Gerencial de Compras',Orden=3  WHERE IdSubMenu=37;
UPDATE dbo.SUBMENU SET Nombre='Reporte de Proveedores',      Orden=4  WHERE IdSubMenu=48;
UPDATE dbo.SUBMENU SET Nombre='Productos por Tienda',        Orden=5  WHERE IdSubMenu=14;
UPDATE dbo.SUBMENU SET Nombre='Reporte de Bajas',            Orden=6  WHERE IdSubMenu=25;
UPDATE dbo.SUBMENU SET Nombre='Reporte NC',                  Orden=7  WHERE IdSubMenu=47;

PRINT 'OK: Submenús de Reportes actualizados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 8: Reestructurar CONFIGURACIÓN (IdMenu=1) + mover Seguridad
-- ════════════════════════════════════════════════════════════════════════════════

-- Cabecera "Usuarios y Seguridad"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=1 AND EsGrupo=1 AND Nombre='Usuarios y Seguridad')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (1, 'Usuarios y Seguridad', '', '', 'fas fa-shield-alt', 1, 1, 1);

-- Mover Usuarios y Roles de Seguridad (7) → Configuración (1)
UPDATE dbo.SUBMENU SET IdMenu=1, Nombre='Usuarios', Orden=2 WHERE IdSubMenu=3;
UPDATE dbo.SUBMENU SET IdMenu=1, Nombre='Roles',    Orden=3 WHERE IdSubMenu=1;
UPDATE dbo.SUBMENU SET IdMenu=1, Activo=0           WHERE IdSubMenu=2;  -- Asignar Permisos (inactivo)

-- Cabecera "Recursos Humanos"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=1 AND EsGrupo=1 AND Nombre='Recursos Humanos')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (1, 'Recursos Humanos', '', '', 'fas fa-id-badge', 4, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Empleados', Orden=5 WHERE IdSubMenu=22;

-- Cabecera "Personas"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=1 AND EsGrupo=1 AND Nombre='Personas')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (1, 'Personas', '', '', 'fas fa-users', 6, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Personas', Orden=7 WHERE IdSubMenu=21;

-- Cabecera "Catálogo"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=1 AND EsGrupo=1 AND Nombre='Catálogo')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (1, 'Catálogo', '', '', 'fas fa-tags', 8, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Categorías', Orden=9  WHERE IdSubMenu=4;
UPDATE dbo.SUBMENU SET Nombre='Productos',  Orden=10 WHERE IdSubMenu=5;
UPDATE dbo.SUBMENU SET Activo=0             WHERE IdSubMenu=18;  -- Precios y Vigencia (inactivo)

-- Cabecera "Sistema"
IF NOT EXISTS (SELECT 1 FROM dbo.SUBMENU WHERE IdMenu=1 AND EsGrupo=1 AND Nombre='Sistema')
    INSERT INTO dbo.SUBMENU (IdMenu, Nombre, Controlador, Vista, Icono, Orden, Activo, EsGrupo)
    VALUES (1, 'Sistema', '', '', 'fas fa-server', 11, 1, 1);

UPDATE dbo.SUBMENU SET Nombre='Parámetros Tributarios', Orden=12 WHERE IdSubMenu=45;
UPDATE dbo.SUBMENU SET Nombre='Motivos de Baja',         Orden=13 WHERE IdSubMenu=23;

PRINT 'OK: Submenús de Configuración actualizados.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 9: usp_ObtenerDetalleUsuario — incluye EsGrupo en XML
-- ════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerDetalleUsuario]
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.IdUsuario,
        u.Nombres,
        u.Apellidos,
        u.Correo,
        u.Clave,
        u.IdTienda,
        u.IdRol,
        CASE WHEN u.Activo = 1 THEN '1' ELSE '0' END                  AS Activo,
        CONVERT(VARCHAR(30), u.FechaRegistro, 126)                     AS FechaRegistro,
        ISNULL(u.PasswordTemporalHash,   '')                           AS PasswordTemporalHash,
        CONVERT(VARCHAR(30), u.PasswordTemporalExpira, 126)            AS PasswordTemporalExpira,
        CASE WHEN ISNULL(u.RequiereCambioPassword,0) = 1 THEN '1' ELSE '0' END AS RequiereCambioPassword,
        ISNULL(u.IntentosFallidos, 0)                                  AS IntentosFallidos,
        CONVERT(VARCHAR(30), u.FechaCambioPassword, 126)               AS FechaCambioPassword,
        CONVERT(VARCHAR(30), u.FechaUltimoLogin,    126)               AS FechaUltimoLogin,

        -- Tienda
        (SELECT t.IdTienda, t.Nombre, t.RUC, t.Direccion, t.Telefono,
                CASE WHEN t.Activo=1 THEN '1' ELSE '0' END AS Activo,
                CONVERT(VARCHAR(30), t.FechaRegistro, 126)  AS FechaRegistro
         FROM   dbo.TIENDA t
         WHERE  t.IdTienda = u.IdTienda
         FOR XML PATH(''), TYPE) AS DetalleTienda,

        -- Rol
        (SELECT r.IdRol, r.Descripcion,
                CASE WHEN r.Activo=1 THEN '1' ELSE '0' END AS Activo,
                CONVERT(VARCHAR(30), r.FechaRegistro, 126)  AS FechaRegistro
         FROM   dbo.ROL r
         WHERE  r.IdRol = u.IdRol
         FOR XML PATH(''), TYPE) AS DetalleRol,

        -- Menú (solo menús con al menos un submenu activo con permiso para el rol)
        (SELECT m.Nombre AS NombreMenu,
                ISNULL(m.Icono, '') AS Icono,
                (
                    -- Submenús: cabeceras de grupo siempre, items solo si tienen permiso
                    SELECT sm.Nombre AS NombreSubMenu,
                           ISNULL(sm.Controlador, '') AS Controlador,
                           ISNULL(sm.Vista,        '') AS Vista,
                           ISNULL(sm.Icono,        '') AS Icono,
                           CASE WHEN sm.Activo = 1 THEN '1' ELSE '0' END AS Activo,
                           CASE WHEN sm.EsGrupo   = 1 THEN '1' ELSE '0' END AS EsGrupo
                    FROM   dbo.SUBMENU sm
                    WHERE  sm.IdMenu  = m.IdMenu
                      AND  sm.Activo  = 1
                      AND  (
                               sm.EsGrupo = 1   -- cabeceras siempre visibles
                               OR EXISTS (
                                   SELECT 1 FROM dbo.PERMISOS p
                                   WHERE  p.IdSubMenu = sm.IdSubMenu
                                     AND  p.IdRol     = u.IdRol
                                     AND  p.Activo    = 1
                               )
                           )
                    ORDER  BY ISNULL(sm.Orden, 999)
                    FOR XML PATH('SubMenu'), TYPE
                ) AS DetalleSubMenu
         FROM   dbo.MENU m
         WHERE  m.Activo = 1
           AND  EXISTS (
                    SELECT 1
                    FROM   dbo.SUBMENU sm2
                    JOIN   dbo.PERMISOS p2 ON p2.IdSubMenu = sm2.IdSubMenu
                    WHERE  sm2.IdMenu  = m.IdMenu
                      AND  sm2.Activo  = 1
                      AND  sm2.EsGrupo = 0
                      AND  p2.IdRol    = u.IdRol
                      AND  p2.Activo   = 1
                )
         ORDER  BY ISNULL(m.Orden, 999)
         FOR XML PATH('Menu'), TYPE) AS DetalleMenu

    FROM dbo.USUARIO u
    WHERE u.IdUsuario = @IdUsuario
    FOR XML PATH('Usuario');
END
GO
PRINT 'OK: usp_ObtenerDetalleUsuario actualizado con EsGrupo.';
GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN FINAL
-- ════════════════════════════════════════════════════════════════════════════════
SELECT m.Orden AS OrdM, m.Nombre AS Menu, m.Activo AS MActivo,
       s.Orden AS OrdS, s.Nombre AS SubMenu, s.Controlador, s.Vista,
       s.EsGrupo, s.Activo AS SActivo
FROM   dbo.MENU m
LEFT   JOIN dbo.SUBMENU s ON s.IdMenu = m.IdMenu
ORDER  BY m.Orden, ISNULL(s.Orden, 999);
GO

PRINT '════ Script 135 completado ════';
GO
