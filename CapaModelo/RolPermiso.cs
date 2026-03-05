using System;
using System.Collections.Generic;

namespace CapaModelo
{
    public class RolPermiso
    {
        public int IdRol { get; set; } // opcional si se va a crear
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        // Nueva propiedad para registrar los permisos asignados
        public List<int> Permisos { get; set; } = new List<int>();
    }
}
