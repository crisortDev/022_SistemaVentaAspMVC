using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;

namespace CapaDatos
{
    public class CD_Compra
    {
        public static CD_Compra _instancia = null;

        private CD_Compra()
        {

        }

        public static CD_Compra Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Compra();
                }
                return _instancia;
            }
        }

        public bool RegistrarCompra(string Detalle)
        {


            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarCompra", oConexion);
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


        public Compra ObtenerDetalleCompra(int IdCompra)
        {
            Compra rptDetalleCompra = new Compra();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleCompra", oConexion);
                cmd.Parameters.AddWithValue("@IdCompra", IdCompra);
                cmd.CommandType = CommandType.StoredProcedure;


                try
                {
                    oConexion.Open();
                    using (XmlReader dr = cmd.ExecuteXmlReader())
                    {
                        while (dr.Read())
                        {
                            XDocument doc = XDocument.Load(dr);
                            if (doc.Element("DETALLE_COMPRA") != null)
                            {
                                rptDetalleCompra = (from dato in doc.Elements("DETALLE_COMPRA")
                                                     select new Compra()
                                                     {
                                                         Codigo = dato.Element("Codigo")?.Value ?? "",
                                                         TotalCosto = Convert.ToDecimal(dato.Element("TotalCosto")?.Value ?? "0", new CultureInfo("es-PE")),
                                                         FechaCompra = dato.Element("FechaCompra")?.Value ?? "",
                                                         FechaVencimientoTimbrado = dato.Element("FechaVencimientoTimbrado")?.Value ?? "",
                                                         NumeroTimbrado = dato.Element("NumeroTimbrado")?.Value ?? "",
                                                         NumeroFactura = dato.Element("NumeroFactura")?.Value ?? "",
                                                         TotalCostoIvaIncluido = Convert.ToDecimal(dato.Element("TotalCostoIvaIncluido")?.Value ?? "0", new CultureInfo("es-PE")),
                                                     }).FirstOrDefault();
                                rptDetalleCompra.oProveedor = (from dato in doc.Element("DETALLE_COMPRA").Elements("DETALLE_PROVEEDOR")
                                                               select new Proveedor()
                                                               {
                                                                   Ruc = dato.Element("RUC").Value,
                                                                   RazonSocial = dato.Element("RazonSocial").Value,
                                                               }).FirstOrDefault();
                                rptDetalleCompra.oTienda = (from dato in doc.Element("DETALLE_COMPRA").Elements("DETALLE_TIENDA")
                                                            select new Tienda()
                                                            {
                                                                RUC = dato.Element("RUC").Value,
                                                                Nombre = dato.Element("Nombre").Value,
                                                                Direccion = dato.Element("Direccion").Value
                                                            }).FirstOrDefault();
                                rptDetalleCompra.oListaDetalleCompra = (from producto in doc.Element("DETALLE_COMPRA").Element("DETALLE_PRODUCTO").Elements("PRODUCTO")
                                                                        select new DetalleCompra()
                                                                        {
                                                                            Cantidad = int.Parse(producto.Element("Cantidad").Value),
                                                                            oProducto = new Producto() { Nombre = producto.Element("NombreProducto").Value },
                                                                            PrecioUnitarioCompra = Convert.ToDecimal(producto.Element("PrecioUnitarioCompra").Value, new CultureInfo("es-PE")),
                                                                            TotalCosto = Convert.ToDecimal(producto.Element("TotalCosto").Value, new CultureInfo("es-PE")),
                                                                            TotalCostoIvaIncluido = Convert.ToDecimal(producto.Element("TotalCostoIvaIncluido").Value, new CultureInfo("es-PE"))
                                                                        }).ToList();
                            }
                            else
                            {
                                rptDetalleCompra = null;
                            }
                        }

                        dr.Close();

                    }

                    return rptDetalleCompra;
                }
                catch (Exception ex)
                {
                    rptDetalleCompra = null;
                    return rptDetalleCompra;
                }
            }
        }




        public List<Compra> ObtenerListaCompra(DateTime FechaInicio, DateTime FechaFin, int IdProveedor, int IdTienda)
        {
            List<Compra> rptListaCompra = new List<Compra>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaCompra", oConexion);
                cmd.Parameters.AddWithValue("@FechaInicio", FechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", FechaFin);
                cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                cmd.Parameters.AddWithValue("@IdTienda", IdTienda);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaCompra.Add(new Compra()
                        {
                            IdCompra = Convert.ToInt32(dr["IdCompra"].ToString()),
                            NumeroCompra = dr["NumeroCompra"].ToString(),
                            oProveedor = new Proveedor() { RazonSocial = dr["RazonSocial"].ToString() },
                            oTienda = new Tienda() { Nombre = dr["Nombre"].ToString() },
                            FechaCompra = dr["FechaCompra"].ToString(),
                            TotalCosto = Convert.ToDecimal(dr["TotalCosto"].ToString(), new CultureInfo("es-PE"))
                        });
                    }
                    dr.Close();

                    return rptListaCompra;

                }
                catch (Exception ex)
                {
                    rptListaCompra = null;
                    return rptListaCompra;
                }
            }
        }

        public string ValidaStockMaximo(int IdProducto, int Cantidad, int Tienda)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ValidaStockMaximo", oConexion);
                    cmd.Parameters.Add("IdProducto", SqlDbType.Int).Value = IdProducto;
                    cmd.Parameters.Add("Cantidad", SqlDbType.Int).Value = Cantidad;
                    cmd.Parameters.Add("IdTienda", SqlDbType.Int).Value = Tienda;

                    // Parámetros de salida
                    cmd.Parameters.Add("Resultado", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("Mensaje", SqlDbType.VarChar, 255).Direction = ParameterDirection.Output;

                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    // Obtener valores de salida
                    int resultado = Convert.ToInt32(cmd.Parameters["Resultado"].Value);
                    string mensaje = cmd.Parameters["Mensaje"].Value?.ToString() ?? "Sin mensaje"; // Manejo de null

                    // Concatenar resultado y mensaje
                    return $"{resultado},{mensaje}";
                }
                catch (Exception ex)
                {
                    // Devuelve un código de error y el mensaje de la excepción
                    return $"-1,Error al validar stock: {ex.Message}";
                }
            }
        }
        public List<HistorialPrecioCompra> ObtenerHistorialPrecioCompra(int idproducto)
        {
            List<HistorialPrecioCompra> lista = new List<HistorialPrecioCompra>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("sp_ObtenerHistorialPrecioCompra", oConexion);
                cmd.Parameters.AddWithValue("@IdProducto", idproducto);
                cmd.CommandType = CommandType.StoredProcedure;

                oConexion.Open();
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        lista.Add(new HistorialPrecioCompra()
                        {
                            FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]).ToString("yyyy-MM-dd"),
                            PrecioCompra = Convert.ToDecimal(dr["PrecioCompra"]),
                            Observaciones = dr["Observaciones"] != DBNull.Value ? dr["Observaciones"].ToString() : ""
                        });
                    }
                }
            }

            return lista;
        }


    }


}
