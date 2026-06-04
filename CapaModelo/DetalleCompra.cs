using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class DetalleCompra
    {
        public int IdDetalleCompra { get; set; }
        public int IdCompra { get; set; }
        public Producto oProducto { get; set; }
        public decimal Cantidad { get; set; }
        public decimal PrecioUnitarioCompra { get; set; }
        public string TextoPrecioUnitarioCompra { get; set; }
        //public decimal PrecioUnitarioVenta { get; set; }
        public string TextoPrecioUnitarioVenta { get; set; }
        public decimal TotalCosto { get; set; }
        public decimal TotalCostoIvaIncluido  { get; set; }
        public string TextoTotalCosto { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        // ── Campos de recepción ───────────────────────────────
        /// <summary>Cantidad que figura en la factura del proveedor.</summary>
        public decimal CantidadFacturada { get; set; }

        /// <summary>Cantidad efectivamente recibida en el depósito.</summary>
        public decimal CantidadRecibida { get; set; }

        /// <summary>
        /// Aceptada | Rechazada | NotaCredito
        /// </summary>
        public string EstadoLinea { get; set; }
    }
}
