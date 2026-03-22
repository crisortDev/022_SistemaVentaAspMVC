using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class BajaProducto
    {
        public int IdProductoTienda { get; set; }
        public int IdProducto { get; set; }
        public int Cantidad { get; set; }
        public string Motivo { get; set; }
        public string Resultado { get; set; }
    }
}
