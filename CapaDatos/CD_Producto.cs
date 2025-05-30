using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;


namespace CapaDatos
{
    public class CD_Producto
    {
        public static CD_Producto _instancia = null;

        private CD_Producto()
        {

        }

        public static CD_Producto Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Producto();
                }
                return _instancia;
            }
        }

        public List<Producto> ObtenerProducto()
        {
            List<Producto> rptListaProducto = new List<Producto>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerProductos", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaProducto.Add(new Producto()
                        {
                            IdProducto = Convert.ToInt32(dr["IdProducto"].ToString()),
                            Codigo = dr["Codigo"].ToString(),
                            ValorCodigo = Convert.ToInt32(dr["ValorCodigo"].ToString()),
                            Nombre = dr["Nombre"].ToString(),
                            Descripcion = dr["DescripcionProducto"].ToString(),
                            IdCategoria = Convert.ToInt32(dr["IdCategoria"].ToString()),
                            oCategoria = new Categoria() { Descripcion = dr["DescripcionCategoria"].ToString() },
                            Activo = Convert.ToBoolean(dr["Activo"].ToString())
                        });
                    }
                    dr.Close();

                    return rptListaProducto;

                }
                catch (Exception ex)
                {
                    rptListaProducto = null;
                    return rptListaProducto;
                }
            }
        }

        public bool RegistrarProducto(Producto oProducto)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarProducto", oConexion);
                    cmd.Parameters.AddWithValue("Nombre", oProducto.Nombre);
                    cmd.Parameters.AddWithValue("Descripcion", oProducto.Descripcion);
                    cmd.Parameters.AddWithValue("IdCategoria", oProducto.IdCategoria);
                    cmd.Parameters.AddWithValue("PrecioVenta", oProducto.PrecioVenta);
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

        public bool ModificarProducto(Producto oProducto)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarProducto", oConexion);
                    cmd.Parameters.AddWithValue("IdProducto", oProducto.IdProducto);
                    cmd.Parameters.AddWithValue("Nombre", oProducto.Nombre);
                    cmd.Parameters.AddWithValue("Descripcion", oProducto.Descripcion);
                    cmd.Parameters.AddWithValue("IdCategoria", oProducto.IdCategoria);
                    cmd.Parameters.AddWithValue("Activo", oProducto.Activo);
                    cmd.Parameters.AddWithValue("PrecioVenta", oProducto.PrecioVenta);
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

        public bool EliminarProducto(int IdProducto)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_EliminarProducto", oConexion);
                    cmd.Parameters.AddWithValue("IdProducto", IdProducto);
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

        public List<PrecioVenta> ObtenerPorProducto(int idProducto)
        {
            List<PrecioVenta> lista = new List<PrecioVenta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerHistorialPreciosVentaPorProducto", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("IdProducto", idProducto);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        lista.Add(new PrecioVenta()
                        {
                            IdPrecioVenta = Convert.ToInt32(dr["IdPrecioVenta"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"]),
                            FechaInicioVigencia = Convert.ToDateTime(dr["FechaInicioVigencia"]),
                            FechaFinVigencia = dr["FechaFinVigencia"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaFinVigencia"])
                        });
                    }
                    dr.Close();

                    return lista;
                }
                catch (Exception)
                {
                    return null;
                }
            }
        }

        public bool RegistrarPrecioVenta(PrecioVenta precio)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_RegistrarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.AddWithValue("IdProducto", precio.IdProducto);
                cmd.Parameters.AddWithValue("PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("FechaInicio", precio.FechaInicioVigencia);
                cmd.Parameters.AddWithValue("FechaFin", (object)precio.FechaFinVigencia ?? DBNull.Value);

                var paramResultado = cmd.Parameters.Add("Resultado", SqlDbType.Bit);
                paramResultado.Direction = ParameterDirection.Output;

                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    resultado = Convert.ToBoolean(paramResultado.Value);
                }
                catch (Exception)
                {
                    resultado = false;
                }
            }
            return resultado;
        }



        public bool ModificarPrecioVenta(PrecioVenta precio)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ModificarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.AddWithValue("IdPrecioVenta", precio.IdPrecioVenta);
                cmd.Parameters.AddWithValue("IdProducto", precio.IdProducto);
                cmd.Parameters.AddWithValue("PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("FechaInicioVigencia", precio.FechaInicioVigencia);
                cmd.Parameters.AddWithValue("FechaFinVigencia", (object)precio.FechaFinVigencia ?? DBNull.Value);

                cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch (Exception)
                {
                    resultado = false;
                }
            }
            return resultado;
        }

        public bool EliminarPrecioVenta(int idPrecioVenta)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_EliminarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.AddWithValue("IdPrecioVenta", idPrecioVenta);
                cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch (Exception)
                {
                    resultado = false;
                }
            }
            return resultado;
        }
        public List<PrecioVenta> ObtenerHistorialPreciosVentaPorProducto(int idProducto)
        {
            List<PrecioVenta> lista = new List<PrecioVenta>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerHistorialPreciosVentaPorProducto", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdProducto", idProducto);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        lista.Add(new PrecioVenta()
                        {
                            IdPrecioVenta = Convert.ToInt32(dr["IdPrecioVenta"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"]), // Aquí mapeo con la propiedad Precio
                            FechaInicioVigencia = Convert.ToDateTime(dr["FechaInicio"]),
                            FechaFinVigencia = dr["FechaFin"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaFin"])
                        });
                    }

                    dr.Close();
                }
                catch (Exception)
                {
                    lista = null;
                }
            }

            return lista;
        }

        // Método para actualizar precio venta usando SP
        public bool ActualizarPrecioVenta(PrecioVenta precio)
        {
            using (SqlConnection conn = new SqlConnection(Conexion.CN))
            using (SqlCommand cmd = new SqlCommand("sp_ActualizarPrecioVenta", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;

                cmd.Parameters.AddWithValue("@IdPrecioVenta", precio.IdPrecioVenta);
                cmd.Parameters.AddWithValue("@PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("@FechaInicio", precio.FechaInicioVigencia);
                if (precio.FechaFinVigencia.HasValue)
                    cmd.Parameters.AddWithValue("@FechaFin", precio.FechaFinVigencia.Value);
                else
                    cmd.Parameters.AddWithValue("@FechaFin", DBNull.Value);

                conn.Open();

                cmd.Parameters.Add("@FilasAfectadas", SqlDbType.Int).Direction = ParameterDirection.Output;
                // ejecutar
                cmd.ExecuteNonQuery();
                int filasAfectadas = (int)cmd.Parameters["@FilasAfectadas"].Value;


                return filasAfectadas > 0;
            }
        }

        public PrecioVenta ObtenerHistorialPreciosVentaPorId(int idPrecioVenta)
        {
            PrecioVenta resultado = null;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerPrecioVentaPorId", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdPrecioVenta", idPrecioVenta);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    if (dr.Read())
                    {
                        resultado = new PrecioVenta()
                        {
                            IdPrecioVenta = Convert.ToInt32(dr["IdPrecioVenta"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"]),
                            FechaInicioVigencia = Convert.ToDateTime(dr["FechaInicio"]),
                            FechaFinVigencia = dr["FechaFin"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaFin"])
                        };
                    }

                    dr.Close();
                }
                catch (Exception)
                {
                    resultado = null;
                }
            }

            return resultado;
        }


    }
}
