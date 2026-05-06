using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class Compra
    {
        public int IdCompra { get; set; }
        public string Codigo { get; set; }
        public string FechaCompra { get; set; }
        public string NumeroCompra { get; set; }
        public string NumeroFactura { get; set; }

        public string NumeroTimbrado { get; set; }
        public  string FechaVencimientoTimbrado { get; set; }
        public Usuario oUsuario { get; set; }
        public Proveedor oProveedor { get; set; }
        public Tienda oTienda { get; set; }
        public List<DetalleCompra> oListaDetalleCompra { get; set; }
        public decimal TotalCosto { get; set; }
        public decimal TotalCostoIvaIncluido { get; set; }
        public string TipoComprobante { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        // ── Campos de recepción / revisión ────────────────────
        /// <summary>FK a ORDEN_COMPRA origen (0 si no aplica).</summary>
        public int IdOrdenCompra { get; set; }

        /// <summary>Fecha real de la factura del proveedor.</summary>
        public string FechaFactura { get; set; }

        /// <summary>Fecha real en que llegó la mercadería.</summary>
        public string FechaEntrega { get; set; }

        /// <summary>
        /// Pendiente | Recibida | Confirmada | Anulada
        /// </summary>
        public string Estado { get; set; }

        /// <summary>Monto de la NC aplicada (null si no hubo NC).</summary>
        public decimal? MontoNotaCredito { get; set; }

        /// <summary>FK al motivo de NC (null si no hubo NC).</summary>
        public int? IdMotivoNotaCredito { get; set; }

        /// <summary>EnRecepcion | Confirmada (estado del proceso de recepción).</summary>
        public string EstadoRecepcion { get; set; }

        /// <summary>Fecha en que se confirmó la compra y se impactó el stock.</summary>
        public string FechaConfirmacion { get; set; }
    }
}
