using System;
using System.Collections.Generic;

namespace CapaModelo
{
    /// <summary>
    /// Orden de Compra: documento interno para aprobar y controlar la
    /// reposicion de stock. Se remite al proveedor para confirmar
    /// cantidades y precios. Es la base para la(s) factura(s) de Compra.
    /// </summary>
    public class OrdenCompra
    {
        // ── Identificacion ────────────────────────────────────
        public int IdOrdenCompra { get; set; }
        public string NumeroOrden { get; set; }

        // ── Relaciones ────────────────────────────────────────
        public Proveedor oProveedor { get; set; }
        public Tienda oTienda { get; set; }
        public Usuario oUsuarioRegistro { get; set; }
        public Usuario oUsuarioAprobador { get; set; }

        // ── Datos de la orden ─────────────────────────────────
        public string FechaOrden { get; set; }
        public string FechaEntregaEstimada { get; set; }
        public string Observacion { get; set; }

        public decimal TotalEstimado { get; set; }
        public decimal TotalEstimadoIva { get; set; }

        // ── Ciclo de vida ────────────────────────────────────
        /// <summary>
        /// Pendiente | Aprobada | Rechazada | Facturada | Cerrada | Anulada
        /// </summary>
        public string Estado { get; set; }
        public string FechaAprobacion { get; set; }
        public string MotivoRechazo { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        // ── Detalle ───────────────────────────────────────────
        public List<DetalleOrdenCompra> oListaDetalle { get; set; }
    }
}
