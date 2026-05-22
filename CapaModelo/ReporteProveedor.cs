using System;

namespace CapaModelo
{
    /// <summary>
    /// Resumen de compras y notas de crédito por proveedor,
    /// usado en el Reporte de Proveedores (punto j del plan de tesis).
    /// </summary>
    public class ReporteProveedor
    {
        public int    IdProveedor     { get; set; }
        public string Proveedor       { get; set; }
        public string RucProveedor    { get; set; }
        public string Telefono        { get; set; }
        public string Correo          { get; set; }

        // ── Compras en el período ──────────────────────────────
        public int     CantidadCompras { get; set; }
        public decimal TotalCompras    { get; set; }

        // ── Notas de Crédito ──────────────────────────────────
        public int     CantidadNC       { get; set; }
        public decimal TotalMontoNC     { get; set; }

        public int     NCPendientes     { get; set; }
        public decimal MontoNCPendiente { get; set; }

        public int     NCRecibidas      { get; set; }
        public int     NCRechazadas     { get; set; }

        // ── Monto neto (Compras − NC recibidas) ───────────────
        public decimal MontoNeto        { get; set; }

        // ── Indicadores de riesgo ─────────────────────────────
        /// <summary>true cuando hay al menos una NC Pendiente con más de 30 días.</summary>
        public bool TieneMorosa         { get; set; }
    }
}
