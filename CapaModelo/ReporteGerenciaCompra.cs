using System.Collections.Generic;

namespace CapaModelo
{
    // ── KPIs principales ─────────────────────────────────────────────────────
    public class KPICompras
    {
        public int     TotalCompras       { get; set; }
        public decimal MontoTotalCompras  { get; set; }
        public decimal MontoTotalConIVA   { get; set; }
        public int     Confirmadas        { get; set; }
        public int     EnProceso          { get; set; }
        public int     Anuladas           { get; set; }
        public decimal MontoTotalNC       { get; set; }
        public int     TotalOC            { get; set; }
        public int     OCPendientes       { get; set; }
        public int     OCFueraPlazo       { get; set; }
    }

    // ── OC por estado ────────────────────────────────────────────────────────
    public class OCPorEstado
    {
        public string  Estado      { get; set; }
        public int     Cantidad    { get; set; }
        public decimal MontoTotal  { get; set; }
    }

    // ── Compras por mes ──────────────────────────────────────────────────────
    public class ComprasPorMes
    {
        public int     Anio      { get; set; }
        public int     Mes       { get; set; }
        public string  MesNombre { get; set; }
        public int     Cantidad  { get; set; }
        public decimal Monto     { get; set; }
    }

    // ── Top proveedores ──────────────────────────────────────────────────────
    public class TopProveedorCompra
    {
        public string  Proveedor     { get; set; }
        public int     TotalCompras  { get; set; }
        public decimal MontoTotal    { get; set; }
    }

    // ── Resumen NC ───────────────────────────────────────────────────────────
    public class ResumenNC
    {
        public int     TotalNC     { get; set; }
        public int     Pendientes  { get; set; }
        public int     Recibidas   { get; set; }
        public int     Rechazadas  { get; set; }
        public int     Morosas     { get; set; }
        public decimal MontoTotal  { get; set; }
    }

    // ── OC fuera de plazo ────────────────────────────────────────────────────
    public class OCFueraDePlazo
    {
        public string  NumeroOrden       { get; set; }
        public string  Proveedor         { get; set; }
        public string  Tienda            { get; set; }
        public string  FechaTopeEntrega  { get; set; }
        public decimal MontoEstimado     { get; set; }
        public string  Estado            { get; set; }
        public int     DiasVencida       { get; set; }
    }

    // ── Contenedor completo del reporte ──────────────────────────────────────
    public class ReporteGerenciaCompra
    {
        public KPICompras              KPIs              { get; set; }
        public List<OCPorEstado>       OrdenesPorEstado  { get; set; }
        public List<ComprasPorMes>     ComprasMensuales  { get; set; }
        public List<TopProveedorCompra>TopProveedores    { get; set; }
        public ResumenNC               NotasCredito      { get; set; }
        public List<OCFueraDePlazo>    OCsFueraDePlazo   { get; set; }
        public string                  FechaInicio       { get; set; }
        public string                  FechaFin          { get; set; }
        public string                  NombreTienda      { get; set; }
    }
}
