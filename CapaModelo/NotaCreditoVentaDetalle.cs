namespace CapaModelo
{
    /// <summary>
    /// Línea de detalle de una Nota de Crédito de Venta (NC por cuotas).
    /// Indica qué productos y en qué cantidades cubre la NC.
    /// </summary>
    public class NotaCreditoVentaDetalle
    {
        public int     IdNCVDetalle    { get; set; }
        public int     IdNCVenta       { get; set; }
        public int     IdProducto      { get; set; }
        public string  NombreProducto  { get; set; }
        public decimal Cantidad        { get; set; }
        public decimal PrecioUnitario  { get; set; }
        public decimal TotalLinea      { get; set; }
    }
}
