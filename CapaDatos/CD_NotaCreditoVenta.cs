using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_NotaCreditoVenta
    {
        private static CD_NotaCreditoVenta _instancia = null;
        private CD_NotaCreditoVenta() { }
        public static CD_NotaCreditoVenta Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_NotaCreditoVenta();
                return _instancia;
            }
        }

        // ----------------------------------------------------------------
        //  REGISTRAR NOTA DE CRÉDITO DE VENTA
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idGenerado) RegistrarNotaCreditoVenta(
            int idVenta, int idMotivoNC, decimal monto,
            string observacion, int idUsuarioRegistro)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarNotaCreditoVenta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                    cmd.Parameters.AddWithValue("@IdMotivoNC", idMotivoNC);
                    cmd.Parameters.AddWithValue("@Monto", monto);
                    cmd.Parameters.AddWithValue("@Observacion",
                        string.IsNullOrWhiteSpace(observacion) ? (object)DBNull.Value : observacion);
                    cmd.Parameters.AddWithValue("@IdUsuarioRegistro", idUsuarioRegistro);

                    cmd.Parameters.Add("@IdNCGenerada", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int id = cmd.Parameters["@IdNCGenerada"].Value != DBNull.Value
                           ? Convert.ToInt32(cmd.Parameters["@IdNCGenerada"].Value) : 0;

                    return (ok, msg, id);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar nota de crédito: " + ex.Message, 0);
                }
            }
        }

        // ----------------------------------------------------------------
        //  APROBAR / RECHAZAR NOTA DE CRÉDITO
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje) AprobarRechazarNCV(
            int idNCVenta, int idUsuario, string accion, string motivoRechazo)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AprobarRechazarNCV", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdNCVenta", idNCVenta);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    cmd.Parameters.AddWithValue("@Accion", accion);         // 'Aprobar' | 'Rechazar'
                    cmd.Parameters.AddWithValue("@MotivoRechazo",
                        string.IsNullOrWhiteSpace(motivoRechazo) ? (object)DBNull.Value : motivoRechazo);

                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al procesar nota de crédito: " + ex.Message);
                }
            }
        }

        // ----------------------------------------------------------------
        //  LISTAR NOTAS DE CRÉDITO DE VENTA
        // ----------------------------------------------------------------
        public List<NotaCreditoVenta> ObtenerListaNotaCreditoVenta(
            int idTienda, string estado, DateTime fechaInicio, DateTime fechaFin)
        {
            List<NotaCreditoVenta> lista = new List<NotaCreditoVenta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaNotaCreditoVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@Estado", estado ?? "");
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new NotaCreditoVenta()
                            {
                                IdNCVenta        = Convert.ToInt32(dr["IdNCVenta"]),
                                NumeroNCV        = dr["NumeroNCV"].ToString(),
                                NumeroFactura    = dr["NumeroFactura"].ToString(),
                                CodigoVenta      = dr["CodigoVenta"].ToString(),
                                Estado           = dr["Estado"].ToString(),
                                Monto            = Convert.ToDecimal(dr["Monto"]),
                                MotivoNC         = dr["MotivoNC"].ToString(),
                                Observacion      = dr["Observacion"].ToString(),
                                FechaRegistro    = dr["FechaRegistro"].ToString(),
                                FechaAprobacion  = dr["FechaAprobacion"] != DBNull.Value
                                                 ? dr["FechaAprobacion"].ToString() : "",
                                MotivoRechazo    = dr["MotivoRechazo"] != DBNull.Value
                                                 ? dr["MotivoRechazo"].ToString() : "",
                                NombreCliente    = dr["NombreCliente"].ToString(),
                                NumeroDocumento  = dr["NumeroDocumento"].ToString(),
                                NombreRegistro       = dr["NombreRegistro"].ToString(),
                                NombreTienda         = dr["NombreTienda"].ToString(),
                                ModalidadPago        = dr["ModalidadPago"] != DBNull.Value
                                                     ? dr["ModalidadPago"].ToString() : "",
                                SaldoActualCliente   = dr["SaldoActualCliente"] != DBNull.Value
                                                     ? Convert.ToDecimal(dr["SaldoActualCliente"]) : 0m
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<NotaCreditoVenta>();
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  OBTENER PRODUCTOS DE VENTA PARA NC DE CRÉDITO
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, NotaCreditoVenta infoVenta, List<NotaCreditoVentaDetalle> productos)
            ObtenerProductosVentaParaNC(int idVenta)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ObtenerProductosVentaParaNC", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction    = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    var info      = new NotaCreditoVenta();
                    var productos = new List<NotaCreditoVentaDetalle>();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        // RS1: info de la venta
                        if (dr.Read())
                        {
                            info.NumeroFactura  = dr["NumeroFactura"].ToString();
                            info.NombreCliente  = dr["NombreCliente"].ToString();
                            info.Monto          = Convert.ToDecimal(dr["TotalCosto"]);
                        }
                        // RS2: productos
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                            {
                                productos.Add(new NotaCreditoVentaDetalle
                                {
                                    IdProducto     = Convert.ToInt32(dr["IdProducto"]),
                                    NombreProducto = dr["NombreProducto"].ToString(),
                                    Cantidad       = Convert.ToDecimal(dr["Cantidad"]),
                                    PrecioUnitario = Convert.ToDecimal(dr["PrecioUnitario"]),
                                    TotalLinea     = Convert.ToDecimal(dr["TotalLinea"])
                                });
                            }
                        }
                    }

                    bool   ok  = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg, info, productos);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message, null, new List<NotaCreditoVentaDetalle>());
                }
            }
        }

        // ----------------------------------------------------------------
        //  REGISTRAR NC DE VENTA CRÉDITO (con detalle de productos, TVP)
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idGenerado)
            RegistrarNCVentaCredito(int idVenta, int idMotivoNC, string observacion,
                                     int idUsuarioRegistro, List<NotaCreditoVentaDetalle> detalle)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    // Armar DataTable para el TVP TProductoNC
                    DataTable dt = new DataTable();
                    dt.Columns.Add("IdProducto",    typeof(int));
                    dt.Columns.Add("Cantidad",      typeof(decimal));
                    dt.Columns.Add("PrecioUnitario",typeof(decimal));
                    foreach (var d in detalle)
                        dt.Rows.Add(d.IdProducto, d.Cantidad, d.PrecioUnitario);

                    SqlCommand cmd = new SqlCommand("usp_RegistrarNCVentaCredito", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdVenta",           idVenta);
                    cmd.Parameters.AddWithValue("@IdMotivoNC",        idMotivoNC);
                    cmd.Parameters.AddWithValue("@Observacion",
                        string.IsNullOrWhiteSpace(observacion) ? (object)DBNull.Value : observacion);
                    cmd.Parameters.AddWithValue("@IdUsuarioRegistro", idUsuarioRegistro);

                    var pProductos          = cmd.Parameters.Add("@Productos", SqlDbType.Structured);
                    pProductos.TypeName     = "dbo.TProductoNC";
                    pProductos.Value        = dt;

                    cmd.Parameters.Add("@IdNCGenerada", SqlDbType.Int).Direction      = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado",    SqlDbType.Bit).Direction      = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje",      SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool   ok  = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int    id  = cmd.Parameters["@IdNCGenerada"].Value != DBNull.Value
                               ? Convert.ToInt32(cmd.Parameters["@IdNCGenerada"].Value) : 0;
                    return (ok, msg, id);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar NC: " + ex.Message, 0);
                }
            }
        }

        // ----------------------------------------------------------------
        //  OBTENER DETALLE DE UNA NCV (para modal de aprobación)
        // ----------------------------------------------------------------
        public List<NotaCreditoVentaDetalle> ObtenerDetalleNCV(int idNCVenta)
        {
            var lista = new List<NotaCreditoVentaDetalle>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleNCV", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdNCVenta", idNCVenta);
                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new NotaCreditoVentaDetalle
                            {
                                IdNCVDetalle   = Convert.ToInt32(dr["IdNCVDetalle"]),
                                IdNCVenta      = Convert.ToInt32(dr["IdNCVenta"]),
                                IdProducto     = Convert.ToInt32(dr["IdProducto"]),
                                NombreProducto = dr["NombreProducto"].ToString(),
                                Cantidad       = Convert.ToDecimal(dr["Cantidad"]),
                                PrecioUnitario = Convert.ToDecimal(dr["PrecioUnitario"]),
                                TotalLinea     = Convert.ToDecimal(dr["TotalLinea"])
                            });
                        }
                    }
                }
                catch { lista = new List<NotaCreditoVentaDetalle>(); }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  OBTENER NCV COMPLETA PARA IMPRESIÓN
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, NotaCreditoVenta cabecera, List<NotaCreditoVentaDetalle> productos)
            ObtenerNCVParaImprimir(int idNCVenta)
        {
            var productos = new List<NotaCreditoVentaDetalle>();
            NotaCreditoVenta cab = null;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ObtenerNCVParaImprimir", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdNCVenta", idNCVenta);
                    oConexion.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        // RS1 — cabecera
                        if (dr.Read())
                        {
                            cab = new NotaCreditoVenta
                            {
                                IdNCVenta        = Convert.ToInt32(dr["IdNCVenta"]),
                                NumeroNCV        = dr["NumeroNCV"].ToString(),
                                Monto            = Convert.ToDecimal(dr["Monto"]),
                                Estado           = dr["Estado"].ToString(),
                                Observacion      = dr["Observacion"] != DBNull.Value ? dr["Observacion"].ToString() : "",
                                MotivoRechazo    = dr["MotivoRechazo"] != DBNull.Value ? dr["MotivoRechazo"].ToString() : "",
                                FechaRegistro    = dr["FechaRegistro"].ToString(),
                                FechaAprobacion  = dr["FechaAprobacion"] != DBNull.Value ? dr["FechaAprobacion"].ToString() : "",
                                MotivoNC         = dr["MotivoNC"].ToString(),
                                NumeroFactura    = dr["NumeroFactura"].ToString(),
                                TotalCosto       = Convert.ToDecimal(dr["TotalCosto"]),
                                ModalidadPago    = dr["ModalidadPago"].ToString(),
                                NombreCliente    = dr["NombreCliente"].ToString(),
                                DocumentoCliente = dr["DocumentoCliente"] != DBNull.Value ? dr["DocumentoCliente"].ToString() : "",
                                NombreTienda     = dr["NombreTienda"].ToString(),
                                NombreRegistro   = dr["NombreRegistro"].ToString(),
                                NombreAprobacion = dr["NombreAprobacion"].ToString(),
                                FechaVenta       = dr["FechaVenta"].ToString()
                            };
                        }

                        // RS2 — productos (solo NC crédito)
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                            {
                                productos.Add(new NotaCreditoVentaDetalle
                                {
                                    IdProducto     = Convert.ToInt32(dr["IdProducto"]),
                                    NombreProducto = dr["NombreProducto"].ToString(),
                                    Cantidad       = Convert.ToDecimal(dr["Cantidad"]),
                                    PrecioUnitario = Convert.ToDecimal(dr["PrecioUnitario"]),
                                    TotalLinea     = Convert.ToDecimal(dr["TotalLinea"])
                                });
                            }
                        }
                    }

                    if (cab == null)
                        return (false, "No se encontró la nota de crédito.", null, productos);

                    return (true, "OK", cab, productos);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message, null, productos);
                }
            }
        }
    }
}
