using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class PrecioVenta
    {
        public int IdPrecioVenta { get; set; }
        public int IdProducto { get; set; }
        public decimal PrecioUnidadVenta { get; set; }
        public DateTime FechaInicioVigencia { get; set; }
        public DateTime? FechaFinVigencia { get; set; }
    }
}
