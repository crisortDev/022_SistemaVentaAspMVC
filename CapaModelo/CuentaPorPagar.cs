using System;

namespace CapaModelo
{
    /// <summary>
    /// Cuota de una Orden de Pago en modalidad Crédito.
    /// Mapea la tabla dbo.CUENTA_POR_PAGAR.
    /// </summary>
    public class CuentaPorPagar
    {
        // ── Identificación ─────────────────────────────────────
        public int    IdCuentaPorPagar  { get; set; }
        public int    NumeroCuota       { get; set; }
        public int    TotalCuotas       { get; set; }

        // ── Relaciones ─────────────────────────────────────────
        public int      IdOrdenPago     { get; set; }
        public string   NumeroOP        { get; set; }
        public int      IdCompra        { get; set; }
        public string   NumeroFactura   { get; set; }
        public string   NumeroCompra    { get; set; }
        public int      IdProveedor     { get; set; }
        public Proveedor oProveedor     { get; set; }
        public Tienda    oTienda        { get; set; }

        // ── Datos financieros ──────────────────────────────────
        public decimal  Monto           { get; set; }

        // ── Ciclo de vida ──────────────────────────────────────
        /// <summary>Pendiente | Pagada | Vencida</summary>
        public string   Estado              { get; set; }
        public DateTime FechaVencimiento    { get; set; }
        public string   FechaVencimientoTexto { get; set; }
        public DateTime? FechaPago          { get; set; }
        public DateTime FechaRegistro       { get; set; }
        public bool     Activo              { get; set; }
    }
}
