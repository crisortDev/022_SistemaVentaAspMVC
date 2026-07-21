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
    public class CD_Cliente
    {
        public static CD_Cliente _instancia = null;

        private CD_Cliente()
        {

        }

        public static CD_Cliente Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Cliente();
                }
                return _instancia;
            }
        }


        public List<Cliente> ObtenerClientes()
        {
            List<Cliente> rptListaCliente = new List<Cliente>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerCliente", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaCliente.Add(new Cliente()
                        {
                            IdCliente = Convert.ToInt32(dr["IdCliente"]),
                            TipoDocumento = dr["TipoDocumento"].ToString(),
                            NumeroDocumento = dr["NumeroDocumento"].ToString(),
                            Nombre = dr["Nombre"].ToString(),
                            Direccion = dr["Direccion"].ToString(),
                            Telefono = dr["Telefono"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            Ciudad = dr["Ciudad"].ToString(),
                            Barrio = dr["Barrio"].ToString(),
                            Calle = dr["Calle"].ToString(),
                            NumeroCasa = dr["NumeroCasa"].ToString(),
                            Referencia = dr["Referencia"].ToString(),
                            Geolocalizacion = dr["Geolocalizacion"] == DBNull.Value ? null : dr["Geolocalizacion"].ToString(),
                            SaldoFavor      = dr["SaldoFavor"] != DBNull.Value ? Convert.ToDecimal(dr["SaldoFavor"]) : 0m
                        });

                    }
                    dr.Close();

                    return rptListaCliente;

                }
                catch (Exception ex)
                {
                    rptListaCliente = null;
                    return rptListaCliente;
                }
            }
        }


        public bool RegistrarCliente(Cliente oCliente)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarCliente", oConexion);
                    cmd.Parameters.AddWithValue("TipoDocumento", oCliente.TipoDocumento);
                    cmd.Parameters.AddWithValue("NumeroDocumento", oCliente.NumeroDocumento);
                    cmd.Parameters.AddWithValue("Nombre", oCliente.Nombre);
                    cmd.Parameters.AddWithValue("Direccion", oCliente.Direccion);
                    cmd.Parameters.AddWithValue("Telefono", oCliente.Telefono);
                    cmd.Parameters.AddWithValue("Ciudad", oCliente.Ciudad);
                    cmd.Parameters.AddWithValue("Barrio", oCliente.Barrio);
                    cmd.Parameters.AddWithValue("Calle", oCliente.Calle);
                    cmd.Parameters.AddWithValue("NumeroCasa", oCliente.NumeroCasa);
                    cmd.Parameters.AddWithValue("Referencia", oCliente.Referencia);
                    cmd.Parameters.AddWithValue("Geolocalizacion", string.IsNullOrEmpty(oCliente.Geolocalizacion) ? (object)DBNull.Value : oCliente.Geolocalizacion); // Agregado
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

        public bool ModificarCliente(Cliente oCliente)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarCliente", oConexion);
                    cmd.Parameters.AddWithValue("IdCliente", oCliente.IdCliente);
                    cmd.Parameters.AddWithValue("TipoDocumento", oCliente.TipoDocumento);
                    cmd.Parameters.AddWithValue("NumeroDocumento", oCliente.NumeroDocumento);
                    cmd.Parameters.AddWithValue("Nombre", oCliente.Nombre);
                    cmd.Parameters.AddWithValue("Direccion", oCliente.Direccion);
                    cmd.Parameters.AddWithValue("Telefono", oCliente.Telefono);
                    cmd.Parameters.AddWithValue("Activo", oCliente.Activo);
                    cmd.Parameters.AddWithValue("Ciudad", oCliente.Ciudad);
                    cmd.Parameters.AddWithValue("Barrio", oCliente.Barrio);
                    cmd.Parameters.AddWithValue("Calle", oCliente.Calle);
                    cmd.Parameters.AddWithValue("NumeroCasa", oCliente.NumeroCasa);
                    cmd.Parameters.AddWithValue("Referencia", oCliente.Referencia);
                    cmd.Parameters.AddWithValue("Geolocalizacion", string.IsNullOrEmpty(oCliente.Geolocalizacion) ? (object)DBNull.Value : oCliente.Geolocalizacion); // Agregado
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

        public bool EliminarCliente(int id)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_EliminarCliente", oConexion);
                    cmd.Parameters.AddWithValue("IdCliente", id);
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


    }
}

