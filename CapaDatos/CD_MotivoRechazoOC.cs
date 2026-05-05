using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_MotivoRechazoOC
    {
        private static CD_MotivoRechazoOC _instancia = null;
        private CD_MotivoRechazoOC() { }
        public static CD_MotivoRechazoOC Instancia
        {
            get { if (_instancia == null) _instancia = new CD_MotivoRechazoOC(); return _instancia; }
        }

        public List<MotivoRechazoOC> Obtener()
        {
            List<MotivoRechazoOC> lista = new List<MotivoRechazoOC>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerMotivosRechazoOC", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new MotivoRechazoOC
                            {
                                IdMotivoRechazo = Convert.ToInt32(dr["IdMotivoRechazo"]),
                                Descripcion     = dr["Descripcion"].ToString(),
                                Activo          = true
                            });
                        }
                    }
                }
                catch (Exception) { lista = new List<MotivoRechazoOC>(); }
            }
            return lista;
        }
    }
}
