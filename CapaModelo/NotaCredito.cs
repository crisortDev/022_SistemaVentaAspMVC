using System;

namespace CapaModelo
{
    /// <summary>
    /// Representa una Nota de Crédito formal (formato SET Paraguay)
    /// emitida por el proveedor cuando hubo diferencia entre lo pedido y lo recibido.
    /// </summary>
    public class NotaCredito
    {
        // ── Identificadores ──────────────────────────────────────────────
        public int    IdNC     { get; set; }
        public int    IdCompra { get; set; }

        // ── Datos de la factura de origen ────────────────────────────────
        public string NumeroFactura { get; set; }
        public string FechaFactura  { get; set; }
        public decimal MontoFactura { get; set; }

        // ── Datos del documento fiscal NC ───────────────────────────────
        /// <summary>Número de Nota de Crédito en formato SET PY: xxx-xxx-xxxxxxx</summary>
        public string NumeroNC          { get; set; }
        public string NumeroTimbrado    { get; set; }
        public string FechaVencTimbrado { get; set; }
        /// <summary>Fecha en que el proveedor emitió la NC.</summary>
        public string FechaEmision      { get; set; }

        // ── Importes ─────────────────────────────────────────────────────
        public decimal MontoNC { get; set; }

        // ── Estado del ciclo de vida ─────────────────────────────────────
        /// <summary>Pendiente | Recibida | Rechazada</summary>
        public string Estado { get; set; }

        // ── Datos calculados para la vista ───────────────────────────────
        /// <summary>true cuando Estado='Pendiente' y han pasado más de 30 días desde FechaFactura.</summary>
        public bool EsMorosa         { get; set; }
        public int  DiasTranscurridos { get; set; }

        // ── Observación y auditoría ──────────────────────────────────────
        public string Observacion      { get; set; }
        public string FechaRegistro    { get; set; }
        public string FechaConfirmacion { get; set; }
        public string UsuarioRegistro  { get; set; }

        // ── Relaciones para la vista ─────────────────────────────────────
        public string MotivoNC   { get; set; }
        public string Proveedor  { get; set; }
        public string RucProveedor { get; set; }
        public string Tienda     { get; set; }
    }
}
