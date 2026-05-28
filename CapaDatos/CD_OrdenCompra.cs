using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Xml;
using System.Xml.Linq;

namespace CapaDatos
{
    /// <summary>
    /// Capa de datos para el modulo Orden de Compra.
    /// Usa los mismos patrones de CD_Compra: Singleton, SqlConnection
    /// via Conexion.CN, stored procedures con parametros @Resultado
    /// y @Mensaje de salida.
    /// </summary>
    public partial class CD_OrdenCompra
    {
        private static CD_OrdenCompra _instancia = null;

        private CD_OrdenCompra() { }

        public static CD_OrdenCompra Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_OrdenCompra();
                return _instancia;
            }
        }

        // ============================================================
        //  REGISTRAR
        // ============================================================

        /// <summary>
        /// Registra una Orden de Compra a partir del XML enviado desde
        /// la vista. Retorna el IdOrdenCompra generado.
        /// </summary>
        public (bool resultado, string mensaje, int idGenerado) RegistrarOrdenCompra(string xmlDetalle)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarOrdenCompra", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("@Detalle", SqlDbType.Xml).Value = xmlDetalle;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@IdGenerado", SqlDbType.Int).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int id = cmd.Parameters["@IdGenerado"].Value != DBNull.Value
                           ? Convert.ToInt32(cmd.Parameters["@IdGenerado"].Value)
                           : 0;

                    return (ok, msg, id);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar la orden: " + ex.Message, 0);
                }
            }
        }

        // ============================================================
        //  LISTAR
        // ============================================================

        public List<OrdenCompra> ObtenerListaOrdenCompra(
            DateTime FechaInicio, DateTime FechaFin,
            int IdProveedor, int IdTienda, string Estado)
        {
            List<OrdenCompra> lista = new List<OrdenCompra>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaOrdenCompra", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FechaInicio", FechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin",    FechaFin);
                cmd.Parameters.AddWithValue("@IdProveedor", IdProveedor);
                cmd.Parameters.AddWithValue("@IdTienda",    IdTienda);
                cmd.Parameters.AddWithValue("@Estado",      (object)Estado ?? DBNull.Value);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new OrdenCompra()
                            {
                                IdOrdenCompra         = Convert.ToInt32(dr["IdOrdenCompra"]),
                                NumeroOrden           = dr["NumeroOrden"].ToString(),
                                oProveedor = new Proveedor()
                                {
                                    IdProveedor = Convert.ToInt32(dr["IdProveedor"]),
                                    RazonSocial = dr["RazonSocialProveedor"].ToString()
                                },
                                oTienda = new Tienda()
                                {
                                    IdTienda = Convert.ToInt32(dr["IdTienda"]),
                                    Nombre   = dr["NombreTienda"].ToString()
                                },
                                oUsuarioRegistro = new Usuario()
                                {
                                    IdUsuario = Convert.ToInt32(dr["IdUsuarioRegistro"]),
                                    Nombres   = dr["NombreUsuarioRegistro"].ToString()
                                },
                                oUsuarioAprobador = dr["IdUsuarioAprobador"] != DBNull.Value
                                    ? new Usuario()
                                    {
                                        IdUsuario = Convert.ToInt32(dr["IdUsuarioAprobador"]),
                                        Nombres   = dr["NombreUsuarioAprobador"].ToString()
                                    }
                                    : null,
                                FechaOrden            = dr["FechaOrden"].ToString(),
                                FechaEntregaEstimada  = dr["FechaEntregaEstimada"].ToString(),
                                Observacion           = dr["Observacion"].ToString(),
                                TotalEstimado         = Convert.ToDecimal(dr["TotalEstimado"]),
                                TotalEstimadoIva      = Convert.ToDecimal(dr["TotalEstimadoIva"]),
                                Estado                = dr["Estado"].ToString(),
                                FechaAprobacion       = dr["FechaAprobacion"].ToString(),
                                MotivoRechazo         = dr["MotivoRechazo"].ToString(),
                                Activo                = Convert.ToBoolean(dr["Activo"])
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<OrdenCompra>();
                }
            }

            return lista;
        }

        // ============================================================
        //  OBTENER DETALLE (XML)
        // ============================================================

        public OrdenCompra ObtenerDetalleOrdenCompra(int IdOrdenCompra)
        {
            OrdenCompra orden = null;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleOrdenCompra", oConexion);
                cmd.Parameters.AddWithValue("@IdOrdenCompra", IdOrdenCompra);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    using (XmlReader dr = cmd.ExecuteXmlReader())
                    {
                        while (dr.Read())
                        {
                            XDocument doc = XDocument.Load(dr);
                            var root = doc.Element("DETALLE_ORDEN_COMPRA");
                            if (root == null) continue;

                            var cul = new CultureInfo("es-PE");

                            // FechaOrden viene como string desde el XML (ej: "21/05/2026")
                            // FechaRegistro es DateTime → se parsea desde ese mismo valor
                            var strFechaOrden = root.Element("FechaOrden")?.Value;
                            DateTime dFechaReg = DateTime.MinValue;
                            DateTime.TryParseExact(
                                strFechaOrden,
                                new[] { "dd/MM/yyyy", "yyyy-MM-dd", "yyyy-MM-ddTHH:mm:ss", "MM/dd/yyyy" },
                                CultureInfo.InvariantCulture,
                                DateTimeStyles.None,
                                out dFechaReg);

                            orden = new OrdenCompra()
                            {
                                IdOrdenCompra        = int.Parse(root.Element("IdOrdenCompra")?.Value ?? "0"),
                                NumeroOrden          = root.Element("NumeroOrden")?.Value,
                                FechaOrden           = strFechaOrden,
                                FechaRegistro        = dFechaReg,
                                FechaEntregaEstimada = root.Element("FechaEntregaEstimada")?.Value,
                                FechaTopeEntrega     = root.Element("FechaTopeEntrega")?.Value,
                                Observacion          = root.Element("Observacion")?.Value,
                                TotalEstimado        = Convert.ToDecimal(root.Element("TotalEstimado")?.Value ?? "0", cul),
                                TotalEstimadoIva     = Convert.ToDecimal(root.Element("TotalEstimadoIva")?.Value ?? "0", cul),
                                Estado               = root.Element("Estado")?.Value,
                                FechaAprobacion      = root.Element("FechaAprobacion")?.Value,
                                MotivoRechazo        = root.Element("MotivoRechazo")?.Value
                            };

                            var prov = root.Element("DETALLE_PROVEEDOR");
                            if (prov != null)
                            {
                                orden.oProveedor = new Proveedor()
                                {
                                    IdProveedor = int.Parse(prov.Element("IdProveedor")?.Value ?? "0"),
                                    Ruc         = prov.Element("RUC")?.Value,
                                    RazonSocial = prov.Element("RazonSocial")?.Value,
                                    Telefono    = prov.Element("Telefono")?.Value,
                                    Correo      = prov.Element("Correo")?.Value,
                                    Direccion   = prov.Element("Direccion")?.Value
                                };
                            }

                            var tienda = root.Element("DETALLE_TIENDA");
                            if (tienda != null)
                            {
                                orden.oTienda = new Tienda()
                                {
                                    IdTienda  = int.Parse(tienda.Element("IdTienda")?.Value ?? "0"),
                                    RUC       = tienda.Element("RUC")?.Value,
                                    Nombre    = tienda.Element("Nombre")?.Value,
                                    Direccion = tienda.Element("Direccion")?.Value
                                };
                            }

                            var usr = root.Element("DETALLE_USUARIO");
                            if (usr != null)
                            {
                                orden.oUsuarioRegistro = new Usuario()
                                {
                                    IdUsuario = int.Parse(usr.Element("IdUsuario")?.Value ?? "0"),
                                    Nombres   = usr.Element("Nombres")?.Value,
                                    Apellidos = usr.Element("Apellidos")?.Value
                                };
                            }

                            var detalle = root.Element("DETALLE_PRODUCTO");
                            if (detalle != null)
                            {
                                orden.oListaDetalle = detalle.Elements("PRODUCTO")
                                    .Select(p => new DetalleOrdenCompra()
                                    {
                                        IdDetalleOrdenCompra = int.Parse(p.Element("IdDetalleOrdenCompra")?.Value ?? "0"),
                                        oProducto = new Producto()
                                        {
                                            IdProducto   = int.Parse(p.Element("IdProducto")?.Value ?? "0"),
                                            Codigo       = p.Element("CodigoProducto")?.Value,
                                            Nombre       = p.Element("NombreProducto")?.Value,
                                            UnidadMedida = p.Element("UnidadMedida")?.Value ?? "Unidad"
                                        },
                                        Cantidad          = int.Parse(p.Element("Cantidad")?.Value ?? "0"),
                                        CantidadFacturada = int.Parse(p.Element("CantidadFacturada")?.Value ?? "0"),
                                        PrecioUnitario    = Convert.ToDecimal(p.Element("PrecioUnitario")?.Value ?? "0", cul),
                                        IvaPorcentaje     = Convert.ToDecimal(p.Element("IvaPorcentaje")?.Value ?? "0", cul),
                                        TotalLinea        = Convert.ToDecimal(p.Element("TotalLinea")?.Value ?? "0", cul),
                                        TotalLineaIva     = Convert.ToDecimal(p.Element("TotalLineaIva")?.Value ?? "0", cul)
                                    }).ToList();
                            }
                            else
                            {
                                orden.oListaDetalle = new List<DetalleOrdenCompra>();
                            }
                        }
                    }
                }
                catch (Exception)
                {
                    orden = null;
                }
            }

            return orden;
        }

        // ============================================================
        //  APROBAR / RECHAZAR / ANULAR
        // ============================================================

        public (bool resultado, string mensaje) AprobarOrdenCompra(int idOrdenCompra, int idUsuarioAprobador, bool esSuperAdmin = false)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AprobarOrdenCompra", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdOrdenCompra",      idOrdenCompra);
                    cmd.Parameters.AddWithValue("@IdUsuarioAprobador", idUsuarioAprobador);
                    cmd.Parameters.AddWithValue("@EsSuperAdmin",       esSuperAdmin ? 1 : 0);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al aprobar: " + ex.Message);
                }
            }
        }

        public (bool resultado, string mensaje) RechazarOrdenCompra(
            int idOrdenCompra, int idUsuarioAprobador, int idMotivoRechazo, string motivo = "")
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RechazarOrdenCompra", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdOrdenCompra", idOrdenCompra);
                    cmd.Parameters.AddWithValue("@IdUsuarioAprobador", idUsuarioAprobador);
                    cmd.Parameters.AddWithValue("@IdMotivoRechazo", idMotivoRechazo);
                    cmd.Parameters.AddWithValue("@Motivo", (object)(string.IsNullOrWhiteSpace(motivo) ? null : motivo) ?? DBNull.Value);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al rechazar: " + ex.Message);
                }
            }
        }

        public (bool resultado, string mensaje) AnularOrdenCompra(int idOrdenCompra, int idUsuario = 0)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AnularOrdenCompra", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdOrdenCompra", idOrdenCompra);
                    cmd.Parameters.AddWithValue("@IdUsuario",     idUsuario);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al anular: " + ex.Message);
                }
            }
        }

        // ============================================================
        //  APOYO: ordenes aprobadas abiertas por proveedor/tienda
        //  (utiles para vincular a una factura de Compra)
        // ============================================================

        public List<OrdenCompra> ObtenerOrdenesAprobadasPorProveedor(int idProveedor, int idTienda)
        {
            List<OrdenCompra> lista = new List<OrdenCompra>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerOrdenesAprobadasPorProveedor", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdProveedor", idProveedor);
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new OrdenCompra()
                            {
                                IdOrdenCompra    = Convert.ToInt32(dr["IdOrdenCompra"]),
                                NumeroOrden      = dr["NumeroOrden"].ToString(),
                                FechaOrden       = dr["FechaOrden"].ToString(),
                                TotalEstimado    = Convert.ToDecimal(dr["TotalEstimado"]),
                                TotalEstimadoIva = Convert.ToDecimal(dr["TotalEstimadoIva"]),
                                Estado           = dr["Estado"].ToString()
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<OrdenCompra>();
                }
            }

            return lista;
        }
    }
}
