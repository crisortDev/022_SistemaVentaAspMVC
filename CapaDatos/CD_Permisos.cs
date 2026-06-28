using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaDatos
{
    public class CD_Permisos
    {
        public static CD_Permisos _instancia = null;

        private CD_Permisos()
        {

        }

        public static CD_Permisos Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Permisos();
                }
                return _instancia;
            }
        }
        public List<Permisos> ObtenerPermisos(int IdRol)
        {
            List<Permisos> rptListaPermisos = new List<Permisos>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerPermisos", oConexion);
                cmd.Parameters.AddWithValue("@IdRol", IdRol);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaPermisos.Add(new Permisos()
                        {
                            IdPermisos = Convert.ToInt32(dr["IdPermisos"].ToString()),
                            Menu = dr["Menu"].ToString(),
                            SubMenu = dr["SubMenu"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"].ToString())
                        });
                    }
                    dr.Close();

                    return rptListaPermisos;

                }
                catch (Exception ex)
                {
                    rptListaPermisos = null;
                    return rptListaPermisos;
                }
            }
        }

        public bool ActualizarPermisos(string Detalle)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ActualizarPermisos", oConexion);
                    cmd.Parameters.Add("Detalle", SqlDbType.Xml).Value = Detalle;
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();

                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);

                }
                catch (Exception ex)
                {
                    respuesta = false;
                }
            }
            return respuesta;
        }
        public List<Permisos> ListarPermisosPorRol(int idRol)
        {
            List<Permisos> lista = new List<Permisos>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    StringBuilder query = new StringBuilder();
                    query.AppendLine("SELECT p.IdPermiso, p.IdRol, p.IdSubMenu, s.Descripcion AS NombreSubMenu, p.Activo");
                    query.AppendLine("FROM PERMISOS p");
                    query.AppendLine("INNER JOIN SUBMENU s ON s.IdSubMenu = p.IdSubMenu");
                    query.AppendLine("WHERE p.IdRol = @idRol");

                    SqlCommand cmd = new SqlCommand(query.ToString(), oConexion);
                    cmd.Parameters.AddWithValue("@idRol", idRol);

                    oConexion.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Permisos()
                            {
                                IdPermisos = Convert.ToInt32(dr["IdPermiso"]),
                                //IdRol = Convert.ToInt32(dr["IdRol"]),
                                //IdSubMenu = Convert.ToInt32(dr["IdSubMenu"]),
                                //NombreSubMenu = dr["NombreSubMenu"].ToString(),
                                Activo = Convert.ToBoolean(dr["Activo"])
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<Permisos>();
                }
            }

            return lista;
        }
        public List<Permisos> ListPermisosPorRol(int idRol)
        {
            List<Permisos> lista = new List<Permisos>();

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                string sql = @"
            SELECT
                p.IdPermisos AS IdPermiso,
                m.Nombre AS NombreMenu,
                s.Nombre AS NombreSubMenu,
                p.Activo
            FROM PERMISOS p
            INNER JOIN SUBMENU s ON s.IdSubMenu = p.IdSubMenu
            INNER JOIN MENU m    ON m.IdMenu    = s.IdMenu
            WHERE p.IdRol = @IdRol
              AND s.Activo  = 1
              AND m.Activo  = 1
              AND s.EsGrupo = 0
              AND m.Nombre <> 'Inicio'
            ORDER BY m.Orden, s.Orden";

                SqlCommand cmd = new SqlCommand(sql, cn);
                cmd.Parameters.AddWithValue("@IdRol", idRol);

                try
                {
                    cn.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        lista.Add(new Permisos()
                        {
                            IdPermisos = Convert.ToInt32(dr["IdPermiso"]),
                            Menu    = dr["NombreMenu"].ToString(),
                            SubMenu = dr["NombreSubMenu"].ToString(),
                            Activo  = Convert.ToBoolean(dr["Activo"])
                        });
                    }

                    dr.Close();
                }
                catch (Exception ex)
                {
                    lista = null;
                }
            }

            return lista;
        }
        public List<object> ListarTodosLosPermisos()
        {
            List<object> lista = new List<object>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string sql = @"SELECT s.IdSubMenu, m.Nombre AS NombreMenu, s.Nombre AS NombreSubMenu
                       FROM SubMenu s
                       INNER JOIN Menu m ON s.IdMenu = m.IdMenu
                       WHERE s.Activo = 1 AND m.Activo = 1 AND s.EsGrupo = 0
                         AND m.Nombre <> 'Inicio'
                       ORDER BY m.Orden, s.Orden";
                SqlCommand cmd = new SqlCommand(sql, oConexion);
                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    lista.Add(new
                    {
                        IdSubMenu = Convert.ToInt32(dr["IdSubMenu"]),
                        NombreMenu = dr["NombreMenu"].ToString(),
                        NombreSubMenu = dr["NombreSubMenu"].ToString()
                    });
                }
                dr.Close();
            }
            return lista;
        }

    }
}
