using System;

namespace CapaModelo
{
    public class DetalleVenta
    {
        public int IdDetalleVenta { get; set; }
        public int IdProducto { get; set; }
        public string CodigoProducto { get; set; }
        public string NombreProducto { get; set; }
        public decimal Cantidad { get; set; }
        public decimal PrecioUnidad { get; set; }
        public decimal IvaPorcentaje { get; set; }
        public decimal MontoIva { get; set; }
        public decimal ImporteSinIva { get; set; }
        public decimal ImporteTotal { get; set; }
        public decimal ImporteTotalIvaIncluido { get; set; }
        /// <summary>Descuento aplicado a esta línea (%). 0 = sin descuento.</summary>
        public decimal PorcentajeDescuento { get; set; }
        /// <summary>Unidad de medida del producto (ej: Unidad, Metro).</summary>
        public string UnidadMedida { get; set; }
        /// <summary>Estado de la línea: OK | GARANTIA_PARCIAL | CAMBIADO | DEVUELTO_NC</summary>
        public string EstadoLinea         { get; set; }
        public int    CantidadGarantizada { get; set; }
        public int    CantidadDisponible  { get; set; }
        /// <summary>Stock disponible del producto en la tienda (solo para pantalla de garantía).</summary>
        public decimal StockDisponible    { get; set; }
    }
}
