using System;

namespace CapaModelo
{
    public class Categoria
    {
        public int IdCategoria { get; set; }
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        /// <summary>
        /// Porcentaje de ganancia sugerido para los productos de esta categoría.
        /// Ejemplo: 25.00 significa 25 %. Opcional, por defecto 0.
        /// </summary>
        public decimal PorcentajeGanancia { get; set; }

        /// <summary>
        /// Fecha de la última modificación del registro.
        /// </summary>
        public DateTime? FechaModificacion { get; set; }

        /// <summary>
        /// Usuario que realizó la última modificación.
        /// </summary>
        public string UsuarioModificacion { get; set; }
    }
}