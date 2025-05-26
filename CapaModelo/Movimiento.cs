using System;

namespace CapaModelo
{
    public class Movimiento
    {
        public int IdMovimiento { get; set; }
        public string NumeroFactura { get; set; }
        public string NumeroTimbrado { get; set; }
        public DateTime FechaTransaccion { get; set; }
        public decimal MontoOperacion { get; set; }
        public string EstadoPago { get; set; }
        public int IdTienda { get; set; }
        public int IdUsuario { get; set; }
        public int IdProveedor { get; set; }

        // Si quieres incluir datos relacionados (producto, tienda) puedes agregarlos opcionalmente:
        public Producto oProducto { get; set; }
        public Tienda oTienda { get; set; }

        // Puedes agregar más campos según sea necesario
    }
}
