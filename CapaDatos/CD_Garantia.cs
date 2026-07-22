using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

namespace CapaDatos
{
    public class CD_Garantia
    {
        // ── Singleton ─────────────────────────────────────────────────────────
        private static CD_Garantia _instancia;
        public static CD_Garantia Instancia =>
            _instancia ?? (_instancia = new CD_Garantia());

        // ── Buscar ventas elegibles para garantía ─────────────────────────────
        public List<Venta> ObtenerVentasParaGarantia(
            string numeroFactura, int idCliente, int idTienda, string documento = "")
        {
            var lista = new List<Venta>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_ObtenerVentasParaGarantia", cn)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@NumeroFactura", string.IsNullOrWhiteSpace(numeroFactura) ? "" : numeroFactura.Trim());
                cmd.Parameters.AddWithValue("@IdCliente",     idCliente);
                cmd.Parameters.AddWithValue("@IdTienda",      idTienda);
                cmd.Parameters.AddWithValue("@Documento",     string.IsNullOrWhiteSpace(documento) ? "" : documento.Trim());

                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Venta
                            {
                                IdVenta          = Convert.ToInt32(dr["IdVenta"]),
                                NumeroFactura    = dr["NumeroFactura"]?.ToString(),
                                FechaRegistro    = dr["FechaVenta"]?.ToString(),
                                TotalCosto       = Convert.ToDecimal(dr["TotalCosto"]),
                                ModalidadPago    = dr["ModalidadPago"]?.ToString(),
                                NumeroCuotas     = dr["NumeroCuotas"] != DBNull.Value ? Convert.ToInt32(dr["NumeroCuotas"]) : 0,
                                Estado           = dr["Estado"]?.ToString(),
                                NombreCliente    = dr["NombreCliente"]?.ToString(),
                                DocumentoCliente = dr["DocumentoCliente"]?.ToString(),
                                NombreTienda     = dr["NombreTienda"]?.ToString(),
                                oCliente = new Cliente
                                {
                                    IdCliente       = Convert.ToInt32(dr["IdCliente"]),
                                    Nombre          = dr["NombreCliente"]?.ToString(),
                                    NumeroDocumento = dr["DocumentoCliente"]?.ToString()
                                },
                                oTienda = new Tienda
                                {
                                    Nombre = dr["NombreTienda"]?.ToString()
                                },
                                // Reutilizamos campos auxiliares
                                CuotasPendientes   = dr["CuotasPendientes"] != DBNull.Value ? Convert.ToInt32(dr["CuotasPendientes"]) : 0,
                                CuotasPagadas      = dr["CuotasPagadas"]    != DBNull.Value ? Convert.ToInt32(dr["CuotasPagadas"])    : 0,
                                TieneItemsActivos  = Convert.ToBoolean(dr["TieneItemsActivos"]),
                                PuedeGarantia      = Convert.ToBoolean(dr["PuedeGarantia"])
                            });
                        }
                    }
                }
                catch (Exception) { }
            }
            return lista;
        }

        // ── Obtener detalle de una venta para seleccionar el ítem fallado ─────
        public List<DetalleVenta> ObtenerDetalleParaGarantia(int idVenta, int idTienda)
        {
            var lista = new List<DetalleVenta>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_ObtenerDetalleVentaParaGarantia", cn)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@IdVenta",  idVenta);
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new DetalleVenta
                            {
                                IdDetalleVenta   = Convert.ToInt32(dr["IdDetalleVenta"]),
                                IdProducto       = Convert.ToInt32(dr["IdProducto"]),
                                NombreProducto   = dr["NombreProducto"]?.ToString(),
                                CodigoProducto   = dr["CodigoProducto"]?.ToString(),
                                Cantidad         = Convert.ToDecimal(dr["Cantidad"]),
                                PrecioUnidad     = Convert.ToDecimal(dr["PrecioUnidad"]),
                                ImporteTotal     = Convert.ToDecimal(dr["ImporteTotal"]),
                                EstadoLinea          = dr["EstadoLinea"]?.ToString() ?? "OK",
                                CantidadGarantizada  = dr["CantidadGarantizada"] != DBNull.Value ? Convert.ToInt32(dr["CantidadGarantizada"]) : 0,
                                CantidadDisponible   = dr["CantidadDisponible"]  != DBNull.Value ? Convert.ToInt32(dr["CantidadDisponible"])  : 0,
                                StockDisponible      = Convert.ToDecimal(dr["StockDisponible"])
                            });
                        }
                    }
                }
                catch (Exception) { }
            }
            return lista;
        }

        // ── Procesar garantía masiva (múltiples ítems en una sola operación) ────
        public (bool resultado, string mensaje, decimal montoNC, string numeroNC, int reemplazos, decimal saldoGenerado)
            ProcesarGarantiaMasiva(
                int idVenta, int idMotivoNC, int idUsuario,
                List<GarantiaItem> items)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    // Construir DataTable para el TVP
                    var tvp = new DataTable();
                    tvp.Columns.Add("IdDetalleVenta",   typeof(int));
                    tvp.Columns.Add("CantidadGarantia", typeof(int));
                    foreach (var it in items)
                        tvp.Rows.Add(it.IdDetalleVenta, it.CantidadGarantia);

                    var cmd = new SqlCommand("usp_ProcesarGarantiaMasiva", cn)
                    {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@IdVenta",    idVenta);
                    cmd.Parameters.AddWithValue("@IdMotivoNC", idMotivoNC);
                    cmd.Parameters.AddWithValue("@IdUsuario",  idUsuario);

                    var pItems = cmd.Parameters.AddWithValue("@Items", tvp);
                    pItems.SqlDbType = SqlDbType.Structured;
                    pItems.TypeName  = "dbo.TGarantiaItem";

                    var pRes    = new SqlParameter("@Resultado",     SqlDbType.Bit)           { Direction = ParameterDirection.Output };
                    var pMsg    = new SqlParameter("@Mensaje",       SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };
                    var pMonto  = new SqlParameter("@MontoNC",       SqlDbType.Decimal)       { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
                    var pNumNC  = new SqlParameter("@NumeroNC",      SqlDbType.VarChar, 20)   { Direction = ParameterDirection.Output };
                    var pRemp   = new SqlParameter("@Reemplazos",    SqlDbType.Int)            { Direction = ParameterDirection.Output };
                    var pSaldo  = new SqlParameter("@SaldoGenerado", SqlDbType.Decimal)       { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };

                    cmd.Parameters.Add(pRes);
                    cmd.Parameters.Add(pMsg);
                    cmd.Parameters.Add(pMonto);
                    cmd.Parameters.Add(pNumNC);
                    cmd.Parameters.Add(pRemp);
                    cmd.Parameters.Add(pSaldo);

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool    ok       = pRes.Value   != DBNull.Value && Convert.ToBoolean(pRes.Value);
                    string  msg      = pMsg.Value?.ToString() ?? "";
                    decimal monto    = pMonto.Value != DBNull.Value ? Convert.ToDecimal(pMonto.Value) : 0;
                    string  numNC    = pNumNC.Value?.ToString() ?? "";
                    int     reempl   = pRemp.Value  != DBNull.Value ? Convert.ToInt32(pRemp.Value) : 0;
                    decimal saldo    = pSaldo.Value != DBNull.Value ? Convert.ToDecimal(pSaldo.Value) : 0;

                    return (ok, msg, monto, numNC, reempl, saldo);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message, 0, "", 0, 0);
                }
            }
        }

        // ── Procesar la garantía individual (legado — mantener compatibilidad) ──
        public (bool resultado, string mensaje, decimal montoNC, decimal saldoGenerado)
            ProcesarGarantia(
                int idVenta, int idDetalleVenta,
                int idMotivoNC, bool hayStock, int idUsuario, int cantidadGarantia = 0)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    var cmd = new SqlCommand("usp_ProcesarGarantia", cn)
                    {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@IdVenta",        idVenta);
                    cmd.Parameters.AddWithValue("@IdDetalleVenta", idDetalleVenta);
                    cmd.Parameters.AddWithValue("@IdMotivoNC",     idMotivoNC);
                    cmd.Parameters.AddWithValue("@HayStock",          hayStock ? 1 : 0);
                    cmd.Parameters.AddWithValue("@IdUsuario",         idUsuario);
                    cmd.Parameters.AddWithValue("@CantidadGarantia",  cantidadGarantia);

                    var pRes    = new SqlParameter("@Resultado",     SqlDbType.Bit)            { Direction = ParameterDirection.Output };
                    var pMsg    = new SqlParameter("@Mensaje",       SqlDbType.NVarChar, 400)  { Direction = ParameterDirection.Output };
                    var pMonto  = new SqlParameter("@MontoNC",       SqlDbType.Decimal)        { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
                    var pSaldo  = new SqlParameter("@SaldoGenerado", SqlDbType.Decimal)        { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
                    cmd.Parameters.Add(pRes);
                    cmd.Parameters.Add(pMsg);
                    cmd.Parameters.Add(pMonto);
                    cmd.Parameters.Add(pSaldo);

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool    ok     = pRes.Value   != DBNull.Value && Convert.ToBoolean(pRes.Value);
                    string  msg    = pMsg.Value?.ToString() ?? "";
                    decimal monto  = pMonto.Value != DBNull.Value ? Convert.ToDecimal(pMonto.Value) : 0;
                    decimal saldo  = pSaldo.Value != DBNull.Value ? Convert.ToDecimal(pSaldo.Value) : 0;
                    return (ok, msg, monto, saldo);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message, 0, 0);
                }
            }
        }
    }
}
