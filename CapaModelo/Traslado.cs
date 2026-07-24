using System.Collections.Generic;

namespace CapaModelo
{
    /// <summary>
    /// Encabezado de una solicitud de traslado entre sucursales (flujo 4 pasos).
    ///   Paso 1: Operador DESTINO  crea solicitud        [Solicitado]
    ///   Paso 2: Supervisor ORIGEN aprueba/rechaza        [Aprobado | Rechazado]
    ///   Paso 3: Operador ORIGEN   despacha (stock--)     [Despachado]
    ///   Paso 4: Operador DESTINO  recepciona (stock++)   [Completado]
    /// </summary>
    public class Traslado
    {
        public int    IdTraslado      { get; set; }
        public string Numero          { get; set; }
        public int    IdTiendaOrigen  { get; set; }
        public int    IdTiendaDestino { get; set; }
        public string TiendaOrigen    { get; set; }
        public string TiendaDestino   { get; set; }
        public string EstadoAprobacion { get; set; }
        public string Observaciones   { get; set; }
        public string MotivoRechazo   { get; set; }

        // Paso 1 — Operador DESTINO crea
        public int    IdUsuario      { get; set; }
        public string Usuario        { get; set; }
        public string FechaTraslado  { get; set; }

        // Paso 2 — Supervisor ORIGEN aprueba/rechaza
        public string UsuarioAprueba  { get; set; }
        public string FechaAprobacion { get; set; }

        // Paso 3 — Operador ORIGEN despacha
        public string UsuarioDespacha { get; set; }
        public string FechaDespacho   { get; set; }

        // Paso 4 — Operador DESTINO recepciona
        public string UsuarioRecibe  { get; set; }
        public string FechaRecepcion { get; set; }

        // Resumen (calculado en SP)
        public int CantidadItems   { get; set; }
        public int TotalUnidades   { get; set; }

        // Ítems — solo se cargan en detalle
        public List<TrasladoDetalle> Detalle { get; set; }
    }

    /// <summary>
    /// Ítem de una solicitud de traslado (un producto + cantidad).
    /// </summary>
    public class TrasladoDetalle
    {
        public int    IdTrasladoDetalle { get; set; }
        public int    IdTraslado        { get; set; }
        public int    IdProducto        { get; set; }
        public string CodigoProducto    { get; set; }
        public string NombreProducto    { get; set; }
        public int    Cantidad          { get; set; }
        public int    StockOrigen       { get; set; }   // stock actual en sucursal origen
    }
}
