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
    }
}
