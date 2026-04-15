using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace CapaDatos
{
    public class CD_Proveedor
    {
        public static CD_Proveedor _instancia = null;

        private CD_Proveedor()
        {

        }

        public static CD_Proveedor Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Proveedor();
                }
                return _instancia;
            }
        }

        public List<Proveedor> ObtenerProveedor()
        {
            List<Proveedor> rptListaProveedor = new List<Proveedor>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerProveedores", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaProveedor.Add(new Proveedor()
                        {
                            IdProveedor = Convert.ToInt32(dr["IdProveedor"]),
                            Ruc = dr["RUC"].ToString(),
                            RazonSocial = dr["RazonSocial"].ToString(),
                            Telefono = dr["Telefono"].ToString(),
                            Correo = dr["Correo"].ToString(),
                            Direccion = dr["Direccion"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            Ciudad = dr["Ciudad"].ToString(),
                            Geolocalizacion = dr["Geolocalizacion"].ToString(),
                            Barrio = dr["Barrio"].ToString(),
                            Calle = dr["Calle"].ToString(),
                            Referencia = dr["Referencia"].ToString()

                        });
                    }
                    dr.Close();

                    return rptListaProveedor;

                }
                catch (Exception ex)
                {
                    rptListaProveedor = new List<Proveedor>();
                    return rptListaProveedor;
                }
            }
        }

        public bool RegistrarProveedor(Proveedor oProveedor)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarProveedor", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@Ruc",             oProveedor.Ruc);
                    cmd.Parameters.AddWithValue("@RazonSocial",     oProveedor.RazonSocial);
                    cmd.Parameters.AddWithValue("@Telefono",        oProveedor.Telefono);
                    cmd.Parameters.AddWithValue("@Correo",          oProveedor.Correo);
                    cmd.Parameters.AddWithValue("@Direccion",       oProveedor.Direccion);
                    cmd.Parameters.AddWithValue("@Ciudad",          (object)oProveedor.Ciudad          ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Barrio",          (object)oProveedor.Barrio          ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Calle",           (object)oProveedor.Calle           ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Referencia",      (object)oProveedor.Referencia      ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Geolocalizacion", (object)oProveedor.Geolocalizacion ?? DBNull.Value);
                    // BUG FIX: se registraba como "@Resultado" pero se leía como "Resultado" → KeyNotFoundException
                    // Unificado: ambos usan "@Resultado" con el prefijo @
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch (Exception ex)
                {
                    respuesta = false;
                }
            }
            return respuesta;
        }


        public bool ModificarProveedor(Proveedor oProveedor)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarProveedor", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    // BUG FIX: parámetros unificados con prefijo @ consistente
                    cmd.Parameters.AddWithValue("@IdProveedor",    oProveedor.IdProveedor);
                    cmd.Parameters.AddWithValue("@Ruc",            oProveedor.Ruc);
                    cmd.Parameters.AddWithValue("@RazonSocial",    oProveedor.RazonSocial);
                    cmd.Parameters.AddWithValue("@Telefono",       oProveedor.Telefono);
                    cmd.Parameters.AddWithValue("@Correo",         oProveedor.Correo);
                    cmd.Parameters.AddWithValue("@Direccion",      oProveedor.Direccion);
                    cmd.Parameters.AddWithValue("@Activo",         oProveedor.Activo);
                    cmd.Parameters.AddWithValue("@Ciudad",         (object)oProveedor.Ciudad          ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Barrio",         (object)oProveedor.Barrio          ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Calle",          (object)oProveedor.Calle           ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Referencia",     (object)oProveedor.Referencia      ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Geolocalizacion",(object)oProveedor.Geolocalizacion ?? DBNull.Value);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch (Exception ex)
                {
                    respuesta = false;
                }
            }
            return respuesta;
        }

        public bool VerificarRucExistente(string ruc)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_VerificarRucProveedor", oConexion);
                    cmd.Parameters.AddWithValue("@Ruc", ruc);
                    cmd.Parameters.Add("@Existe", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    existe = Convert.ToBoolean(cmd.Parameters["@Existe"].Value);
                }
                catch { existe = false; }
            }
            return existe;
        }

        public bool ReactivarProveedor(int IdProveedor)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ReactivarProveedor", oConexion);
                    cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        public bool TieneCompras(int IdProveedor)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ProveedorTieneCompras", oConexion);
                    cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    resultado = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch
                {
                    resultado = false;
                }
            }
            return resultado;
        }

        public bool DesactivarProveedor(int IdProveedor)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_DesactivarProveedor", oConexion);
                    cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch
                {
                    respuesta = false;
                }
            }
            return respuesta;
        }

        public (bool resultado, string mensaje) EliminarProveedor(int IdProveedor)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_EliminarProveedor", oConexion);
                    cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "Error desconocido.";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al conectar con la base de datos: " + ex.Message);
                }
            }
        }

    }
}