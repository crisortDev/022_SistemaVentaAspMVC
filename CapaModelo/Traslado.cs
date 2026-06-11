using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class Traslado
    {
        public int IdTraslado { get; set; }
        public int IdProducto { get; set; }
        public int IdTiendaOrigen { get; set; }
        public int IdTiendaDestino { get; set; }
        public decimal Cantidad { get; set; }
        public string Observaciones { get; set; }
        public int IdUsuario { get; set; }
        public string FechaTraslado { get; set; }

        public string NombreProducto { get; set; }
        public string CodigoProducto { get; set; }
        public string TiendaOrigen { get; set; }
        public string TiendaDestino { get; set; }
        public string Usuario { get; set; }

        // Flujo de aprobación
        public string EstadoAprobacion { get; set; }
        public string UsuarioAprueba { get; set; }
        public string FechaAprobacion { get; set; }
        public string MotivoRechazo { get; set; }
        public int IdTiendaDestino2 => IdTiendaDestino; // alias para binding JS
    }
}
