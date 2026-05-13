using System;

namespace CapaModelo
{
    public class NotaCreditoVenta
    {
        public int IdNCVenta { get; set; }
        public string NumeroNCV { get; set; }
        public int IdVenta { get; set; }
        public int IdMotivoNC { get; set; }
        public decimal Monto { get; set; }
        public string Estado { get; set; }
        public string Observacion { get; set; }
        public int IdUsuarioRegistro { get; set; }
        public string FechaRegistro { get; set; }
        public string FechaAprobacion { get; set; }
        public string MotivoRechazo { get; set; }
        public string NumeroFactura { get; set; }
        public string CodigoVenta { get; set; }
        public string NombreCliente { get; set; }
        public string NumeroDocumento { get; set; }
        public string MotivoNC { get; set; }
        public string NombreRegistro { get; set; }
        public string NombreTienda { get; set; }
    }
}
