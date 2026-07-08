using System.Collections.Generic;

namespace CapaModelo
{
    // ── RS1: KPIs ────────────────────────────────────────────────────────────────
    public class KPIVentas
    {
        public int     TotalVentas       { get; set; }
        public int     VentasEfectivas   { get; set; }
        public decimal MontoNeto         { get; set; }
        public decimal MontoTotal        { get; set; }
        public decimal MontoNC           { get; set; }
        public int     TotalNC           { get; set; }
        public int     CantidadClientes  { get; set; }
        public decimal TotalUnidades     { get; set; }
        public decimal TicketPromedio    { get; set; }
        public double? VariacionMontoPct { get; set; }
        public double? VariacionVentasPct{ get; set; }
        public decimal MontoAnterior     { get; set; }
        public int     VentasAnterior    { get; set; }
    }

    // ── RS2: Ventas por mes ───────────────────────────────────────────────────────
    public class VentasPorMes
    {
        public int     Anio      { get; set; }
        public int     Mes       { get; set; }
        public string  MesNombre { get; set; }
        public int     Cantidad  { get; set; }
        public decimal MontoTotal{ get; set; }
    }

    // ── RS3: Top productos por unidades ──────────────────────────────────────────
    public class TopProductoVenta
    {
        public int     Ranking          { get; set; }
        public string  Codigo           { get; set; }
        public string  Producto         { get; set; }
        public string  Categoria        { get; set; }
        public decimal UnidadesVendidas { get; set; }
        public decimal MontoTotal       { get; set; }
    }

    // ── RS4: Top productos por utilidad ──────────────────────────────────────────
    public class ProductoUtilidad
    {
        public int     Ranking   { get; set; }
        public string  Codigo    { get; set; }
        public string  Producto  { get; set; }
        public string  Categoria { get; set; }
        public decimal Cantidad  { get; set; }
        public decimal VentaTotal{ get; set; }
        public decimal CostoTotal{ get; set; }
        public decimal Utilidad  { get; set; }
        public double  MargenPct { get; set; }
    }

    // ── RS5: Ventas por tienda ────────────────────────────────────────────────────
    public class VentasPorTienda
    {
        public string  Tienda        { get; set; }
        public int     Cantidad      { get; set; }
        public decimal MontoTotal    { get; set; }
        public double  PorcentajePct { get; set; }
    }

    // ── RS6: Ventas por vendedor ──────────────────────────────────────────────────
    public class VentasPorVendedor
    {
        public string  Vendedor      { get; set; }
        public string  Tienda        { get; set; }
        public int     Cantidad      { get; set; }
        public decimal MontoTotal    { get; set; }
        public decimal TicketPromedio{ get; set; }
    }

    // ── RS7: Top clientes ─────────────────────────────────────────────────────────
    public class TopClienteVenta
    {
        public int     Ranking         { get; set; }
        public string  Cliente         { get; set; }
        public int     CantidadFacturas{ get; set; }
        public decimal MontoTotal      { get; set; }
        public decimal TicketPromedio  { get; set; }
    }

    // ── RS8: Relación con inventario ──────────────────────────────────────────────
    public class InvRelacion
    {
        public string  Tienda               { get; set; }
        public int     ProductosAgotados    { get; set; }
        public int     ProductosBajoStock   { get; set; }
        public int     TotalProductos       { get; set; }
        public int     InventariosAprobados { get; set; }
        public double  PctDiferenciaProm    { get; set; }
    }

    // ── Objeto raíz devuelto al controller ───────────────────────────────────────
    public class ReporteVentasGerencia
    {
        public KPIVentas              KPIs             { get; set; }
        public List<VentasPorMes>     VentasPorMes     { get; set; }
        public List<TopProductoVenta> TopProductos     { get; set; }
        public List<ProductoUtilidad> ProductosUtilidad{ get; set; }
        public List<VentasPorTienda>  VentasPorTienda  { get; set; }
        public List<VentasPorVendedor>VentasPorVendedor{ get; set; }
        public List<TopClienteVenta>  TopClientes      { get; set; }
        public List<InvRelacion>      Inventario       { get; set; }

        public string NombreTienda { get; set; }
        public string FechaInicio  { get; set; }
        public string FechaFin     { get; set; }
    }
}
