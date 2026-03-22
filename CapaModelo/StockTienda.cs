using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class StockTienda
    {
        public int IdProductoTienda { get; set; }
        public int IdProducto { get; set; }
        public string Codigo { get; set; }
        public string NombreProducto { get; set; }
        public string Categoria { get; set; }
        public int IdTienda { get; set; }
        public string NombreTienda { get; set; }
        public int Stock { get; set; }
        public int StockMinimo { get; set; }
        public int StockMaximo { get; set; }
        public string EstadoStock { get; set; }
    }
}
