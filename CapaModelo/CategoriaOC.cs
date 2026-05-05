using System;

namespace CapaModelo
{
    /// <summary>
    /// Categoría de la Orden de Compra (rotación, urgente, programada, etc.).
    /// Mapea la tabla dbo.CATEGORIA_ORDEN_COMPRA.
    /// </summary>
    public class CategoriaOC
    {
        public int IdCategoriaOC { get; set; }
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
    }
}
