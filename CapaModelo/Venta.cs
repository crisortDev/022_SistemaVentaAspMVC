using System;
using System.Collections.Generic;

namespace CapaModelo
{
    public class Venta
    {
        public int IdVenta { get; set; }
        public string TipoDocumento { get; set; }
        public string TipoFlujo { get; set; }       // Directa | PreVenta
        public string Estado { get; set; }           // Activa | Anulada
        public string Codigo { get; set; }
        public decimal TotalCosto { get; set; }
        public string TextoTotalCosto { get; set; }
        public decimal ImporteRecibido { get; set; }
        public string TextoImporteRecibido { get; set; }
        public decimal ImporteCambio { get; set; }
        public string TextoImporteCambio { get; set; }
        public string FechaRegistro { get; set; }
        public string NumeroFactura { get; set; }
        public string NumeroTimbrado { get; set; }
        public string VencimientoTimbrado { get; set; }
        public decimal ImporteTotalIvaIncluido { get; set; }
        // IVA desglosado Paraguay
        public decimal IVA10 { get; set; }
        public decimal IVA5 { get; set; }
        public decimal Exento0 { get; set; }
        public decimal Gravado10 { get; set; }
        public decimal Gravado5Base { get; set; }
        // Datos tributarios SET
        public string Establecimiento { get; set; }
        public string PuntoExpedicion { get; set; }
        // Forma de cobro y flujo
        public string FormaCobro { get; set; }
        public string NumeroOV { get; set; }
        // Resumen para lista
        public string NombreCliente { get; set; }
        public string DocumentoCliente { get; set; }
        public string NombreUsuario { get; set; }
        public string NombreTienda { get; set; }
        // Condición de venta (Contado | Crédito)
        public string Condicion { get; set; }
        public int? PlazoCredito { get; set; }
        public string FechaVencimientoCredito { get; set; }
        // Modalidad de pago (Efectivo | Transferencia | Crédito)
        public string ModalidadPago { get; set; }
        public string NumeroTransferencia { get; set; }
        public int? NumeroCuotas { get; set; }
        public decimal? MontoFinanciado { get; set; }
        public decimal? RecargoCredito { get; set; }
        public decimal SaldoFavorAplicado { get; set; }
        // Datos KuDE
        public string NombreCajero { get; set; }
        public string NombreEmisor { get; set; }
        public string RUCEmisor { get; set; }
        public string DireccionEmisor { get; set; }
        public string TelefonoEmisor { get; set; }
        public DateTime VFechaRegistro { get; set; }
        // Objetos relacionados
        public Usuario oUsuario { get; set; }
        public Tienda oTienda { get; set; }
        public Cliente oCliente { get; set; }
        public List<DetalleVenta> oListaDetalleVenta { get; set; }
    }

    public class DatosTributarios
    {
        public string NumeroTimbrado        { get; set; }
        public string VencimientoTimbrado   { get; set; }
        public string Establecimiento       { get; set; }
        public string PuntoExpedicion       { get; set; }
        public int    SecuenciaActual       { get; set; }
        public string ProximoNumeroFactura  { get; set; }
        // Campos adicionales para el CRUD de Parametrización Tributaria
        public string RazonSocial           { get; set; }
        public int    DiasParaVencer        { get; set; }
        public string EstadoTimbrado        { get; set; }  // VIGENTE / POR VENCER / VENCIDO
    }

    public class FormaCobro
    {
        public int IdFormaCobro { get; set; }
        public string Nombre { get; set; }
        public bool Activo { get; set; }
    }

    public class CuotaCobro
    {
        public int IdCuotaCobro { get; set; }
        public int IdVenta { get; set; }
        public string NumeroFactura { get; set; }
        public int NumeroCuota { get; set; }
        public int TotalCuotas { get; set; }
        public decimal MontoFinanciado { get; set; }
        public decimal Monto { get; set; }
        public string FechaVencimiento { get; set; }
        public string Estado { get; set; }             // Pendiente | Pagada | Vencida
        public string FechaPago { get; set; }
        public decimal? MontoRecibido { get; set; }
        public int IdCliente { get; set; }
        public string NombreCliente { get; set; }
        public string DocumentoCliente { get; set; }
        public int IdTienda { get; set; }
        public string NombreTienda { get; set; }
        public int DiasParaVencer { get; set; }
    }
}
