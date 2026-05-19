using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_PuntoCaja
    {
        private static readonly CD_PuntoCaja _instancia = new CD_PuntoCaja();
        public static CD_PuntoCaja Instancia => _instancia;
        private CD_PuntoCaja() { }

        // ── Listar puntos de caja (maestro) ──────────────────────────
        public List<PuntoCaja> ObtenerPuntos(int idTienda = 0)
        {
            var lista = new List<PuntoCaja>();
            try
            {
                using (var cn = new SqlConnection(Conexion.CN))
                {
                    cn.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerPuntosCaja", cn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                        using (var dr = cmd.ExecuteReader())
                        {
                            while (dr.Read())
                            {
                                lista.Add(new PuntoCaja
                                {
                                    IdPuntoCaja     = Convert.ToInt32(dr["IdPuntoCaja"]),
                                    IdTienda        = Convert.ToInt32(dr["IdTienda"]),
                                    NombreTienda    = dr["NombreTienda"].ToString(),
                                    Nombre          = dr["Nombre"].ToString(),
                                    Descripcion     = dr["Descripcion"].ToString(),
                                    Activo          = Convert.ToBoolean(dr["Activo"]),
                                    FechaRegistro   = Convert.ToDateTime(dr["FechaRegistro"]),
                                    TotalSesiones   = Convert.ToInt32(dr["TotalSesiones"]),
                                    SesionesAbiertas= Convert.ToInt32(dr["SesionesAbiertas"]),
                                    UltimaApertura  = dr["UltimaApertura"] == DBNull.Value
                                                        ? (DateTime?)null
                                                        : Convert.ToDateTime(dr["UltimaApertura"])
                                });
                            }
                        }
                    }
                }
            }
            catch { }
            return lista;
        }

        // ── Sesiones de un punto de caja (detalle) ────────────────────
        public List<SesionCajaPunto> ObtenerSesiones(int idPuntoCaja)
        {
            var lista = new List<SesionCajaPunto>();
            try
            {
                using (var cn = new SqlConnection(Conexion.CN))
                {
                    cn.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerSesionesPorPunto", cn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdPuntoCaja", idPuntoCaja);
                        using (var dr = cmd.ExecuteReader())
                        {
                            while (dr.Read())
                            {
                                lista.Add(new SesionCajaPunto
                                {
                                    IdCaja        = Convert.ToInt32(dr["IdCaja"]),
                                    Aperturista   = dr["Aperturista"].ToString(),
                                    FechaApertura = Convert.ToDateTime(dr["FechaApertura"]),
                                    MontoApertura = Convert.ToDecimal(dr["MontoApertura"]),
                                    FechaCierre   = dr["FechaCierre"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaCierre"]),
                                    UsuarioCierre = dr["UsuarioCierre"].ToString(),
                                    MontoSistema  = dr["MontoSistema"]  == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["MontoSistema"]),
                                    MontoContado  = dr["MontoContado"]  == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["MontoContado"]),
                                    Diferencia    = dr["Diferencia"]    == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["Diferencia"]),
                                    Estado        = dr["Estado"].ToString(),
                                    Observacion   = dr["Observacion"]?.ToString(),
                                    CantidadVentas= Convert.ToInt32(dr["CantidadVentas"]),
                                    TotalVentas   = Convert.ToDecimal(dr["TotalVentas"])
                                });
                            }
                        }
                    }
                }
            }
            catch { }
            return lista;
        }

        // ── Registrar nuevo punto ─────────────────────────────────────
        public (bool resultado, string mensaje, int idPuntoCaja) Registrar(
            int idTienda, string nombre, string descripcion)
        {
            try
            {
                using (var cn = new SqlConnection(Conexion.CN))
                {
                    cn.Open();
                    using (var cmd = new SqlCommand("usp_RegistrarPuntoCaja", cn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                        cmd.Parameters.AddWithValue("@Nombre",      nombre ?? "");
                        cmd.Parameters.AddWithValue("@Descripcion", descripcion ?? "");

                        var pRes = cmd.Parameters.Add("@Resultado",   SqlDbType.Bit);         pRes.Direction = ParameterDirection.Output;
                        var pMsg = cmd.Parameters.Add("@Mensaje",     SqlDbType.NVarChar, 300); pMsg.Direction = ParameterDirection.Output;
                        var pId  = cmd.Parameters.Add("@IdPuntoCaja", SqlDbType.Int);           pId.Direction  = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();
                        return ((bool)pRes.Value, pMsg.Value?.ToString(), (int)pId.Value);
                    }
                }
            }
            catch (Exception ex) { return (false, "Error: " + ex.Message, 0); }
        }

        // ── Actualizar punto ──────────────────────────────────────────
        public (bool resultado, string mensaje) Actualizar(
            int idPuntoCaja, string nombre, string descripcion, bool activo)
        {
            try
            {
                using (var cn = new SqlConnection(Conexion.CN))
                {
                    cn.Open();
                    using (var cmd = new SqlCommand("usp_ActualizarPuntoCaja", cn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdPuntoCaja", idPuntoCaja);
                        cmd.Parameters.AddWithValue("@Nombre",      nombre ?? "");
                        cmd.Parameters.AddWithValue("@Descripcion", descripcion ?? "");
                        cmd.Parameters.AddWithValue("@Activo",      activo);

                        var pRes = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pRes.Direction = ParameterDirection.Output;
                        var pMsg = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pMsg.Direction = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();
                        return ((bool)pRes.Value, pMsg.Value?.ToString());
                    }
                }
            }
            catch (Exception ex) { return (false, "Error: " + ex.Message); }
        }
    }
}
