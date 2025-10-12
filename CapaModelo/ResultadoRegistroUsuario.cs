using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public class ResultadoRegistroUsuario
    {
        public string TipoMensaje { get; set; }   // "OK" o "ERROR"
        public string Mensaje { get; set; }       // texto del mensaje
        public int IdUsuario { get; set; }
        public string OTP { get; set; }
        public DateTime? Expira { get; set; }
    }
}
