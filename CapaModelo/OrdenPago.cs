using System;

namespace CapaModelo
{
    /// <summary>
    /// Orden de Pago generada automáticamente al confirmar una Compra.
    /// Mapea la tabla dbo.ORDEN_PAGO.
    /// </summary>
    public class OrdenPago
    {
        // ── Identificacion ─────────────────────────────────────
        public int    IdOrdenPago       { get; set; }
        public string NumeroOP          { get; set; }

        // ── Relaciones ─────────────────────────────────────────
        public int    IdCompra          { get; set; }
        public Compra oCompra           { get; set; }

        public Proveedor oProveedor     { get; set; }
        public Tienda    oTienda        { get; set; }
        public Usuario   oUsuarioEmite  { get; set; }

        // ── Datos financieros ──────────────────────────────────
        public decimal Monto            { get; set; }

        // ── Modalidad de pago ──────────────────────────────────
        /// <summary>Contado | Credito</summary>
        public string ModalidadPago     { get; set; }
        public int?   NumeroCuotas      { get; set; }

        // ── Aprobación supervisor ──────────────────────────────
        /// <summary>Pendiente | Aprobada | Rechazada</summary>
        public string   EstadoAprobacion     { get; set; }
        public int?     IdUsuarioAprobador   { get; set; }
        public Usuario  oUsuarioAprobador    { get; set; }
        public DateTime? FechaAprobacion     { get; set; }
        public string   MotivoRechazo        { get; set; }

        // ── Ciclo de vida ──────────────────────────────────────
        /// <summary>Emitida | Pagada | Anulada</summary>
        public string   Estado          { get; set; }
        public DateTime FechaEmision    { get; set; }
        public string   FechaEmisionTexto { get; set; }
        public bool     Activo          { get; set; }
    }
}
