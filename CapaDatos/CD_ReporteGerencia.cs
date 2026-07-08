using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_ReporteGerencia
    {
        private static CD_ReporteGerencia _instancia;
        private CD_ReporteGerencia() { }
        public static CD_ReporteGerencia Instancia
        {
            get { if (_instancia == null) _instancia = new CD_ReporteGerencia(); return _instancia; }
        }

        /// <summary>
        /// Llama a usp_ReporteGerenciaCompras y lee los 8 result sets.
        /// </summary>
        public ReporteGerenciaCompra ObtenerReporte(DateTime fechaInicio, DateTime fechaFin, int idTienda = 0)
        {
            var reporte = new ReporteGerenciaCompra
            {
                KPIs             = new KPICompras(),
                ComprasMensuales = new List<ComprasPorMes>(),
                TopProveedores   = new List<TopProveedorCompra>(),
                TopProductos     = new List<ProductoComprado>(),
                OrdenesPorEstado = new List<OCPorEstado>(),
                ComprasPorTienda = new List<ComprasPorTienda>(),
                RelacionCV       = new RelacionComprasVentas(),
                NotasCredito     = new ResumenNC(),
                OCsFueraDePlazo  = new List<OCFueraDePlazo>(),
                FechaInicio      = fechaInicio.ToString("dd/MM/yyyy"),
                FechaFin         = fechaFin.ToString("dd/MM/yyyy")
            };

            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    var cmd = new SqlCommand("usp_ReporteGerenciaCompras", cn)
                    {
                        CommandType    = CommandType.StoredProcedure,
                        CommandTimeout = 60
                    };
                    cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = fechaInicio.Date;
                    cmd.Parameters.Add("@FechaFin",    SqlDbType.Date).Value = fechaFin.Date;
                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        // ── RS1: KPIs ─────────────────────────────────────────
                        if (dr.Read())
                        {
                            reporte.KPIs = new KPICompras
                            {
                                TotalCompras       = L<int>(dr,     "TotalCompras"),
                                MontoTotalCompras  = L<decimal>(dr, "MontoTotalCompras"),
                                Confirmadas        = L<int>(dr,     "Confirmadas"),
                                Recepcionadas      = L<int>(dr,     "Recepcionadas"),
                                EnProceso          = L<int>(dr,     "EnProceso"),
                                Anuladas           = L<int>(dr,     "Anuladas"),
                                GastoPromedio      = L<decimal>(dr, "GastoPromedio"),
                                MontoTotalNC       = L<decimal>(dr, "MontoTotalNC"),
                                TotalOC            = L<int>(dr,     "TotalOC"),
                                OCPendientes       = L<int>(dr,     "OCPendientes"),
                                OCFueraPlazo       = L<int>(dr,     "OCFueraPlazo"),
                                ProveedoresActivos = L<int>(dr,     "ProveedoresActivos"),
                                ProductosComprados = L<int>(dr,     "ProductosComprados")
                            };
                        }

                        // ── RS2: Compras por mes ──────────────────────────────
                        if (dr.NextResult())
                            while (dr.Read())
                                reporte.ComprasMensuales.Add(new ComprasPorMes
                                {
                                    Anio      = L<int>(dr,     "Anio"),
                                    Mes       = L<int>(dr,     "Mes"),
                                    MesNombre = L<string>(dr,  "MesNombre"),
                                    Cantidad  = L<int>(dr,     "Cantidad"),
                                    Monto     = L<decimal>(dr, "Monto")
                                });

                        // ── RS3: Top proveedores ──────────────────────────────
                        if (dr.NextResult())
                            while (dr.Read())
                                reporte.TopProveedores.Add(new TopProveedorCompra
                                {
                                    Ranking      = L<int>(dr,     "Ranking"),
                                    Proveedor    = L<string>(dr,  "Proveedor"),
                                    TotalCompras = L<int>(dr,     "TotalCompras"),
                                    MontoTotal   = L<decimal>(dr, "MontoTotal"),
                                    CantidadNC   = L<int>(dr,     "CantidadNC")
                                });

                        // ── RS4: Top productos ────────────────────────────────
                        if (dr.NextResult())
                            while (dr.Read())
                                reporte.TopProductos.Add(new ProductoComprado
                                {
                                    Ranking       = L<int>(dr,     "Ranking"),
                                    Codigo        = L<string>(dr,  "Codigo"),
                                    Producto      = L<string>(dr,  "Producto"),
                                    Categoria     = L<string>(dr,  "Categoria"),
                                    CantidadTotal = L<decimal>(dr, "CantidadTotal"),
                                    MontoTotal    = L<decimal>(dr, "MontoTotal")
                                });

                        // ── RS5: Estado OC ────────────────────────────────────
                        if (dr.NextResult())
                            while (dr.Read())
                                reporte.OrdenesPorEstado.Add(new OCPorEstado
                                {
                                    Estado     = L<string>(dr,  "Estado"),
                                    Cantidad   = L<int>(dr,     "Cantidad"),
                                    MontoTotal = L<decimal>(dr, "MontoTotal")
                                });

                        // ── RS6: Compras por tienda ───────────────────────────
                        if (dr.NextResult())
                            while (dr.Read())
                                reporte.ComprasPorTienda.Add(new ComprasPorTienda
                                {
                                    Tienda          = L<string>(dr,  "Tienda"),
                                    CantidadCompras = L<int>(dr,     "CantidadCompras"),
                                    MontoTotal      = L<decimal>(dr, "MontoTotal"),
                                    PorcentajePct   = L<double>(dr,  "PorcentajePct")
                                });

                        // ── RS7: Relación Compras vs Ventas ───────────────────
                        if (dr.NextResult() && dr.Read())
                            reporte.RelacionCV = new RelacionComprasVentas
                            {
                                TotalCompras = L<decimal>(dr, "TotalCompras"),
                                TotalVentas  = L<decimal>(dr, "TotalVentas")
                            };

                        // ── RS8: Resumen NC ───────────────────────────────────
                        if (dr.NextResult() && dr.Read())
                            reporte.NotasCredito = new ResumenNC
                            {
                                TotalNC    = L<int>(dr,     "TotalNC"),
                                Pendientes = L<int>(dr,     "Pendientes"),
                                Recibidas  = L<int>(dr,     "Recibidas"),
                                Rechazadas = L<int>(dr,     "Rechazadas"),
                                Morosas    = L<int>(dr,     "Morosas"),
                                MontoTotal = L<decimal>(dr, "MontoTotal")
                            };
                    }
                }
                catch (Exception ex)
                {
                    throw new Exception("Error al generar reporte de gerencia: " + ex.Message, ex);
                }
            }
            return reporte;
        }

        // ── Helper genérico defensivo ─────────────────────────────────────────────
        private static T L<T>(IDataReader dr, string col)
        {
            try
            {
                int ord = dr.GetOrdinal(col);
                if (dr.IsDBNull(ord)) return default(T);
                object v = dr.GetValue(ord);
                if (typeof(T) == typeof(double) || typeof(T) == typeof(double?))
                    return (T)(object)Convert.ToDouble(v);
                return (T)Convert.ChangeType(v, Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T));
            }
            catch { return default(T); }
        }
    }
}
