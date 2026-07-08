using System.Collections.Generic;

namespace CapaModelo
{
    // ── RS1: KPIs ────────────────────────────────────────────────────────────────
    public class KPICompras
    {
        public int     TotalCompras       { get; set; }
        public decimal MontoTotalCompras  { get; set; }
        public int     Confirmadas        { get; set; }
        public int     Recepcionadas      { get; set; }
        public int     EnProceso          { get; set; }
        public int     Anuladas           { get; set; }
        public decimal GastoPromedio      { get; set; }
        public decimal MontoTotalNC       { get; set; }
        public int     TotalOC            { get; set; }
        public int     OCPendientes       { get; set; }
        public int     OCFueraPlazo       { get; set; }
        public int     ProveedoresActivos { get; set; }
        public int     ProductosComprados { get; set; }
    }

    // ── RS2: Compras por mes ─────────────────────────────────────────────────────
    public class ComprasPorMes
    {
        public int     Anio      { get; set; }
        public int     Mes       { get; set; }
        public string  MesNombre { get; set; }
        public int     Cantidad  { get; set; }
        public decimal Monto     { get; set; }
    }

    // ── RS3: Top proveedores ─────────────────────────────────────────────────────
    public class TopProveedorCompra
    {
        public int     Ranking      { get; set; }
        public string  Proveedor    { get; set; }
        public int     TotalCompras { get; set; }
        public decimal MontoTotal   { get; set; }
        public int     CantidadNC   { get; set; }
    }

    // ── RS4: Productos más comprados ─────────────────────────────────────────────
    public class ProductoComprado
    {
        public int     Ranking       { get; set; }
        public string  Codigo        { get; set; }
        public string  Producto      { get; set; }
        public string  Categoria     { get; set; }
        public decimal CantidadTotal { get; set; }
        public decimal MontoTotal    { get; set; }
    }

    // ── RS5: OC por estado ───────────────────────────────────────────────────────
    public class OCPorEstado
    {
        public string  Estado     { get; set; }
        public int     Cantidad   { get; set; }
        public decimal MontoTotal { get; set; }
    }

    // ── RS6: Compras por tienda ──────────────────────────────────────────────────
    public class ComprasPorTienda
    {
        public string  Tienda          { get; set; }
        public int     CantidadCompras { get; set; }
        public decimal MontoTotal      { get; set; }
        public double  PorcentajePct   { get; set; }
    }

    // ── RS7: Relación Compras vs Ventas ──────────────────────────────────────────
    public class RelacionComprasVentas
    {
        public decimal TotalCompras { get; set; }
        public decimal TotalVentas  { get; set; }
    }

    // ── RS8: Resumen NC ──────────────────────────────────────────────────────────
    public class ResumenNC
    {
        public int     TotalNC    { get; set; }
        public int     Pendientes { get; set; }
        public int     Recibidas  { get; set; }
        public int     Rechazadas { get; set; }
        public int     Morosas    { get; set; }
        public decimal MontoTotal { get; set; }
    }

    // ── OC fuera de plazo (conservado para compatibilidad) ───────────────────────
    public class OCFueraDePlazo
    {
        public string  NumeroOrden      { get; set; }
        public string  Proveedor        { get; set; }
        public string  Tienda           { get; set; }
        public string  FechaTopeEntrega { get; set; }
        public decimal MontoEstimado    { get; set; }
        public string  Estado           { get; set; }
        public int     DiasVencida      { get; set; }
    }

    // ── Contenedor completo ──────────────────────────────────────────────────────
    public class ReporteGerenciaCompra
    {
        public KPICompras                KPIs              { get; set; }
        public List<ComprasPorMes>       ComprasMensuales  { get; set; }
        public List<TopProveedorCompra>  TopProveedores    { get; set; }
        public List<ProductoComprado>    TopProductos      { get; set; }
        public List<OCPorEstado>         OrdenesPorEstado  { get; set; }
        public List<ComprasPorTienda>    ComprasPorTienda  { get; set; }
        public RelacionComprasVentas     RelacionCV        { get; set; }
        public ResumenNC                 NotasCredito      { get; set; }
        // Conservado para compatibilidad (ya no lo usa el SP pero puede usarse en otro lado)
        public List<OCFueraDePlazo>      OCsFueraDePlazo   { get; set; }
        public string                    FechaInicio       { get; set; }
        public string                    FechaFin          { get; set; }
        public string                    NombreTienda      { get; set; }
    }
}
