using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class HistorialPrecioCompra
    {
        public string FechaRegistro { get; set; }  // Puede ser DateTime si lo preferís
        public decimal PrecioCompra { get; set; }
        public string Observaciones { get; set; }
    }
}
