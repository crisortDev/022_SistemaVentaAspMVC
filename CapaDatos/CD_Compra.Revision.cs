using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace CapaDatos
{
    /// <summary>
    /// EXTENSIÓN de CD_Compra con la lógica nueva de recepción.
    ///
    /// IMPORTANTE: cambiar en CD_Compra.cs:
    ///     public class CD_Compra
    /// por:
    ///     public partial class CD_Compra
    ///
    /// Métodos:
    ///  - RegistrarRecepcion(idCompra, fechaFactura, fechaEntrega, lineas)
    ///  - ConfirmarCompra(idCompra)
    ///  - GenerarNotaCredito(idCompra, idMotivoNC)
    ///  - ObtenerLineasParaRecepcion(idCompra)
    /// </summary>
    public partial class CD_Compra
    {
        /// <summary>
        /// Registra la recepción de una compra: actualiza FechaFactura,
        /// FechaEntrega y la cantidad recibida por cada línea.
        /// El SP marca cada línea como Aceptada / Rechazada / NC.
        /// </summary>
        public (bool resultado, string mensaje) RegistrarRecepcion(
            int idCompra, DateTime fechaFactura, DateTime fechaEntrega,
            List<DetalleRecepcion> lineas)
        {
            // Construimos el XML <DETALLE><ITEM>...</ITEM></DETALLE>
            var xml = new StringBuilder();
            xml.Append("<DETALLE>");
            foreach (var l in lineas)
            {
                xml.Append("<ITEM>");
                xml.Append("<IdDetalleCompra>").Append(l.IdDetalleCompra).Append("</IdDetalleCompra>");
                xml.Append("<CantidadRecibida>").Append(l.CantidadRecibida).Append("</CantidadRecibida>");
                xml.Append("</ITEM>");
            }
            xml.Append("</DETALLE>");

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarRecepcionCompra", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra",     idCompra);
                    cmd.Parameters.Add("@FechaFactura", SqlDbType.Date).Value     = fechaFactura.Date;
                    cmd.Parameters.Add("@FechaEntrega", SqlDbType.DateTime).Value = fechaEntrega;
                    cmd.Parameters.Add("@Detalle", SqlDbType.Xml).Value           = xml.ToString();
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction     = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok    = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar recepción: " + ex.Message);
                }
            }
        }

        /// <summary>
        /// Confirma la compra: cambia EstadoRecepcion/Estado a Confirmada y mueve el stock.
        /// El parámetro idUsuario es obligatorio para la trazabilidad O&amp;M.
        /// </summary>
        public (bool resultado, string mensaje) ConfirmarCompra(int idCompra, int idUsuario = 0, bool esSuperAdmin = false)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ConfirmarCompraEImpactarStock", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra",     idCompra);
                    cmd.Parameters.AddWithValue("@IdUsuario",    idUsuario);
                    cmd.Parameters.AddWithValue("@EsSuperAdmin", esSuperAdmin ? 1 : 0);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok    = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al confirmar compra: " + ex.Message);
                }
            }
        }

        /// <summary>
        /// Genera la nota de crédito por las diferencias entre cantidad facturada y
        /// cantidad recibida. Si no hay diferencia, devuelve resultado=false.
        /// </summary>
        public (bool resultado, string mensaje, decimal montoNC) GenerarNotaCredito(
            int idCompra, int idMotivoNC)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_GenerarNotaCreditoPorDiferencia", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra", idCompra);
                    cmd.Parameters.AddWithValue("@IdMotivoNotaCredito", idMotivoNC);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@MontoNC", SqlDbType.Decimal).Direction = ParameterDirection.Output;
                    cmd.Parameters["@MontoNC"].Precision = 18;
                    cmd.Parameters["@MontoNC"].Scale     = 2;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok    = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    decimal monto = cmd.Parameters["@MontoNC"].Value != DBNull.Value
                                  ? Convert.ToDecimal(cmd.Parameters["@MontoNC"].Value) : 0;
                    return (ok, msg, monto);
                }
                catch (Exception ex)
                {
                    return (false, "Error al generar nota de crédito: " + ex.Message, 0);
                }
            }
        }

        /// <summary>
        /// Obtiene las líneas de una compra para mostrar en el form de recepción.
        /// </summary>
        public List<DetalleCompra> ObtenerLineasParaRecepcion(int idCompra)
        {
            var lista = new List<DetalleCompra>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
                    SELECT dc.IdDetalleCompra, dc.IdCompra, dc.IdProducto,
                           dc.Cantidad, dc.CantidadFacturada, dc.CantidadRecibida,
                           dc.PrecioUnitarioCompra, dc.TotalCosto, dc.EstadoLinea,
                           p.Codigo, p.Nombre, p.Descripcion
                      FROM dbo.DETALLE_COMPRA dc
                      INNER JOIN dbo.PRODUCTO p ON p.IdProducto = dc.IdProducto
                     WHERE dc.IdCompra = @IdCompra
                       AND dc.Activo = 1", cn);
                cmd.Parameters.AddWithValue("@IdCompra", idCompra);
                cmd.CommandType = CommandType.Text;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new DetalleCompra
                            {
                                IdDetalleCompra = Convert.ToInt32(dr["IdDetalleCompra"]),
                                IdCompra        = Convert.ToInt32(dr["IdCompra"]),
                                Cantidad        = Convert.ToInt32(dr["Cantidad"]),
                                CantidadFacturada = dr["CantidadFacturada"] != DBNull.Value
                                                    ? Convert.ToInt32(dr["CantidadFacturada"]) : 0,
                                CantidadRecibida  = dr["CantidadRecibida"] != DBNull.Value
                                                    ? Convert.ToInt32(dr["CantidadRecibida"]) : 0,
                                EstadoLinea     = dr["EstadoLinea"]?.ToString(),
                                PrecioUnitarioCompra = Convert.ToDecimal(dr["PrecioUnitarioCompra"]),
                                TotalCosto      = Convert.ToDecimal(dr["TotalCosto"]),
                                oProducto = new Producto
                                {
                                    IdProducto  = Convert.ToInt32(dr["IdProducto"]),
                                    Codigo      = dr["Codigo"]?.ToString(),
                                    Nombre      = dr["Nombre"]?.ToString(),
                                    Descripcion = dr["Descripcion"]?.ToString()
                                }
                            });
                        }
                    }
                }
                catch (Exception) { }
            }
            return lista;
        }
    }

    /// <summary>
    /// DTO simple para enviar líneas al método RegistrarRecepcion.
    /// </summary>
    public class DetalleRecepcion
    {
        public int IdDetalleCompra { get; set; }
        public int CantidadRecibida { get; set; }
    }

    // ================================================================
    //  NUEVO: RegistrarRecepcionDesdeOC
    // ================================================================
    public partial class CD_Compra
    {
        /// <summary>
        /// Crea el registro COMPRA + DETALLE_COMPRA directamente desde una OC aprobada,
        /// con las cantidades realmente recibidas. Llama a usp_RegistrarRecepcionDesdeOC.
        /// </summary>
        public (bool resultado, string mensaje, int idCompra) RegistrarRecepcionDesdeOC(
            int idOrdenCompra, int idUsuario,
            string numeroFactura, string numeroTimbrado,
            DateTime fechaVencTimbrado, DateTime fechaFactura, DateTime fechaEntrega,
            List<CapaModelo.LineaRecepcionOC> lineas)
        {
            var xml = new System.Text.StringBuilder();
            xml.Append("<DETALLE>");
            foreach (var l in lineas)
            {
                xml.Append("<ITEM>");
                xml.Append("<IdDetalleOC>").Append(l.IdDetalleOC).Append("</IdDetalleOC>");
                xml.Append("<CantidadRecibida>").Append(l.CantidadRecibida).Append("</CantidadRecibida>");
                xml.Append("</ITEM>");
            }
            xml.Append("</DETALLE>");

            using (var cn = new System.Data.SqlClient.SqlConnection(Conexion.CN))
            {
                try
                {
                    var cmd = new System.Data.SqlClient.SqlCommand("usp_RegistrarRecepcionDesdeOC", cn);
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdOrdenCompra",     idOrdenCompra);
                    cmd.Parameters.AddWithValue("@IdUsuario",         idUsuario);
                    cmd.Parameters.AddWithValue("@NumeroFactura",     numeroFactura);
                    cmd.Parameters.AddWithValue("@NumeroTimbrado",    numeroTimbrado);
                    cmd.Parameters.Add("@FechaVencTimbrado", System.Data.SqlDbType.Date).Value     = fechaVencTimbrado.Date;
                    cmd.Parameters.Add("@FechaFactura",      System.Data.SqlDbType.Date).Value     = fechaFactura.Date;
                    cmd.Parameters.Add("@FechaEntrega",      System.Data.SqlDbType.DateTime).Value = fechaEntrega;
                    cmd.Parameters.Add("@Detalle",           System.Data.SqlDbType.Xml).Value      = xml.ToString();

                    var pId  = new System.Data.SqlClient.SqlParameter("@IdCompra",  System.Data.SqlDbType.Int)           { Direction = System.Data.ParameterDirection.Output };
                    var pRes = new System.Data.SqlClient.SqlParameter("@Resultado", System.Data.SqlDbType.Bit)           { Direction = System.Data.ParameterDirection.Output };
                    var pMsg = new System.Data.SqlClient.SqlParameter("@Mensaje",   System.Data.SqlDbType.NVarChar, 400) { Direction = System.Data.ParameterDirection.Output };
                    cmd.Parameters.Add(pId);
                    cmd.Parameters.Add(pRes);
                    cmd.Parameters.Add(pMsg);

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok    = Convert.ToBoolean(pRes.Value);
                    string msg = pMsg.Value?.ToString() ?? "";
                    int id     = ok && pId.Value != DBNull.Value ? Convert.ToInt32(pId.Value) : 0;
                    return (ok, msg, id);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message, 0);
                }
            }
        }
    }

    // ================================================================
    //  ANULAR COMPRA  (segregación O&M — el revisor anula si no llegó)
    // ================================================================
    public partial class CD_Compra
    {
        /// <summary>
        /// Anula una compra Pendiente. Solo el revisor (diferente al que registró)
        /// puede ejecutar esta acción. Registra en HISTORIAL_ESTADO_COMPRA.
        /// </summary>
        public (bool resultado, string mensaje) AnularCompra(
            int idCompra, int idUsuario, string motivo = "")
        {
            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AnularCompra", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra",  idCompra);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    cmd.Parameters.AddWithValue("@Motivo",
                        string.IsNullOrWhiteSpace(motivo) ? (object)DBNull.Value : motivo);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok    = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al anular compra: " + ex.Message);
                }
            }
        }

        /// <summary>
        /// Obtiene la lista de compras para la pantalla de Revisión,
        /// filtrando por fechas, proveedor, tienda y estado.
        /// Llama a usp_ObtenerListaCompraRevision.
        /// </summary>
        public List<CapaModelo.Compra> ObtenerListaRevision(
            DateTime fechaInicio, DateTime fechaFin,
            int idProveedor, int idTienda, string estado = "Pendiente")
        {
            var lista = new List<CapaModelo.Compra>();

            using (var cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaCompraRevision", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = fechaInicio.Date;
                cmd.Parameters.Add("@FechaFin",    SqlDbType.Date).Value = fechaFin.Date;
                cmd.Parameters.AddWithValue("@IdProveedor", idProveedor);
                cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                cmd.Parameters.AddWithValue("@Estado",      string.IsNullOrWhiteSpace(estado) ? "Todos" : estado);

                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new CapaModelo.Compra
                            {
                                IdCompra        = Convert.ToInt32(dr["IdCompra"]),
                                NumeroCompra    = dr["NumeroCompra"].ToString(),
                                NumeroFactura   = dr["NumeroFactura"]?.ToString(),
                                NumeroTimbrado  = dr["NumeroTimbrado"]?.ToString(),
                                oProveedor = new CapaModelo.Proveedor
                                {
                                    IdProveedor = Convert.ToInt32(dr["IdProveedor"]),
                                    RazonSocial = dr["RazonSocial"].ToString()
                                },
                                oTienda = new CapaModelo.Tienda
                                {
                                    IdTienda = Convert.ToInt32(dr["IdTienda"]),
                                    Nombre   = dr["NombreTienda"].ToString()
                                },
                                FechaCompra      = dr["FechaRegistro"].ToString(),
                                FechaFactura     = dr["FechaFactura"].ToString(),
                                FechaEntrega     = dr["FechaEntrega"].ToString(),
                                TotalCosto       = Convert.ToDecimal(dr["TotalCosto"]),
                                Estado           = dr["Estado"].ToString(),
                                EstadoRecepcion  = dr["EstadoRecepcion"].ToString(),
                                UsuarioRegistro  = dr["UsuarioRegistro"].ToString(),
                                NumeroOrden      = dr["NumeroOrden"]?.ToString(),
                                MontoNotaCredito = LeerDecimal(dr, "MontoNotaCredito"),
                                NecesitaNC       = LeerBool(dr, "NecesitaNC"),
                                IdOrdenPago      = LeerInt(dr, "IdOrdenPago")
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<CapaModelo.Compra>();
                }
            }

            return lista;
        }

        // ── Helpers defensivos: leen columnas opcionales sin explotar ─────────
        private static decimal LeerDecimal(SqlDataReader dr, string columna)
        {
            try { return dr[columna] != DBNull.Value ? Convert.ToDecimal(dr[columna]) : 0; }
            catch { return 0; }
        }

        private static bool LeerBool(SqlDataReader dr, string columna)
        {
            try { return dr[columna] != DBNull.Value && Convert.ToBoolean(dr[columna]); }
            catch { return false; }
        }

        private static int LeerInt(SqlDataReader dr, string columna)
        {
            try { return dr[columna] != DBNull.Value ? Convert.ToInt32(dr[columna]) : 0; }
            catch { return 0; }
        }
    }
}
