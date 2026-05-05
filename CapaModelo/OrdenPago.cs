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

        // ── Ciclo de vida ──────────────────────────────────────
        /// <summary>
        /// Pendiente | Pagada | Anulada
        /// </summary>
        public string   Estado          { get; set; }
        public DateTime FechaEmision    { get; set; }
        public string   FechaEmisionTexto { get; set; }
        public bool     Activo          { get; set; }
    }
}
