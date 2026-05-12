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
        /// Llama a usp_ReporteGerenciaCompras y lee los 6 result sets en una sola conexión.
        /// </summary>
        public ReporteGerenciaCompra ObtenerReporte(DateTime fechaInicio, DateTime fechaFin, int idTienda = 0)
        {
            var reporte = new ReporteGerenciaCompra
            {
                KPIs             = new KPICompras(),
                OrdenesPorEstado = new List<OCPorEstado>(),
                ComprasMensuales = new List<ComprasPorMes>(),
                TopProveedores   = new List<TopProveedorCompra>(),
                NotasCredito     = new ResumenNC(),
                OCsFueraDePlazo  = new List<OCFueraDePlazo>(),
                FechaInicio      = fechaInicio.ToString("dd/MM/yyyy"),
                FechaFin         = fechaFin.ToString("dd/MM/yyyy")
            };

            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    var cmd = new SqlCommand("usp_ReporteGerenciaCompras", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = fechaInicio.Date;
                    cmd.Parameters.Add("@FechaFin",    SqlDbType.Date).Value = fechaFin.Date;
                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        // ── RS1: KPIs ───────────────────────────────────────
                        if (dr.Read())
                        {
                            reporte.KPIs = new KPICompras
                            {
                                TotalCompras      = L<int>(dr,     "TotalCompras"),
                                MontoTotalCompras = L<decimal>(dr, "MontoTotalCompras"),
                                MontoTotalConIVA  = L<decimal>(dr, "MontoTotalConIVA"),
                                Confirmadas       = L<int>(dr,     "Confirmadas"),
                                EnProceso         = L<int>(dr,     "EnProceso"),
                                Anuladas          = L<int>(dr,     "Anuladas"),
                                MontoTotalNC      = L<decimal>(dr, "MontoTotalNC"),
                                TotalOC           = L<int>(dr,     "TotalOC"),
                                OCPendientes      = L<int>(dr,     "OCPendientes"),
                                OCFueraPlazo      = L<int>(dr,     "OCFueraPlazo")
                            };
                        }

                        // ── RS2: OC por estado ──────────────────────────────
                        dr.NextResult();
                        while (dr.Read())
                        {
                            reporte.OrdenesPorEstado.Add(new OCPorEstado
                            {
                                Estado     = dr["Estado"].ToString(),
                                Cantidad   = L<int>(dr,     "Cantidad"),
                                MontoTotal = L<decimal>(dr, "MontoTotal")
                            });
                        }

                        // ── RS3: Compras por mes ────────────────────────────
                        dr.NextResult();
                        while (dr.Read())
                        {
                            reporte.ComprasMensuales.Add(new ComprasPorMes
                            {
                                Anio      = L<int>(dr,     "Anio"),
                                Mes       = L<int>(dr,     "Mes"),
                                MesNombre = dr["MesNombre"].ToString(),
                                Cantidad  = L<int>(dr,     "Cantidad"),
                                Monto     = L<decimal>(dr, "Monto")
                            });
                        }

                        // ── RS4: Top proveedores ────────────────────────────
                        dr.NextResult();
                        while (dr.Read())
                        {
                            reporte.TopProveedores.Add(new TopProveedorCompra
                            {
                                Proveedor    = dr["Proveedor"].ToString(),
                                TotalCompras = L<int>(dr,     "TotalCompras"),
                                MontoTotal   = L<decimal>(dr, "MontoTotal")
                            });
                        }

                        // ── RS5: Resumen NC ─────────────────────────────────
                        dr.NextResult();
                        if (dr.Read())
                        {
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

                        // ── RS6: OCs fuera de plazo ─────────────────────────
                        dr.NextResult();
                        while (dr.Read())
                        {
                            reporte.OCsFueraDePlazo.Add(new OCFueraDePlazo
                            {
                                NumeroOrden      = dr["NumeroOrden"].ToString(),
                                Proveedor        = dr["Proveedor"].ToString(),
                                Tienda           = dr["Tienda"].ToString(),
                                FechaTopeEntrega = dr["FechaTopeEntrega"].ToString(),
                                MontoEstimado    = L<decimal>(dr, "MontoEstimado"),
                                Estado           = dr["Estado"].ToString(),
                                DiasVencida      = L<int>(dr, "DiasVencida")
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    // En caso de error devolver reporte vacío (el controller loguea)
                    throw new Exception("Error al generar reporte de gerencia: " + ex.Message, ex);
                }
            }

            return reporte;
        }

        // ── Helper genérico defensivo ─────────────────────────────────────────
        private static T L<T>(SqlDataReader dr, string col)
        {
            try
            {
                var v = dr[col];
                if (v == DBNull.Value) return default(T);
                return (T)Convert.ChangeType(v, typeof(T));
            }
            catch { return default(T); }
        }
    }
}
