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

        // ── Campos de anulación / auditoría ──────────────────
        /// <summary>IdUsuario que confirmó la compra (segregación O&amp;M).</summary>
        public int? IdUsuarioConfirma { get; set; }

        /// <summary>Nombre del usuario que confirmó (para vistas).</summary>
        public string UsuarioConfirma { get; set; }

        /// <summary>Fecha en que se anuló la compra.</summary>
        public string FechaAnulacion { get; set; }

        /// <summary>Motivo de anulación ingresado por el revisor.</summary>
        public string MotivoAnulacion { get; set; }

        /// <summary>Nombre del usuario que registró la compra (para vistas).</summary>
        public string UsuarioRegistro { get; set; }

        /// <summary>Número de la OC vinculada (para vistas de revisión).</summary>
        public string NumeroOrden { get; set; }

        /// <summary>
        /// true si la compra tiene líneas con diferencia (CantidadRecibida &lt; Cantidad)
        /// y aún no se generó una Nota de Crédito. Se usa en la vista Revisión para
        /// mostrar el botón "Generar NC".
        /// </summary>
        public bool NecesitaNC { get; set; }

        /// <summary>
        /// IdOrdenPago generada para esta compra (0 = aún no se generó la OP).
        /// Se usa en la vista Revisión para mostrar/ocultar el botón "Generar OP".
        /// </summary>
        public int IdOrdenPago { get; set; }

        /// <summary>
        /// Estado de la Nota de Crédito de Compra asociada (Pendiente/Recibida/Rechazada/vacío).
        /// Si EstadoNC = 'Pendiente', el botón OP y Ver Documento se deshabilitan.
        /// </summary>
        public string EstadoNC { get; set; }
    }
}
