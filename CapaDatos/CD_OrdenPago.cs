using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    /// <summary>
    /// Capa de datos para Orden de Pago.
    /// </summary>
    public class CD_OrdenPago
    {
        private static CD_OrdenPago _instancia = null;
        private CD_OrdenPago() { }
        public static CD_OrdenPago Instancia
        {
            get { if (_instancia == null) _instancia = new CD_OrdenPago(); return _instancia; }
        }

        /// <summary>
        /// Genera la OP a partir de una compra confirmada.
        /// </summary>
        public (bool resultado, string mensaje, int idGenerado) Generar(int idCompra, int idUsuarioEmite)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_GenerarOrdenPago", cn);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdCompra", idCompra);
                    cmd.Parameters.AddWithValue("@IdUsuarioEmite", idUsuarioEmite);
                    cmd.Parameters.Add("@IdOPGenerada", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int idOP = cmd.Parameters["@IdOPGenerada"].Value != DBNull.Value
                                ? Convert.ToInt32(cmd.Parameters["@IdOPGenerada"].Value)
                                : 0;
                    return (ok, msg, idOP);
                }
                catch (Exception ex)
                {
                    return (false, "Error al generar OP: " + ex.Message, 0);
                }
            }
        }

        /// <summary>
        /// Obtiene una OP por id (para vista de impresión / consulta).
        /// </summary>
        public OrdenPago Obtener(int idOrdenPago)
        {
            OrdenPago op = null;
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
                    SELECT op.IdOrdenPago, op.NumeroOP, op.IdCompra, op.Monto, op.Estado,
                           op.FechaEmision, op.IdUsuarioEmite, op.Activo,
                           c.NumeroFactura, c.TotalCosto, c.MontoNotaCredito,
                           p.IdProveedor, p.RUC, p.RazonSocial,
                           t.IdTienda, t.Nombre AS NombreTienda, t.RUC AS RucTienda,
                           u.Nombres, u.Apellidos
                      FROM dbo.ORDEN_PAGO op
                      INNER JOIN dbo.COMPRA    c ON c.IdCompra    = op.IdCompra
                      INNER JOIN dbo.PROVEEDOR p ON p.IdProveedor = op.IdProveedor
                      INNER JOIN dbo.TIENDA    t ON t.IdTienda    = op.IdTienda
                      INNER JOIN dbo.USUARIO   u ON u.IdUsuario   = op.IdUsuarioEmite
                     WHERE op.IdOrdenPago = @IdOrdenPago", cn);
                cmd.Parameters.AddWithValue("@IdOrdenPago", idOrdenPago);
                cmd.CommandType = CommandType.Text;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            op = new OrdenPago
                            {
                                IdOrdenPago        = Convert.ToInt32(dr["IdOrdenPago"]),
                                NumeroOP           = dr["NumeroOP"].ToString(),
                                IdCompra           = Convert.ToInt32(dr["IdCompra"]),
                                Monto              = Convert.ToDecimal(dr["Monto"]),
                                Estado             = dr["Estado"].ToString(),
                                FechaEmision       = Convert.ToDateTime(dr["FechaEmision"]),
                                FechaEmisionTexto  = Convert.ToDateTime(dr["FechaEmision"]).ToString("dd/MM/yyyy HH:mm"),
                                Activo             = Convert.ToBoolean(dr["Activo"]),
                                oCompra = new Compra
                                {
                                    IdCompra        = Convert.ToInt32(dr["IdCompra"]),
                                    NumeroFactura   = dr["NumeroFactura"].ToString(),
                                    TotalCosto      = Convert.ToDecimal(dr["TotalCosto"]),
                                    MontoNotaCredito = dr["MontoNotaCredito"] != DBNull.Value
                                                        ? Convert.ToDecimal(dr["MontoNotaCredito"]) : (decimal?)null
                                },
                                oProveedor = new Proveedor
                                {
                                    IdProveedor = Convert.ToInt32(dr["IdProveedor"]),
                                    Ruc         = dr["RUC"].ToString(),
                                    RazonSocial = dr["RazonSocial"].ToString()
                                },
                                oTienda = new Tienda
                                {
                                    IdTienda = Convert.ToInt32(dr["IdTienda"]),
                                    RUC      = dr["RucTienda"].ToString(),
                                    Nombre   = dr["NombreTienda"].ToString()
                                },
                                oUsuarioEmite = new Usuario
                                {
                                    Nombres   = dr["Nombres"].ToString(),
                                    Apellidos = dr["Apellidos"].ToString()
                                }
                            };
                        }
                    }
                }
                catch (Exception) { op = null; }
            }
            return op;
        }

        /// <summary>
        /// Listado de OPs por filtros básicos.
        /// </summary>
        public List<OrdenPago> ObtenerLista(int idTienda, DateTime fechaInicio, DateTime fechaFin, string estado)
        {
            var lista = new List<OrdenPago>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
                    SELECT op.IdOrdenPago, op.NumeroOP, op.IdCompra, op.Monto, op.Estado,
                           op.FechaEmision, op.Activo,
                           p.RazonSocial AS RazonSocialProveedor,
                           t.Nombre AS NombreTienda
                      FROM dbo.ORDEN_PAGO op
                      INNER JOIN dbo.PROVEEDOR p ON p.IdProveedor = op.IdProveedor
                      INNER JOIN dbo.TIENDA    t ON t.IdTienda    = op.IdTienda
                     WHERE (@IdTienda = 0 OR op.IdTienda = @IdTienda)
                       AND CAST(op.FechaEmision AS DATE) BETWEEN @FInicio AND @FFin
                       AND (@Estado IS NULL OR @Estado = '' OR op.Estado = @Estado)
                     ORDER BY op.FechaEmision DESC", cn);
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@FInicio", fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FFin",    fechaFin.Date);
                cmd.Parameters.AddWithValue("@Estado",  (object)estado ?? DBNull.Value);
                cmd.CommandType = CommandType.Text;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new OrdenPago
                            {
                                IdOrdenPago       = Convert.ToInt32(dr["IdOrdenPago"]),
                                NumeroOP          = dr["NumeroOP"].ToString(),
                                IdCompra          = Convert.ToInt32(dr["IdCompra"]),
                                Monto             = Convert.ToDecimal(dr["Monto"]),
                                Estado            = dr["Estado"].ToString(),
                                FechaEmision      = Convert.ToDateTime(dr["FechaEmision"]),
                                FechaEmisionTexto = Convert.ToDateTime(dr["FechaEmision"]).ToString("dd/MM/yyyy HH:mm"),
                                Activo            = Convert.ToBoolean(dr["Activo"]),
                                oProveedor = new Proveedor { RazonSocial = dr["RazonSocialProveedor"].ToString() },
                                oTienda    = new Tienda    { Nombre      = dr["NombreTienda"].ToString() }
                            });
                        }
                    }
                }
                catch (Exception) { }
            }
            return lista;
        }
    }
}
