using System;

namespace CapaModelo
{
    public class Persona
    {
        public int IdPersona { get; set; }
        public string Nombres { get; set; }          // Para persona física
        public string Apellidos { get; set; }        // Para persona física
        public string RazonSocial { get; set; }      // Para persona jurídica
        public string TipoDocumento { get; set; }    // CI, RUC, etc.
        public string Documento { get; set; }        // Número de documento
        public string Ciudad { get; set; }
        public string Barrio { get; set; }
        public string Correo { get; set; }
        public string Telefono { get; set; }
        public string Calle1 { get; set; }
        public string Calle2 { get; set; }
        public DateTime FechaRegistro { get; set; }
        public bool Activo { get; set; }
        public DateTime? FechaBaja { get; set; }
    }
}
