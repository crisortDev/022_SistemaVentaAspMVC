using System;

namespace CapaModelo
{
    /// <summary>
    /// Representa un comprobante de cobro (Contado = cobrado al instante; Crédito = pendiente hasta que el cliente pague).
    /// </summary>
    public class ComprobanteCobro
    {
        public int     IdComprobanteCobro { get; set; }
        public string  NumeroCobro        { get; set; }
        public int     IdVenta            { get; set; }
        /// <summary>Sucursal dueña del comprobante (para aislamiento por sucursal). 0 = no informado.</summary>
        public int     IdTienda           { get; set; }
        public string  Estado             { get; set; }   // Cobrado | Pendiente
        public decimal MontoTotal         { get; set; }
        public decimal MontoRecibido      { get; set; }
        public decimal MontoCambio        { get; set; }
        public string  FechaRegistro      { get; set; }   // emisión de la factura
        public string  FormaCobro         { get; set; }
        public string  NumeroFactura      { get; set; }
        public string  CodigoVenta        { get; set; }
        public string  NombreCliente      { get; set; }
        public string  NumeroDocumento    { get; set; }
        public string  TelefonoCliente    { get; set; }
        public string  NombreCajero       { get; set; }
        public string  NombreTienda       { get; set; }

        // ── Crédito ─────────────────────────────────────────────────────────
        public string  Condicion          { get; set; }   // Contado | Crédito
        public int?    PlazoCredito       { get; set; }   // 30 | 60
        public string  FechaVencimiento   { get; set; }   // dd/MM/yyyy
        /// <summary>Días que faltan para vencer (negativo = ya vencida)</summary>
        public int?    DiasParaVencer     { get; set; }

        // ── Recibo imprimible ────────────────────────────────────────────────
        /// <summary>Fecha en que se efectuó el cobro (distinto a FechaRegistro para CXC)</summary>
        public string  FechaCobro         { get; set; }
        /// <summary>Nombre del usuario que registró el cobro</summary>
        public string  NombreCobrador     { get; set; }
        /// <summary>Observación del cobro CXC</summary>
        public string  Observacion        { get; set; }
        public string  DireccionTienda    { get; set; }
        public string  TelefonoTienda     { get; set; }
        public string  DireccionCliente   { get; set; }
    }

    /// <summary>
    /// Modelo para registrar el cobro de una factura a crédito.
    /// </summary>
    public class CobroRequest
    {
        public int     IdCompCobro   { get; set; }
        public int     IdFormaCobro  { get; set; }
        public decimal MontoRecibido { get; set; }
        public string  Observacion   { get; set; }
    }
}
