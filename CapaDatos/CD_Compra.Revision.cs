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
        /// Confirma la compra: cambia EstadoRecepcion a Confirmada y mueve el stock.
        /// </summary>
        public (bool resultado, string mensaje) ConfirmarCompra(int idCompra)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ConfirmarCompraEImpactarStock", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra", idCompra);
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
}
