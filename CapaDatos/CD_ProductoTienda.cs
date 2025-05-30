using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaDatos
{
    public class CD_ProductoTienda
    {
        public static CD_ProductoTienda _instancia = null;

        private CD_ProductoTienda()
        {

        }

        public static CD_ProductoTienda Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_ProductoTienda();
                }
                return _instancia;
            }
        }

        public List<ProductoTienda> ObtenerProductoTienda()
        {
            List<ProductoTienda> rptListaProductoTienda = new List<ProductoTienda>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerProductoTienda", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaProductoTienda.Add(new ProductoTienda()
                        {
                            IdProductoTienda = Convert.ToInt32(dr["IdProductoTienda"].ToString()),
                            oProducto = new Producto()
                            {
                                IdProducto = Convert.ToInt32(dr["IdProducto"].ToString()),
                                Codigo = dr["CodigoProducto"].ToString(),
                                Nombre = dr["NombreProducto"].ToString(),
                                Descripcion = dr["DescripcionProducto"].ToString(),
                            },
                            oTienda = new Tienda()
                            {
                                IdTienda = Convert.ToInt32(dr["IdTienda"].ToString()),
                                RUC = dr["RUC"].ToString(),
                                Nombre = dr["NombreTienda"].ToString(),
                                Direccion = dr["DireccionTienda"].ToString(),
                            },
                            PrecioUnidadCompra = Convert.ToInt32(
                            Convert.ToDecimal(dr["PrecioUnidadCompra"].ToString(), new CultureInfo("es-PY"))),
                            PrecioVenta = Math.Truncate(Convert.ToDecimal(dr["PrecioVenta"].ToString(), new CultureInfo("es-PY"))),
                            //PrecioIvaIncluido = Math.Truncate(Convert.ToDecimal(dr["PrecioIvaIncluido"].ToString(), new CultureInfo("es-PY"))),
                            PrecioCompraIvaIncluido = Math.Truncate(Convert.ToDecimal(dr["PrecioCompraIvaIncluido"].ToString(), new CultureInfo("es-PY"))),
                            PrecioVentaIvaIncluido = Math.Truncate(Convert.ToDecimal(dr["PrecioVentaIvaIncluido"].ToString(), new CultureInfo("es-PY"))),
                            Stock = Convert.ToInt32(dr["Stock"].ToString()),
                            PorcentajeIva = Convert.ToInt32(dr["Porcentaje"].ToString()),
                            Iniciado = Convert.ToBoolean(dr["Iniciado"].ToString()),
                            
                            //PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"].ToString(), new CultureInfo("es-PE")),
                        });
                    }
                    dr.Close();

                    return rptListaProductoTienda;

                }
                catch (Exception ex)
                {
                    rptListaProductoTienda = null;
                    return rptListaProductoTienda;
                }
            }
        }

        public bool RegistrarProductoTienda(ProductoTienda oProductoTienda)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarProductoTienda", oConexion);
                    cmd.Parameters.AddWithValue("IdProducto", oProductoTienda.oProducto.IdProducto);
                    cmd.Parameters.AddWithValue("IdTienda", oProductoTienda.oTienda.IdTienda);

                    // Agregar StockMinimo y StockMaximo
                    cmd.Parameters.AddWithValue("StockMinimo", oProductoTienda.StockMinimo);
                    cmd.Parameters.AddWithValue("StockMaximo", oProductoTienda.StockMaximo);

                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch (Exception ex)
                {
                    respuesta = false;
                    // Considera registrar el error (ej: log, Debug.WriteLine)
                }
            }
            return respuesta;
        }

        public bool ModificarProductoTienda(ProductoTienda oProductoTienda)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarProductoTienda", oConexion);
                    cmd.Parameters.AddWithValue("IdProductoTienda", oProductoTienda.IdProductoTienda);
                    cmd.Parameters.AddWithValue("IdProducto", oProductoTienda.oProducto.IdProducto);
                    cmd.Parameters.AddWithValue("IdTienda", oProductoTienda.oTienda.IdTienda);
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

        public bool EliminarProductoTienda(int IdProductoTienda)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_EliminarProductoTienda", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    // Parámetro CON @
                    cmd.Parameters.AddWithValue("@IdProductoTienda", IdProductoTienda);

                    // Parámetro de salida
                    SqlParameter paramResultado = new SqlParameter("@Resultado", SqlDbType.Bit);
                    paramResultado.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(paramResultado);

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    // Obtener el valor del parámetro de salida
                    respuesta = (bool)paramResultado.Value;
                }
                catch (Exception ex)
                {
                    respuesta = false;
                    // Log del error
                }
            }
            return respuesta;
        }


        public string ControlarStock(int IdProducto, int IdTienda, int Cantidad, bool Restar)
        {
            string resultado = "";
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ControlarStock", oConexion);
                    cmd.Parameters.AddWithValue("IdProducto", IdProducto);
                    cmd.Parameters.AddWithValue("IdTienda", IdTienda);
                    cmd.Parameters.AddWithValue("Cantidad", Cantidad);
                    cmd.Parameters.AddWithValue("Restar", Restar);
                    cmd.Parameters.Add("Resultado", SqlDbType.VarChar, 255).Direction = ParameterDirection.Output;  // Cambiar BIT a VARCHAR
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    // Obtener el mensaje de la operación
                    resultado = cmd.Parameters["Resultado"].Value.ToString();
                }
                catch (Exception ex)
                {
                    resultado = "Error en la operación: " + ex.Message;
                }
            }
            return resultado;
        }

        public string BajaStockProductoTienda(int idProductoTienda, int cantidad, string motivo, int idProducto)
        {
            string resultado = "";

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_BajaStockProductoTienda", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    // Agregar los parámetros al comando
                    cmd.Parameters.AddWithValue("@IdProductoTienda", idProductoTienda);
                    cmd.Parameters.AddWithValue("@Cantidad", cantidad);
                    cmd.Parameters.AddWithValue("@Motivo", motivo);
                    cmd.Parameters.AddWithValue("@IdProducto", idProducto); // Agregar el idProducto

                    oConexion.Open();

                    // Ejecutar y obtener el mensaje del SELECT
                    resultado = cmd.ExecuteScalar().ToString();
                }
                catch (Exception ex)
                {
                    resultado = "Error: " + ex.Message;
                }
            }
            return resultado;
        }
    }
}
