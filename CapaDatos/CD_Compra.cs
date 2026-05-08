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
    public partial class CD_Compra
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

        /// <summary>
        /// Registra una compra y retorna el IdCompra generado
        /// El SP usp_RegistrarCompra inserta la compra y retorna @Resultado = 1 si éxito
        /// Luego obtenemos el IdCompra con SELECT TOP 1
        /// </summary>
        public int RegistrarCompraRetornarId(string Detalle)
        {
            int idCompra = 0;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarCompra", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("@Detalle", SqlDbType.Xml).Value = Detalle;

                    // El SP tiene 3 OUTPUT: @IdCompra, @Resultado, @Mensaje
                    SqlParameter pIdCompra = new SqlParameter("@IdCompra", SqlDbType.Int);
                    pIdCompra.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(pIdCompra);

                    SqlParameter pResultado = new SqlParameter("@Resultado", SqlDbType.Bit);
                    pResultado.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(pResultado);

                    SqlParameter pMensaje = new SqlParameter("@Mensaje", SqlDbType.NVarChar, 400);
                    pMensaje.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(pMensaje);

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool resultado = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value ?? false);
                    string mensaje = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";

                    System.Diagnostics.Debug.WriteLine($"SP usp_RegistrarCompra — Resultado: {resultado} | Mensaje: {mensaje}");

                    if (resultado)
                    {
                        // El SP ya devuelve el id con SCOPE_IDENTITY() en @IdCompra
                        object rawId = cmd.Parameters["@IdCompra"].Value;
                        if (rawId != null && rawId != DBNull.Value)
                            idCompra = Convert.ToInt32(rawId);

                        System.Diagnostics.Debug.WriteLine($"✅ Compra registrada. IdCompra: {idCompra}");
                    }
                    else
                    {
                        System.Diagnostics.Debug.WriteLine($"❌ SP retornó false. Mensaje: {mensaje}");
                        idCompra = 0;
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"❌ Error en RegistrarCompraRetornarId: {ex.Message}\nStack: {ex.StackTrace}");
                    idCompra = 0;
                }
            }
            return idCompra;
        }

        /// <summary>
        /// Vincula una compra registrada con una Orden de Compra
        /// </summary>
        public bool VincularCompraConOrdenCompra(int idCompra, int idOrdenCompra, out string mensaje)
        {
            mensaje = string.Empty;
            bool respuesta = false;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_VincularCompraOrdenCompra", oConexion);
                    cmd.Parameters.AddWithValue("@IdCompra", idCompra);
                    cmd.Parameters.AddWithValue("@IdOrdenCompra", idOrdenCompra);

                    SqlParameter pResultado = new SqlParameter("@Resultado", SqlDbType.Bit);
                    pResultado.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(pResultado);

                    SqlParameter pMensaje = new SqlParameter("@Mensaje", SqlDbType.NVarChar, 500);
                    pMensaje.Direction = ParameterDirection.Output;
                    cmd.Parameters.Add(pMensaje);

                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value ?? false);
                    mensaje = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "Operación completada";
                }
                catch (Exception ex)
                {
                    respuesta = false;
                    mensaje = "Error: " + ex.Message;
                }
            }
            return respuesta;
        }

        // 🆕 NUEVO MÉTODO: Actualizar CantidadFacturada en DetalleOrdenCompra
        public bool ActualizarCantidadFacturada(int idDetalleOrdenCompra, int cantidadAgregar, out string mensaje)
        {
            mensaje = "";
            try
            {
                using (SqlConnection conexion = new SqlConnection(Conexion.CN))
                {
                    string query = @"
                        UPDATE [DetalleOrdenCompra]
                        SET [CantidadFacturada] = [CantidadFacturada] + @cantidadAgregar
                        WHERE [IdDetalleOrdenCompra] = @idDetalleOrdenCompra
                        AND ([CantidadFacturada] + @cantidadAgregar) <= [Cantidad]";

                    using (SqlCommand comando = new SqlCommand(query, conexion))
                    {
                        comando.Parameters.AddWithValue("@idDetalleOrdenCompra", idDetalleOrdenCompra);
                        comando.Parameters.AddWithValue("@cantidadAgregar", cantidadAgregar);

                        conexion.Open();
                        int filasAfectadas = comando.ExecuteNonQuery();

                        if (filasAfectadas > 0)
                        {
                            mensaje = "CantidadFacturada actualizada correctamente";
                            return true;
                        }
                        else
                        {
                            mensaje = "No se pudo actualizar. Verifique que la cantidad no exceda la cantidad ordenada.";
                            return false;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                mensaje = ex.Message;
                return false;
            }
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
                                var root = doc.Element("DETALLE_COMPRA");
                                rptDetalleCompra = new Compra()
                                {
                                    IdCompra                 = int.Parse(root.Element("IdCompra")?.Value ?? "0"),
                                    Codigo                   = root.Element("Codigo")?.Value ?? "",
                                    NumeroFactura            = root.Element("NumeroFactura")?.Value ?? "",
                                    NumeroTimbrado           = root.Element("NumeroTimbrado")?.Value ?? "",
                                    FechaVencimientoTimbrado = root.Element("FechaVencimientoTimbrado")?.Value ?? "",
                                    FechaCompra              = root.Element("FechaCompra")?.Value ?? "",
                                    FechaFactura             = root.Element("FechaFactura")?.Value ?? "",
                                    FechaEntrega             = root.Element("FechaEntrega")?.Value ?? "",
                                    TotalCosto               = Convert.ToDecimal(root.Element("TotalCosto")?.Value ?? "0", new CultureInfo("es-PE")),
                                    TotalCostoIvaIncluido    = Convert.ToDecimal(root.Element("TotalCostoIvaIncluido")?.Value ?? "0", new CultureInfo("es-PE")),
                                    Estado                   = root.Element("Estado")?.Value ?? "",
                                    EstadoRecepcion          = root.Element("EstadoRecepcion")?.Value ?? "",
                                    MontoNotaCredito         = root.Element("MontoNotaCredito") != null
                                                               ? Convert.ToDecimal(root.Element("MontoNotaCredito").Value, new CultureInfo("es-PE"))
                                                               : (decimal?)null,
                                    NumeroOrden              = root.Element("DETALLE_OC")?.Element("NumeroOrden")?.Value ?? ""
                                };

                                rptDetalleCompra.oProveedor = root.Element("DETALLE_PROVEEDOR") != null
                                    ? new Proveedor()
                                      {
                                          Ruc         = root.Element("DETALLE_PROVEEDOR").Element("RUC")?.Value ?? "",
                                          RazonSocial = root.Element("DETALLE_PROVEEDOR").Element("RazonSocial")?.Value ?? "",
                                          Telefono    = root.Element("DETALLE_PROVEEDOR").Element("Telefono")?.Value ?? "",
                                          Correo      = root.Element("DETALLE_PROVEEDOR").Element("Correo")?.Value ?? "",
                                          Direccion   = root.Element("DETALLE_PROVEEDOR").Element("Direccion")?.Value ?? ""
                                      }
                                    : new Proveedor();

                                rptDetalleCompra.oTienda = root.Element("DETALLE_TIENDA") != null
                                    ? new Tienda()
                                      {
                                          RUC       = root.Element("DETALLE_TIENDA").Element("RUC")?.Value ?? "",
                                          Nombre    = root.Element("DETALLE_TIENDA").Element("Nombre")?.Value ?? "",
                                          Direccion = root.Element("DETALLE_TIENDA").Element("Direccion")?.Value ?? ""
                                      }
                                    : new Tienda();
                                var detalleProductoEl = doc.Element("DETALLE_COMPRA")?.Element("DETALLE_PRODUCTO");
                                rptDetalleCompra.oListaDetalleCompra = detalleProductoEl != null
                                    ? (from producto in detalleProductoEl.Elements("PRODUCTO")
                                       select new DetalleCompra()
                                       {
                                           Cantidad             = int.Parse(producto.Element("Cantidad")?.Value ?? "0"),
                                           CantidadRecibida     = producto.Element("CantidadRecibida") != null ? int.Parse(producto.Element("CantidadRecibida").Value) : 0,
                                           oProducto            = new Producto() { Nombre = producto.Element("NombreProducto")?.Value ?? "" },
                                           PrecioUnitarioCompra = Convert.ToDecimal(producto.Element("PrecioUnitarioCompra")?.Value ?? "0", new CultureInfo("es-PE")),
                                           TotalCosto           = Convert.ToDecimal(producto.Element("TotalCosto")?.Value            ?? "0", new CultureInfo("es-PE")),
                                           TotalCostoIvaIncluido = Convert.ToDecimal(producto.Element("TotalCostoIvaIncluido")?.Value ?? "0", new CultureInfo("es-PE")),
                                           EstadoLinea          = producto.Element("EstadoLinea")?.Value ?? ""
                                       }).ToList()
                                    : new List<DetalleCompra>();
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
