using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    /// <summary>
    /// Representa una solicitud de traslado de mercadería entre sucursales.
    /// Flujo (5 pasos):
    ///   Solicitado → AprobadoSolicitud → Despachado → EnRecepcion → Completado
    /// Rechazos:
    ///   RechazadoDestino (Paso 2) | RechazadoOrigen (Paso 3)
    /// </summary>
    public class Traslado
    {
        public int    IdTraslado       { get; set; }
        public string Numero           { get; set; }
        public int    IdProducto       { get; set; }
        public int    IdTiendaOrigen   { get; set; }
        public int    IdTiendaDestino  { get; set; }
        public decimal Cantidad        { get; set; }
        public string Observaciones    { get; set; }
        public int    IdUsuario        { get; set; }
        public string FechaTraslado    { get; set; }

        // Datos de visualización
        public string NombreProducto  { get; set; }
        public string CodigoProducto  { get; set; }
        public string TiendaOrigen    { get; set; }
        public string TiendaDestino   { get; set; }
        public string Usuario         { get; set; }   // quien creó la solicitud (Operador DESTINO)

        // Estado actual
        public string EstadoAprobacion { get; set; }
        public string MotivoRechazo    { get; set; }

        // Paso 2 — Supervisor DESTINO aprueba/rechaza solicitud
        public string UsuarioAprobSolicitud { get; set; }
        public string FechaAprobSolicitud   { get; set; }

        // Paso 3 — Supervisor ORIGEN autoriza despacho (reutiliza columnas UsuarioAprueba/FechaAprobacion)
        public string UsuarioAprueba  { get; set; }
        public string FechaAprobacion { get; set; }

        // Paso 4 — Operador DESTINO registra llegada física (reutiliza IdUsuarioRecibe/FechaRecepcion)
        public string UsuarioRecibe  { get; set; }
        public string FechaRecepcion { get; set; }

        // Paso 5 — Supervisor DESTINO aprueba recepción final → stock mueve
        public string UsuarioAprobFinal { get; set; }
        public string FechaAprobFinal   { get; set; }
    }
}
