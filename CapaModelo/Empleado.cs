using System;
namespace CapaModelo
{
    public class Empleado
    {
        public int IdEmpleado { get; set; }          // PK
        public string CI { get; set; }               // Cédula, única
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        public int IdTienda { get; set; }            // FK a Tienda
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }

        // Propiedades de navegación opcionales
        public Tienda oTienda { get; set; }          // para acceder a los datos de la tienda
    }
}
