using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;

namespace CapaDatos
{
    public class CD_Venta
    {
        private static CD_Venta _instancia = null;
        private CD_Venta() { }
        public static CD_Venta Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_Venta();
                return _instancia;
            }
        }

        // ----------------------------------------------------------------
        //  DATOS TRIBUTARIOS (timbrado vigente + próximo número de factura)
        // ----------------------------------------------------------------
        public DatosTributarios ObtenerDatosTributarios()
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDatosTributarios", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            return new DatosTributarios()
                            {
                                NumeroTimbrado       = dr["NumeroTimbrado"].ToString(),
                                VencimientoTimbrado  = dr["VencimientoTimbrado"].ToString(),
                                Establecimiento      = dr["Establecimiento"].ToString(),
                                PuntoExpedicion      = dr["PuntoExpedicion"].ToString(),
                                SecuenciaActual      = Convert.ToInt32(dr["SecuenciaActual"]),
                                ProximoNumeroFactura = dr["ProximoNumeroFactura"].ToString()
                            };
                        }
                    }
                    return null;
                }
                catch (Exception)
                {
                    return null;
                }
            }
        }

        // ----------------------------------------------------------------
        //  REGISTRAR VENTA DIRECTA (Cajero hace todo en un paso)
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idVenta, string numeroFactura) RegistrarVentaDirecta(
            int idTienda, int idUsuario, int? idCliente, int idFormaCobro,
            decimal importeRecibido, string detalleXml)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarVentaDirecta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    cmd.Parameters.AddWithValue("@IdCliente",
                        idCliente.HasValue ? (object)idCliente.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdFormaCobro", idFormaCobro);
                    cmd.Parameters.AddWithValue("@ImporteRecibido", importeRecibido);
                    cmd.Parameters.Add("@DetalleXml", SqlDbType.Xml).Value = detalleXml;

                    cmd.Parameters.Add("@IdVentaGenerada", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@NumeroFactura", SqlDbType.VarChar, 20).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int id = cmd.Parameters["@IdVentaGenerada"].Value != DBNull.Value
                           ? Convert.ToInt32(cmd.Parameters["@IdVentaGenerada"].Value) : 0;
                    string nroFac = cmd.Parameters["@NumeroFactura"].Value?.ToString() ?? "";

                    return (ok, msg, id, nroFac);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar venta: " + ex.Message, 0, "");
                }
            }
        }

        // ----------------------------------------------------------------
        //  FACTURAR DESDE ORDEN DE VENTA (Pre-venta → Factura)
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idVenta, string numeroFactura) FacturarDesdeOrdenVenta(
            int idOrdenVenta, int idUsuarioCajero, int? idCliente,
            int idFormaCobro, decimal importeRecibido)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_FacturarDesdeOrdenVenta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdOrdenVenta", idOrdenVenta);
                    cmd.Parameters.AddWithValue("@IdUsuarioCajero", idUsuarioCajero);
                    cmd.Parameters.AddWithValue("@IdCliente",
                        idCliente.HasValue ? (object)idCliente.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdFormaCobro", idFormaCobro);
                    cmd.Parameters.AddWithValue("@ImporteRecibido", importeRecibido);

                    cmd.Parameters.Add("@IdVentaGenerada", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@NumeroFactura", SqlDbType.VarChar, 20).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int id = cmd.Parameters["@IdVentaGenerada"].Value != DBNull.Value
                           ? Convert.ToInt32(cmd.Parameters["@IdVentaGenerada"].Value) : 0;
                    string nroFac = cmd.Parameters["@NumeroFactura"].Value?.ToString() ?? "";

                    return (ok, msg, id, nroFac);
                }
                catch (Exception ex)
                {
                    return (false, "Error al facturar pre-venta: " + ex.Message, 0, "");
                }
            }
        }

        // ----------------------------------------------------------------
        //  LISTAR VENTAS (v2)
        // ----------------------------------------------------------------
        public List<Venta> ObtenerListaVenta_v2(
            int idTienda, DateTime fechaInicio, DateTime fechaFin,
            string numeroFactura, string documentoCliente, string nombreCliente,
            string tipoFlujo, string estado)
        {
            List<Venta> lista = new List<Venta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaVenta_v2", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
                cmd.Parameters.AddWithValue("@NumeroFactura", numeroFactura ?? "");
                cmd.Parameters.AddWithValue("@DocumentoCliente", documentoCliente ?? "");
                cmd.Parameters.AddWithValue("@NombreCliente", nombreCliente ?? "");
                cmd.Parameters.AddWithValue("@TipoFlujo", tipoFlujo ?? "");
                cmd.Parameters.AddWithValue("@Estado", estado ?? "");

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Venta()
                            {
                                IdVenta          = Convert.ToInt32(dr["IdVenta"]),
                                NumeroFactura    = dr["NumeroFactura"].ToString(),
                                TipoFlujo        = dr["TipoFlujo"].ToString(),
                                Estado           = dr["Estado"].ToString(),
                                TotalCosto       = Convert.ToDecimal(dr["TotalCosto"]),
                                FormaCobro       = dr["FormaCobro"].ToString(),
                                FechaRegistro    = dr["FechaRegistro"].ToString(),
                                NombreCliente    = dr["NombreCliente"].ToString(),
                                DocumentoCliente = dr["DocumentoCliente"].ToString(),
                                NombreUsuario    = dr["NombreUsuario"].ToString(),
                                NombreTienda     = dr["NombreTienda"].ToString(),
                                NumeroOV         = dr["NumeroOV"] != DBNull.Value
                                                 ? dr["NumeroOV"].ToString() : ""
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<Venta>();
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  DETALLE VENTA v2 (2 resultsets: cabecera KuDE + productos)
        // ----------------------------------------------------------------
        public Venta ObtenerDetalleVenta_v2(int idVenta)
        {
            Venta venta = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleVenta_v2", oConexion);
                cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        // RS1: cabecera KuDE
                        if (dr.Read())
                        {
                            venta = new Venta()
                            {
                                IdVenta                   = Convert.ToInt32(dr["IdVenta"]),
                                NumeroFactura             = dr["NumeroFactura"].ToString(),
                                NumeroTimbrado            = dr["NumeroTimbrado"].ToString(),
                                VencimientoTimbrado       = dr["VencimientoTimbrado"].ToString(),
                                Establecimiento           = dr["Establecimiento"].ToString(),
                                PuntoExpedicion           = dr["PuntoExpedicion"].ToString(),
                                TipoFlujo                 = dr["TipoFlujo"].ToString(),
                                Estado                    = dr["Estado"].ToString(),
                                FechaRegistro             = dr["FechaRegistro"].ToString(),
                                TotalCosto                = Convert.ToDecimal(dr["TotalCosto"]),
                                ImporteRecibido           = Convert.ToDecimal(dr["ImporteRecibido"]),
                                ImporteCambio             = Convert.ToDecimal(dr["ImporteCambio"]),
                                Gravado10                 = Convert.ToDecimal(dr["Gravado10"]),
                                Gravado5Base              = Convert.ToDecimal(dr["Gravado5Base"]),
                                IVA10                     = Convert.ToDecimal(dr["IVA10"]),
                                IVA5                      = Convert.ToDecimal(dr["IVA5"]),
                                Exento0                   = Convert.ToDecimal(dr["Exento0"]),
                                FormaCobro                = dr["FormaCobro"].ToString(),
                                NombreCliente             = dr["NombreCliente"].ToString(),
                                DocumentoCliente          = dr["DocumentoCliente"].ToString(),
                                NombreCajero              = dr["NombreCajero"].ToString(),
                                NombreEmisor              = dr["NombreEmisor"].ToString(),
                                RUCEmisor                 = dr["RUCEmisor"].ToString(),
                                DireccionEmisor           = dr["DireccionEmisor"].ToString(),
                                TelefonoEmisor            = dr["TelefonoEmisor"].ToString(),
                                NumeroOV                  = dr["NumeroOV"] != DBNull.Value
                                                          ? dr["NumeroOV"].ToString() : "",
                                oListaDetalleVenta        = new System.Collections.Generic.List<DetalleVenta>()
                            };
                        }

                        // RS2: productos
                        if (venta != null && dr.NextResult())
                        {
                            while (dr.Read())
                            {
                                venta.oListaDetalleVenta.Add(new DetalleVenta()
                                {
                                    IdProducto             = Convert.ToInt32(dr["IdProducto"]),
                                    CodigoProducto         = dr["CodigoProducto"].ToString(),
                                    NombreProducto         = dr["NombreProducto"].ToString(),
                                    Cantidad               = Convert.ToInt32(dr["Cantidad"]),
                                    PrecioUnidad           = Convert.ToDecimal(dr["PrecioUnidad"]),
                                    IvaPorcentaje          = Convert.ToDecimal(dr["IvaPorcentaje"]),
                                    MontoIva               = Convert.ToDecimal(dr["MontoIva"]),
                                    ImporteSinIva          = Convert.ToDecimal(dr["ImporteSinIva"]),
                                    ImporteTotal           = Convert.ToDecimal(dr["ImporteTotal"]),
                                    ImporteTotalIvaIncluido= Convert.ToDecimal(dr["ImporteTotalIvaIncluido"])
                                });
                            }
                        }
                    }
                }
                catch (Exception)
                {
                    venta = null;
                }
            }
            return venta;
        }

        // ----------------------------------------------------------------
        //  ANULAR VENTA
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje) AnularVenta(
            int idVenta, int idUsuario, string motivoAnulacion)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AnularVenta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    cmd.Parameters.AddWithValue("@MotivoAnulacion",
                        string.IsNullOrWhiteSpace(motivoAnulacion) ? (object)DBNull.Value : motivoAnulacion);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al anular venta: " + ex.Message);
                }
            }
        }

        // ----------------------------------------------------------------
        //  FORMAS DE COBRO
        // ----------------------------------------------------------------
        public List<FormaCobro> ObtenerFormasCobro()
        {
            List<FormaCobro> lista = new List<FormaCobro>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT IdFormaCobro, Nombre, Activo FROM FORMA_COBRO WHERE Activo = 1 ORDER BY Nombre",
                    oConexion);
                cmd.CommandType = CommandType.Text;
                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new FormaCobro()
                            {
                                IdFormaCobro = Convert.ToInt32(dr["IdFormaCobro"]),
                                Nombre       = dr["Nombre"].ToString(),
                                Activo       = Convert.ToBoolean(dr["Activo"])
                            });
                        }
                    }
                }
                catch (Exception) { }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  MÉTODOS LEGACY (conservados para compatibilidad con vistas viejas)
        // ----------------------------------------------------------------
        public List<Venta> ObtenerListaVenta(string Codigo, DateTime FechaInicio, DateTime FechaFin,
            string NumeroDocumento, string Nombre)
        {
            List<Venta> lista = new List<Venta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaVenta", oConexion);
                cmd.Parameters.AddWithValue("@Codigo", Codigo);
                cmd.Parameters.AddWithValue("@FechaInicio", FechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", FechaFin);
                cmd.Parameters.AddWithValue("@NumeroDocumento", NumeroDocumento);
                cmd.Parameters.AddWithValue("@Nombre", Nombre);
                cmd.CommandType = CommandType.StoredProcedure;
                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new Venta()
                        {
                            IdVenta          = Convert.ToInt32(dr["IdVenta"]),
                            TipoDocumento    = dr["TipoDocumento"].ToString(),
                            Codigo           = dr["Codigo"].ToString(),
                            FechaRegistro    = Convert.ToDateTime(dr["FechaRegistro"]).ToString("dd/MM/yyyy"),
                            VFechaRegistro   = Convert.ToDateTime(dr["FechaRegistro"]),
                            oCliente         = new Cliente()
                            {
                                NumeroDocumento = dr["NumeroDocumento"].ToString(),
                                Nombre          = dr["Nombre"].ToString()
                            },
                            TotalCosto             = decimal.Parse(dr["TotalCosto"].ToString()),
                            ImporteTotalIvaIncluido= decimal.Parse(dr["ImporteIvaIncluido"].ToString())
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
    }
}
