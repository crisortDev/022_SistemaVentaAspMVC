using System;

namespace CapaModelo
{
    public class ComprobanteCobro
    {
        public int IdComprobanteCobro { get; set; }
        public string NumeroCobro { get; set; }
        public int IdVenta { get; set; }
        public string Estado { get; set; }
        public decimal MontoTotal { get; set; }
        public decimal MontoRecibido { get; set; }
        public decimal MontoCambio { get; set; }
        public string FechaRegistro { get; set; }
        public string FormaCobro { get; set; }
        public string NumeroFactura { get; set; }
        public string CodigoVenta { get; set; }
        public string NombreCliente { get; set; }
        public string NumeroDocumento { get; set; }
        public string NombreCajero { get; set; }
        public string NombreTienda { get; set; }
    }
}
