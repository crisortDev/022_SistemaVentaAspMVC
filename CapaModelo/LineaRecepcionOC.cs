namespace CapaModelo
{
    /// <summary>
    /// DTO para las líneas del formulario de Recepción desde OC.
    /// Contiene el ID del detalle de la OC y la cantidad físicamente recibida.
    /// </summary>
    public class LineaRecepcionOC
    {
        public int IdDetalleOC      { get; set; }
        public int CantidadRecibida { get; set; }
    }
}
