using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;

namespace CapaDatos
{
    public class CD_ReporteVentasGerencia
    {
        private static CD_ReporteVentasGerencia _instancia;
        private CD_ReporteVentasGerencia() { }
        public static CD_ReporteVentasGerencia Instancia
        {
            get { if (_instancia == null) _instancia = new CD_ReporteVentasGerencia(); return _instancia; }
        }

        // ── Helper: leer valor con safe cast ─────────────────────────────────────
        private static T L<T>(IDataReader dr, string col)
        {
            try
            {
                int ord = dr.GetOrdinal(col);
                if (dr.IsDBNull(ord)) return default(T);
                object v = dr.GetValue(ord);
                if (typeof(T) == typeof(double?) || typeof(T) == typeof(double))
                    return (T)(object)Convert.ToDouble(v);
                return (T)Convert.ChangeType(v, Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T));
            }
            catch { return default(T); }
        }

        /// <summary>
        /// Llama a usp_ReporteVentasGerencia y lee los 8 result sets.
        /// </summary>
        public ReporteVentasGerencia ObtenerReporte(DateTime fechaInicio, DateTime fechaFin, int idTienda = 0)
        {
            var reporte = new ReporteVentasGerencia
            {
                KPIs              = new KPIVentas(),
                VentasPorMes      = new List<VentasPorMes>(),
                TopProductos      = new List<TopProductoVenta>(),
                ProductosUtilidad = new List<ProductoUtilidad>(),
                VentasPorTienda   = new List<VentasPorTienda>(),
                VentasPorVendedor = new List<VentasPorVendedor>(),
                TopClientes       = new List<TopClienteVenta>(),
                Inventario        = new List<InvRelacion>(),
                FechaInicio       = fechaInicio.ToString("dd/MM/yyyy"),
                FechaFin          = fechaFin.ToString("dd/MM/yyyy")
            };

            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    var cmd = new SqlCommand("usp_ReporteVentasGerencia", cn)
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
                            reporte.KPIs = new KPIVentas
                            {
                                TotalVentas        = L<int>(dr,      "TotalVentas"),
                                VentasEfectivas    = L<int>(dr,      "VentasEfectivas"),
                                MontoNeto          = L<decimal>(dr,  "MontoNeto"),
                                MontoTotal         = L<decimal>(dr,  "MontoTotal"),
                                MontoNC            = L<decimal>(dr,  "MontoNC"),
                                TotalNC            = L<int>(dr,      "TotalNC"),
                                CantidadClientes   = L<int>(dr,      "CantidadClientes"),
                                TotalUnidades      = L<decimal>(dr,  "TotalUnidades"),
                                TicketPromedio     = L<decimal>(dr,  "TicketPromedio"),
                                VariacionMontoPct  = L<double?>(dr,  "VariacionMontoPct"),
                                VariacionVentasPct = L<double?>(dr,  "VariacionVentasPct"),
                                MontoAnterior      = L<decimal>(dr,  "MontoAnterior"),
                                VentasAnterior     = L<int>(dr,      "VentasAnterior")
                            };
                        }

                        // ── RS2: Ventas por mes ───────────────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.VentasPorMes.Add(new VentasPorMes
                                {
                                    Anio       = L<int>(dr,     "Anio"),
                                    Mes        = L<int>(dr,     "Mes"),
                                    MesNombre  = L<string>(dr,  "MesNombre"),
                                    Cantidad   = L<int>(dr,     "Cantidad"),
                                    MontoTotal = L<decimal>(dr, "MontoTotal")
                                });
                        }

                        // ── RS3: Top productos por unidades ───────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.TopProductos.Add(new TopProductoVenta
                                {
                                    Ranking          = L<int>(dr,     "Ranking"),
                                    Codigo           = L<string>(dr,  "Codigo"),
                                    Producto         = L<string>(dr,  "Producto"),
                                    Categoria        = L<string>(dr,  "Categoria"),
                                    UnidadesVendidas = L<decimal>(dr, "UnidadesVendidas"),
                                    MontoTotal       = L<decimal>(dr, "MontoTotal")
                                });
                        }

                        // ── RS4: Productos por utilidad ───────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.ProductosUtilidad.Add(new ProductoUtilidad
                                {
                                    Ranking    = L<int>(dr,     "Ranking"),
                                    Codigo     = L<string>(dr,  "Codigo"),
                                    Producto   = L<string>(dr,  "Producto"),
                                    Categoria  = L<string>(dr,  "Categoria"),
                                    Cantidad   = L<decimal>(dr, "Cantidad"),
                                    VentaTotal = L<decimal>(dr, "VentaTotal"),
                                    CostoTotal = L<decimal>(dr, "CostoTotal"),
                                    Utilidad   = L<decimal>(dr, "Utilidad"),
                                    MargenPct  = L<double>(dr,  "MargenPct")
                                });
                        }

                        // ── RS5: Ventas por tienda ────────────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.VentasPorTienda.Add(new VentasPorTienda
                                {
                                    Tienda        = L<string>(dr,  "Tienda"),
                                    Cantidad      = L<int>(dr,     "Cantidad"),
                                    MontoTotal    = L<decimal>(dr, "MontoTotal"),
                                    PorcentajePct = L<double>(dr,  "PorcentajePct")
                                });
                        }

                        // ── RS6: Ventas por vendedor ──────────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.VentasPorVendedor.Add(new VentasPorVendedor
                                {
                                    Vendedor       = L<string>(dr,  "Vendedor"),
                                    Tienda         = L<string>(dr,  "Tienda"),
                                    Cantidad       = L<int>(dr,     "Cantidad"),
                                    MontoTotal     = L<decimal>(dr, "MontoTotal"),
                                    TicketPromedio = L<decimal>(dr, "TicketPromedio")
                                });
                        }

                        // ── RS7: Top clientes ─────────────────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.TopClientes.Add(new TopClienteVenta
                                {
                                    Ranking          = L<int>(dr,     "Ranking"),
                                    Cliente          = L<string>(dr,  "Cliente"),
                                    CantidadFacturas = L<int>(dr,     "CantidadFacturas"),
                                    MontoTotal       = L<decimal>(dr, "MontoTotal"),
                                    TicketPromedio   = L<decimal>(dr, "TicketPromedio")
                                });
                        }

                        // ── RS8: Relación con inventario ──────────────────────
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                                reporte.Inventario.Add(new InvRelacion
                                {
                                    Tienda               = L<string>(dr, "Tienda"),
                                    ProductosAgotados    = L<int>(dr,    "ProductosAgotados"),
                                    ProductosBajoStock   = L<int>(dr,    "ProductosBajoStock"),
                                    TotalProductos       = L<int>(dr,    "TotalProductos"),
                                    InventariosAprobados = L<int>(dr,    "InventariosAprobados"),
                                    PctDiferenciaProm    = L<double>(dr, "PctDiferenciaProm")
                                });
                        }
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[CD_ReporteVentasGerencia] Error: " + ex.Message);
                }
            }
            return reporte;
        }
    }
}
