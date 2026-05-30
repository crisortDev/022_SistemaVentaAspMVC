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
        public decimal Stock { get; set; }
        public decimal StockMinimo { get; set; }
        public decimal StockMaximo { get; set; }
        public decimal PrecioIvaIncluido { get; set; }
        public decimal PrecioVentaIvaIncluido { get; set; }
        public decimal PrecioCompraIvaIncluido { get; set; }
        public decimal PrecioUnidadCompra { get; set; }
        /// <summary>Costo Promedio Ponderado (CPP) — se recalcula en cada confirmación de compra.</summary>
        public decimal CostoPromedio { get; set; }
        public decimal PrecioUnidadVenta { get; set; }
        public decimal PrecioVenta { get; set; }
        public decimal PorcentajeIva { get; set; }
        public bool Iniciado { get; set; }
        // Precio calculado por margen mínimo de la categoría (IVA incluido)
        public decimal PrecioSugerido { get; set; }
        // Porcentaje de ganancia de la categoría a la que pertenece el producto
        public decimal MargenCategoria { get; set; }
        // Descuento máximo permitido (%) para productos de esta categoría
        public decimal DescuentoMaxPermitido { get; set; }
        // Unidad de medida del producto (Unidad / Metro / Kg)
        public string UnidadMedida { get; set; }
    }
}
