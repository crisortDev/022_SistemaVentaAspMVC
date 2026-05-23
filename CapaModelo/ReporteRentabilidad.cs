using System;

namespace CapaModelo
{
    /// <summary>
    /// Resultado del reporte de Rentabilidad por Producto (CPP).
    /// Utilizado por usp_rptRentabilidadProducto.
    /// </summary>
    public class ReporteRentabilidad
    {
        public int     IdProducto          { get; set; }
        public string  Codigo              { get; set; }
        public string  Producto            { get; set; }
        public string  Categoria           { get; set; }
        public string  Tienda              { get; set; }
        public int     StockActual         { get; set; }

        /// <summary>Costo Promedio Ponderado calculado en la última confirmación de compra.</summary>
        public decimal CostoPromedio       { get; set; }

        /// <summary>Precio de venta vigente (IVA incluido).</summary>
        public decimal PrecioVentaVigente  { get; set; }

        public int     UnidadesVendidas    { get; set; }
        public decimal IngresosTotales     { get; set; }
        public decimal CostoTotalVentas    { get; set; }
        public decimal UtilidadBruta       { get; set; }

        /// <summary>Margen Bruto en porcentaje: UtilidadBruta / Ingresos * 100.</summary>
        public decimal MargenBrutoPct      { get; set; }

        /// <summary>Valor del inventario actual valorizado al CPP.</summary>
        public decimal ValorInventarioCPP  { get; set; }
    }
}
