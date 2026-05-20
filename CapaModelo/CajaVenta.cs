using System;
using System.Collections.Generic;

namespace CapaModelo
{
    /// <summary>
    /// Cabecera completa de una sesión de caja (para Comprobante de Apertura y Arqueo de Cierre).
    /// </summary>
    public class DetalleCaja
    {
        // ── Datos de la sesión ──
        public int       IdCaja          { get; set; }
        public int       IdTienda        { get; set; }
        public string    NombreTienda    { get; set; }
        public string    DireccionTienda { get; set; }
        public string    TelefonoTienda  { get; set; }
        public string    Aperturista     { get; set; }
        public DateTime  FechaApertura   { get; set; }
        public decimal   MontoApertura   { get; set; }
        public DateTime? FechaCierre     { get; set; }
        public string    UsuarioCierre   { get; set; }
        public decimal   MontoSistema    { get; set; }
        public decimal   MontoContado    { get; set; }
        public decimal   Diferencia      { get; set; }
        public string    Estado          { get; set; }
        public string    Observacion     { get; set; }
        // ── Datos empresa / tributarios ──
        public string    RazonSocial     { get; set; }
        public string    NumeroTimbrado  { get; set; }
        public string    Establecimiento { get; set; }
        public string    PuntoExpedicion { get; set; }
        // ── Totales calculados ──
        public int       CantidadVentas  { get; set; }
        public decimal   TotalVentas     { get; set; }
        // ── Listas adjuntas ──
        public List<OperacionCaja>    Operaciones { get; set; } = new List<OperacionCaja>();
        public List<ResumenFormaCobro> Resumen    { get; set; } = new List<ResumenFormaCobro>();
    }


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
