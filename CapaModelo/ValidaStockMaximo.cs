using System.Collections.Generic;
using System.Xml.Serialization;

namespace CapaModelo
{
    using System.Xml.Serialization;
    public class ValidaStockMaximo
    {
        [XmlRoot("DETALLE")]
        public class DetalleRoot
        {
            [XmlElement("COMPRA")]
            public Compra Compra { get; set; }

            [XmlElement("DETALLE_COMPRA")]
            public DetalleCompra DetalleCompra { get; set; }
        }

        public class Compra
        {
            [XmlElement("IdUsuario")]
            public string IdUsuario { get; set; }

            [XmlElement("IdProveedor")]
            public int IdProveedor { get; set; }

            [XmlElement("IdTienda")]
            public int IdTienda { get; set; }

            [XmlElement("NumeroFactura")]
            public string NumeroFactura { get; set; }

            [XmlElement("NumeroTimbrado")]
            public string NumeroTimbrado { get; set; }

            [XmlElement("FechaVencimientoTimbrado")]
            public string FechaVencimientoTimbrado { get; set; }

            [XmlElement("TotalCosto")]
            public decimal TotalCosto { get; set; }
        }

        public class DetalleCompra
        {
            [XmlElement("DETALLE")]
            public Detalle Detalle { get; set; }
        }

        public class Detalle
        {
            [XmlElement("IdCompra")]
            public int IdCompra { get; set; }

            [XmlElement("IdProducto")]
            public int IdProducto { get; set; }

            [XmlElement("Cantidad")]
            public int Cantidad { get; set; }

            [XmlElement("PrecioUnidadCompra")]
            public decimal PrecioUnidadCompra { get; set; }

            [XmlElement("PrecioUnidadVenta")]
            public string PrecioUnidadVenta { get; set; } // Usamos string por el valor "NaN"
            [XmlElement("TotalCosto")]
            public decimal TotalCosto { get; set; }
        }
    }
}