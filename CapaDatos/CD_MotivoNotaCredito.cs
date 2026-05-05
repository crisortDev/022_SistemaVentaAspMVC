using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_MotivoNotaCredito
    {
        private static CD_MotivoNotaCredito _instancia = null;
        private CD_MotivoNotaCredito() { }
        public static CD_MotivoNotaCredito Instancia
        {
            get { if (_instancia == null) _instancia = new CD_MotivoNotaCredito(); return _instancia; }
        }

        public List<MotivoNotaCredito> Obtener()
        {
            List<MotivoNotaCredito> lista = new List<MotivoNotaCredito>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                // El SP no existe en el deploy: hacemos el SELECT directo.
                SqlCommand cmd = new SqlCommand(
                    "SELECT IdMotivoNotaCredito, Descripcion FROM dbo.MOTIVO_NOTA_CREDITO WHERE Activo = 1 ORDER BY Descripcion", cn);
                cmd.CommandType = CommandType.Text;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new MotivoNotaCredito
                            {
                                IdMotivoNotaCredito = Convert.ToInt32(dr["IdMotivoNotaCredito"]),
                                Descripcion         = dr["Descripcion"].ToString(),
                                Activo              = true
                            });
                        }
                    }
                }
                catch (Exception) { lista = new List<MotivoNotaCredito>(); }
            }
            return lista;
        }
    }
}
