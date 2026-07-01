/* ============================================================================
   PROYECTO TESIS - Sistema de Ventas ASP.NET MVC
   Script 01: Unidad de Medida por Categoria + Cantidades decimales
   ----------------------------------------------------------------------------
   QUE HACE ESTE SCRIPT:
   1. Crea la tabla UnidadMedida (catalogo: Unidad, Kg, Litro, etc.)
   2. Agrega la FK IdUnidadMedida a la tabla Categoria
   3. Carga unidades de medida iniciales
   4. Cambia los campos Cantidad (int -> decimal) en los 4 detalles
   5. Cambia Producto.Stock (int -> decimal) para soportar fracciones

   IMPORTANTE:
   - HACER BACKUP de la base ANTES de ejecutar (ver guia paso 1).
   - Ejecutar por bloques y revisar mensajes.
   - Decimal(18,3) permite hasta 3 decimales (ej: 0.250 Kg, 1.5 Lt).
   ============================================================================ */

SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    /* ------------------------------------------------------------------
       1) TABLA UnidadMedida
       ------------------------------------------------------------------ */
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UnidadMedida')
    BEGIN
        CREATE TABLE [dbo].[UnidadMedida] (
            [IdUnidadMedida] INT IDENTITY(1,1) NOT NULL,
            [Descripcion]    NVARCHAR(50)  NOT NULL,   -- ej: Kilogramo
            [Abreviatura]    NVARCHAR(10)  NOT NULL,   -- ej: Kg
            [PermiteDecimal] BIT           NOT NULL CONSTRAINT DF_UM_PermiteDecimal DEFAULT (0),
            [EsActivo]       BIT           NULL        CONSTRAINT DF_UM_EsActivo     DEFAULT (1),
            CONSTRAINT [PK_UnidadMedida] PRIMARY KEY CLUSTERED ([IdUnidadMedida] ASC)
        );
        PRINT '>> Tabla UnidadMedida creada.';
    END
    ELSE
        PRINT '>> Tabla UnidadMedida ya existe, se omite.';

    /* ------------------------------------------------------------------
       2) UNIDADES DE MEDIDA INICIALES
       PermiteDecimal = 1 en las que tienen sentido fraccionar (peso/volumen/longitud)
       ------------------------------------------------------------------ */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[UnidadMedida])
    BEGIN
        INSERT INTO [dbo].[UnidadMedida] (Descripcion, Abreviatura, PermiteDecimal, EsActivo) VALUES
            ('Unidad',     'Un.', 0, 1),
            ('Kilogramo',  'Kg',  1, 1),
            ('Gramo',      'g',   1, 1),
            ('Litro',      'Lt',  1, 1),
            ('Mililitro',  'ml',  1, 1),
            ('Metro',      'm',   1, 1),
            ('Centimetro', 'cm',  1, 1),
            ('Caja',       'Cja', 0, 1),
            ('Paquete',    'Paq', 0, 1),
            ('Docena',     'Doc', 0, 1);
        PRINT '>> Unidades de medida iniciales cargadas.';
    END

    /* ------------------------------------------------------------------
       3) FK IdUnidadMedida EN Categoria
       Nullable para no romper categorias existentes.
       ------------------------------------------------------------------ */
    IF NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE Name = 'IdUnidadMedida'
                     AND Object_ID = Object_ID('dbo.Categoria'))
    BEGIN
        ALTER TABLE [dbo].[Categoria] ADD [IdUnidadMedida] INT NULL;
        PRINT '>> Columna Categoria.IdUnidadMedida agregada.';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Categoria_UnidadMedida')
    BEGIN
        ALTER TABLE [dbo].[Categoria]
            ADD CONSTRAINT [FK_Categoria_UnidadMedida]
            FOREIGN KEY ([IdUnidadMedida]) REFERENCES [dbo].[UnidadMedida] ([IdUnidadMedida]);
        PRINT '>> FK_Categoria_UnidadMedida creada.';
    END

    /* Asignar "Unidad" por defecto a las categorias que no tengan unidad */
    UPDATE c
        SET c.IdUnidadMedida = (SELECT TOP 1 IdUnidadMedida FROM [dbo].[UnidadMedida] WHERE Descripcion = 'Unidad')
    FROM [dbo].[Categoria] c
    WHERE c.IdUnidadMedida IS NULL;
    PRINT '>> Categorias sin unidad actualizadas a "Unidad".';

    /* ------------------------------------------------------------------
       4) CANTIDAD int -> decimal(18,3) en los 4 detalles
       (las columnas no tienen indices ni constraints sobre Cantidad,
        por eso se puede alterar directamente)
       ------------------------------------------------------------------ */
    ALTER TABLE [dbo].[DetalleCompra]            ALTER COLUMN [Cantidad] DECIMAL(18,3) NULL;
    ALTER TABLE [dbo].[DetalleVenta]             ALTER COLUMN [Cantidad] DECIMAL(18,3) NULL;
    ALTER TABLE [dbo].[DetalleNotaCreditoCompra] ALTER COLUMN [Cantidad] DECIMAL(18,3) NULL;
    ALTER TABLE [dbo].[DetalleNotaCreditoVenta]  ALTER COLUMN [Cantidad] DECIMAL(18,3) NULL;
    PRINT '>> Cantidad cambiada a decimal(18,3) en los 4 detalles.';

    /* ------------------------------------------------------------------
       5) STOCK int -> decimal(18,3) en Producto
       ------------------------------------------------------------------ */
    ALTER TABLE [dbo].[Producto] ALTER COLUMN [Stock] DECIMAL(18,3) NULL;
    PRINT '>> Producto.Stock cambiado a decimal(18,3).';

    COMMIT TRANSACTION;
    PRINT '============================================================';
    PRINT 'OK - Todos los cambios aplicados correctamente.';
    PRINT 'Siguiente paso: actualizar el modelo .edmx en Visual Studio.';
    PRINT '============================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** No se aplico ningun cambio (rollback).';
END CATCH;
GO

/* ============================================================================
   OPCIONAL - Unidad de medida tambien a nivel Producto (descomentar si se quiere)
   Permite que un producto sobrescriba la unidad heredada de su categoria.
   ============================================================================ */
-- IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name='IdUnidadMedida' AND Object_ID=Object_ID('dbo.Producto'))
-- BEGIN
--     ALTER TABLE [dbo].[Producto] ADD [IdUnidadMedida] INT NULL;
--     ALTER TABLE [dbo].[Producto] ADD CONSTRAINT [FK_Producto_UnidadMedida]
--         FOREIGN KEY ([IdUnidadMedida]) REFERENCES [dbo].[UnidadMedida]([IdUnidadMedida]);
-- END
-- GO

/* ============================================================================
   ROLLBACK MANUAL (solo si necesitas revertir y NO restauraste backup)
   OJO: volver decimal->int trunca los decimales existentes.
   ============================================================================ */
-- ALTER TABLE [dbo].[DetalleCompra]            ALTER COLUMN [Cantidad] INT NULL;
-- ALTER TABLE [dbo].[DetalleVenta]             ALTER COLUMN [Cantidad] INT NULL;
-- ALTER TABLE [dbo].[DetalleNotaCreditoCompra] ALTER COLUMN [Cantidad] INT NULL;
-- ALTER TABLE [dbo].[DetalleNotaCreditoVenta]  ALTER COLUMN [Cantidad] INT NULL;
-- ALTER TABLE [dbo].[Producto]                 ALTER COLUMN [Stock] INT NULL;
-- ALTER TABLE [dbo].[Categoria] DROP CONSTRAINT [FK_Categoria_UnidadMedida];
-- ALTER TABLE [dbo].[Categoria] DROP COLUMN [IdUnidadMedida];
-- DROP TABLE [dbo].[UnidadMedida];
-- GO
