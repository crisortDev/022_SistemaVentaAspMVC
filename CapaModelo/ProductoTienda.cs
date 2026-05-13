using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class ProductoTienda
    {
        public int IdProductoTienda { get; set; }
        public Producto oProducto { get; set; }
        public Tienda oTienda { get; set; }
        public int Stock { get; set; }
        public int StockMinimo { get; set; }
        public int StockMaximo { get; set; }
        public decimal PrecioIvaIncluido { get; set; }
        public decimal PrecioVentaIvaIncluido { get; set; }
        public decimal PrecioCompraIvaIncluido { get; set; }
        public decimal PrecioUnidadCompra { get; set; }
        public decimal PrecioUnidadVenta { get; set; }
        public decimal PrecioVenta { get; set; }
        public decimal PorcentajeIva { get; set; }
        public bool Iniciado { get; set; }
        // Precio calculado por margen mínimo de la categoría (IVA incluido)
        public decimal PrecioVentaSugerido { get; set; }
        public decimal PorcentajeGananciaCategoria { get; set; }
    }
}
