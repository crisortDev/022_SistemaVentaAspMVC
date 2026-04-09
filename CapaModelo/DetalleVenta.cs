using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class DetalleVenta
    {
        public int Cantidad { get; set; }
        public string NombreProducto { get; set; }
        // FIX: Cambiado de float a decimal para evitar errores de precisión en montos monetarios.
        // float tiene ~7 dígitos de precisión, decimal(18,2) es el estándar para dinero.
        public decimal PrecioUnidad { get; set; }
        public decimal ImporteTotal { get; set; }
        public decimal ImporteTotalIvaIncluido { get; set; }
    }
}
