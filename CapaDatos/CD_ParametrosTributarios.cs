using CapaModelo;
using System;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_ParametrosTributarios
    {
        private static readonly CD_ParametrosTributarios _instancia = new CD_ParametrosTributarios();
        public static CD_ParametrosTributarios Instancia => _instancia;
        private CD_ParametrosTributarios() { }

        // ── Obtener configuración completa ────────────────────────────
        public DatosTributarios ObtenerConfiguracion()
        {
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerConfiguracionTributaria", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        using (var dr = cmd.ExecuteReader())
                        {
                            if (dr.Read())
                            {
                                return new DatosTributarios
                                {
                                    NumeroTimbrado       = dr["NumeroTimbrado"].ToString(),
                                    VencimientoTimbrado  = dr["VencimientoTimbrado"].ToString(),
                                    Establecimiento      = dr["Establecimiento"].ToString(),
                                    PuntoExpedicion      = dr["PuntoExpedicion"].ToString(),
                                    SecuenciaActual      = Convert.ToInt32(dr["SecuenciaActual"]),
                                    ProximoNumeroFactura = dr["ProximoNumeroFactura"].ToString(),
                                    RazonSocial          = dr["RazonSocial"].ToString(),
                                    DiasParaVencer       = Convert.ToInt32(dr["DiasParaVencer"]),
                                    EstadoTimbrado       = dr["EstadoTimbrado"].ToString()
                                };
                            }
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        // ── Actualizar configuración ──────────────────────────────────
        public (bool resultado, string mensaje) Actualizar(
            string numeroTimbrado, DateTime vencimiento,
            string establecimiento, string puntoExpedicion, string razonSocial)
        {
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ActualizarConfiguracionTributaria", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@NumeroTimbrado",      numeroTimbrado);
                        cmd.Parameters.AddWithValue("@VencimientoTimbrado", vencimiento.Date);
                        cmd.Parameters.AddWithValue("@Establecimiento",     establecimiento);
                        cmd.Parameters.AddWithValue("@PuntoExpedicion",     puntoExpedicion);
                        cmd.Parameters.AddWithValue("@RazonSocial",         razonSocial ?? "");

                        var pRes = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);
                        pRes.Direction = ParameterDirection.Output;
                        var pMsg = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300);
                        pMsg.Direction = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();

                        return ((bool)pRes.Value, pMsg.Value?.ToString());
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error: " + ex.Message);
            }
        }
    }
}
