using System;

namespace CapaModelo
{
    /// <summary>
    /// Representa una sesión de caja (apertura → cierre).
    /// </summary>
    public class SesionCaja
    {
        public int      IdCaja          { get; set; }
        public int      IdTienda        { get; set; }
        public string   NombreTienda    { get; set; }
        public int      IdUsuario       { get; set; }
        public string   NombreUsuario   { get; set; }
        public DateTime FechaApertura   { get; set; }
        public decimal  MontoApertura   { get; set; }
        public DateTime?FechaCierre     { get; set; }
        public string   Cierre          { get; set; }
        public decimal? MontoSistema    { get; set; }
        public decimal? MontoContado    { get; set; }
        public decimal? Diferencia      { get; set; }
        public string   Estado          { get; set; }
        public string   Observacion     { get; set; }

        // Calculados en tiempo real (solo caja abierta)
        public decimal  TotalVentas     { get; set; }
        public int      CantidadVentas  { get; set; }
    }

    /// <summary>
    /// Representa una operación individual dentro de una sesión de caja.
    /// </summary>
    public class OperacionCaja
    {
        public int      IdVenta         { get; set; }
        public string   NumeroFactura   { get; set; }
        public DateTime FechaRegistro   { get; set; }
        public string   NombreCliente   { get; set; }
        public string   FormaCobro      { get; set; }
        public decimal  Monto           { get; set; }
        public decimal  MontoRecibido   { get; set; }
        public decimal  MontoCambio     { get; set; }
        public string   NombreCajero    { get; set; }
        public string   Estado          { get; set; }
    }

    /// <summary>
    /// Resumen por forma de cobro al cierre de caja.
    /// </summary>
    public class ResumenFormaCobro
    {
        public string   FormaCobro  { get; set; }
        public int      Cantidad    { get; set; }
        public decimal  TotalMonto  { get; set; }
    }
}
