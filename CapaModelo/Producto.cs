using System;

namespace CapaModelo
{
    public class Producto
    {
        public int IdProducto { get; set; }
        public string Codigo { get; set; }
        public int ValorCodigo { get; set; }
        public string Nombre { get; set; }
        public string Descripcion { get; set; }
        public int IdCategoria { get; set; }
        public decimal IvaPorcentaje { get; set; }
        public int StockMaximo { get; set; }
        public Categoria oCategoria { get; set; }
        public bool Activo { get; set; }

        /// <summary>
        /// Unidad de medida para la venta. Sincronizada desde CATEGORIA.
        /// Valores: 'Unidad' (default), 'Metro', 'Kg'.
        /// </summary>
        public string UnidadMedida { get; set; }
    }
}