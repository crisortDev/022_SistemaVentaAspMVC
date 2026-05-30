using System;

namespace CapaModelo
{
    /// <summary>
    /// Linea de detalle de una Orden de Compra.
    /// La cantidad facturada se controla contra la Cantidad
    /// pedida para evitar que la misma linea se use mas de una vez.
    /// </summary>
    public class DetalleOrdenCompra
    {
        public int IdDetalleOrdenCompra { get; set; }
        public int IdOrdenCompra { get; set; }

        public Producto oProducto { get; set; }

        public decimal Cantidad { get; set; }
        public decimal CantidadFacturada { get; set; }

        public decimal PrecioUnitario { get; set; }
        public decimal IvaPorcentaje { get; set; }

        public decimal TotalLinea { get; set; }
        public decimal TotalLineaIva { get; set; }

        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
    }
}
