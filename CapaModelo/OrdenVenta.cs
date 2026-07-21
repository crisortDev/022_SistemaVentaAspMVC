using System;
using System.Collections.Generic;

namespace CapaModelo
{
    public class OrdenVenta
    {
        public int IdOrdenVenta { get; set; }
        public string NumeroOV { get; set; }
        public int IdTienda { get; set; }
        public int? IdCliente { get; set; }
        public int IdUsuarioRegistro { get; set; }
        public decimal TotalEstimado { get; set; }
        public decimal IVA10 { get; set; }
        public decimal IVA5 { get; set; }
        public decimal Exento0 { get; set; }
        public string Estado { get; set; }
        public string Observacion { get; set; }
        public string FechaRegistro { get; set; }
        public string FechaVencimiento { get; set; }
        public string AlertaVencimiento { get; set; }
        public string NombreTienda { get; set; }
        public string NombreUsuario { get; set; }
        public string NombreCliente { get; set; }
        public string DocumentoCliente { get; set; }
        public decimal SaldoFavorCliente { get; set; }
        public string DireccionCliente { get; set; }
        public string TelefonoCliente { get; set; }
        public string TipoDocumentoCliente { get; set; }
        public string RUCTienda { get; set; }
        public List<DetalleOrdenVenta> oDetalle { get; set; }
    }

    public class DetalleOrdenVenta
    {
        public int IdDetalleOV { get; set; }
        public int IdProducto { get; set; }
        public string Codigo { get; set; }
        public string NombreProducto { get; set; }
        public decimal Cantidad { get; set; }
        public decimal PrecioUnidad { get; set; }
        public decimal IvaPorcentaje { get; set; }
        public decimal TotalLinea { get; set; }
        public decimal TotalLineaIva { get; set; }
        public decimal StockDisponible { get; set; }
    }
}
