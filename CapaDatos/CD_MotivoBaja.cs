using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_MotivoBaja
    {
        private static CD_MotivoBaja _instancia = null;
        private CD_MotivoBaja() { }

        public static CD_MotivoBaja Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_MotivoBaja();
                return _instancia;
            }
        }

        public List<MotivoBaja> ObtenerMotivosBaja()
        {
            var lista = new List<MotivoBaja>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerMotivosBaja", cn)
                { CommandType = CommandType.StoredProcedure };
                try
                {
                    cn.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new MotivoBaja
                        {
                            IdMotivoBaja = Convert.ToInt32(dr["IdMotivoBaja"]),
                            Descripcion = dr["Descripcion"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"])
                        });
                    }
                    dr.Close();
                }
                catch { lista = new List<MotivoBaja>(); }
            }
            return lista;
        }

        public bool RegistrarMotivoBaja(MotivoBaja obj)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_RegistrarMotivoBaja", cn)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@Descripcion", obj.Descripcion);
                cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    cn.Open();
                    cmd.ExecuteNonQuery();
                    return Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { return false; }
            }
        }

        public bool ModificarMotivoBaja(MotivoBaja obj)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ModificarMotivoBaja", cn)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdMotivoBaja", obj.IdMotivoBaja);
                cmd.Parameters.AddWithValue("@Descripcion", obj.Descripcion);
                cmd.Parameters.AddWithValue("@Activo", obj.Activo);
                cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    cn.Open();
                    cmd.ExecuteNonQuery();
                    return Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { return false; }
            }
        }

        public bool EliminarMotivoBaja(int idMotivoBaja)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_EliminarMotivoBaja", cn)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdMotivoBaja", idMotivoBaja);
                cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    cn.Open();
                    cmd.ExecuteNonQuery();
                    return Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { return false; }
            }
        }
    }
}