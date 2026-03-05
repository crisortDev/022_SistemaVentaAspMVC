using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_Rol
    {
        public static CD_Rol _instancia = null;

        private CD_Rol()
        {

        }

        public static CD_Rol Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Rol();
                }
                return _instancia;
            }
        }

        public List<Rol> ObtenerRol()
        {
            List<Rol> rptListaRol = new List<Rol>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerRoles", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaRol.Add(new Rol()
                        {
                            IdRol = Convert.ToInt32(dr["IdRol"].ToString()),
                            Descripcion = dr["Descripcion"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"].ToString())
                        });
                    }
                    dr.Close();

                    return rptListaRol;

                }
                catch (Exception ex)
                {
                    rptListaRol = null;
                    return rptListaRol;
                }
            }
        }

        public bool RegistrarRol(Rol oRol)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarRol", oConexion);
                    cmd.Parameters.AddWithValue("Descripcion", oRol.Descripcion);
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

        public bool ModificarRol(Rol oRol)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarRol", oConexion);
                    cmd.Parameters.AddWithValue("IdRol", oRol.IdRol);
                    cmd.Parameters.AddWithValue("Descripcion", oRol.Descripcion);
                    cmd.Parameters.AddWithValue("Activo", oRol.Activo);
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

        public (bool resultado, string mensaje) DesactivarRol(int IdRol)
        {
            bool resultado = false;
            string mensaje = "";

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    oConexion.Open();

                    // Verificar si el rol está asignado a algún usuario activo
                    string checkSql = "SELECT COUNT(1) FROM USUARIO WHERE IdRol = @IdRol";
                    SqlCommand cmdCheck = new SqlCommand(checkSql, oConexion);
                    cmdCheck.Parameters.AddWithValue("@IdRol", IdRol);
                    int count = Convert.ToInt32(cmdCheck.ExecuteScalar());

                    if (count > 0)
                    {
                        resultado = false;
                        mensaje = "El rol está asignado a usuarios activos y no se puede desactivar.";
                    }
                    else
                    {
                        // Actualizar el rol a inactivo
                        string sql = "UPDATE ROL SET Activo = 0 WHERE IdRol = @IdRol";
                        SqlCommand cmd = new SqlCommand(sql, oConexion);
                        cmd.Parameters.AddWithValue("@IdRol", IdRol);
                        int filas = cmd.ExecuteNonQuery();

                        resultado = filas > 0;
                        mensaje = resultado ? "El rol fue desactivado correctamente." : "No se pudo desactivar el rol.";
                    }
                }
                catch (Exception ex)
                {
                    resultado = false;
                    mensaje = "Ocurrió un error al desactivar el rol: " + ex.Message;
                }
            }

            return (resultado, mensaje);
        }
        public bool RegistrarRolConPermisos(RolPermiso modelo)
        {
            bool resultado = false;

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                cn.Open();
                SqlTransaction tx = cn.BeginTransaction();

                try
                {
                    // 1️⃣ Insertar ROL y obtener ID
                    string sqlRol = @"
                INSERT INTO ROL (Descripcion, Activo, FechaRegistro)
                VALUES (@Descripcion, 1, GETDATE());
                SELECT SCOPE_IDENTITY();
            ";

                    SqlCommand cmdRol = new SqlCommand(sqlRol, cn, tx);
                    cmdRol.Parameters.AddWithValue("@Descripcion", modelo.Descripcion);

                    int idRol = Convert.ToInt32(cmdRol.ExecuteScalar());

                    if (idRol <= 0)
                        throw new Exception("No se pudo crear el rol");

                    // 2️⃣ Insertar permisos
                    foreach (int idSubMenu in modelo.Permisos)
                    {
                        string sqlPermiso = @"
                    INSERT INTO PERMISOS (IdRol, IdSubMenu, Activo, FechaRegistro)
                    VALUES (@IdRol, @IdSubMenu, 1, GETDATE())
                ";

                        SqlCommand cmdPermiso = new SqlCommand(sqlPermiso, cn, tx);
                        cmdPermiso.Parameters.AddWithValue("@IdRol", idRol);
                        cmdPermiso.Parameters.AddWithValue("@IdSubMenu", idSubMenu);

                        cmdPermiso.ExecuteNonQuery();
                    }

                    tx.Commit();
                    resultado = true;
                }
                catch (Exception)
                {
                    tx.Rollback();
                    resultado = false;
                }
            }

            return resultado;
        }
    }
}
