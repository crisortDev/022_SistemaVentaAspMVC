using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    /// <summary>
    /// Capa de datos para el módulo de Nota de Crédito (formato SET Paraguay).
    /// </summary>
    public class CD_NotaCredito
    {
        // ── Singleton ────────────────────────────────────────────────────
        private static CD_NotaCredito _instancia;
        private CD_NotaCredito() { }
        public static CD_NotaCredito Instancia
        {
            get { if (_instancia == null) _instancia = new CD_NotaCredito(); return _instancia; }
        }

        // ════════════════════════════════════════════════════════════════
        //  OBTENER LISTA
        // ════════════════════════════════════════════════════════════════

        /// <summary>
        /// Obtiene las Notas de Crédito filtradas por tienda y/o estado.
        /// Morosas se detectan en SQL (EsMorosa = 1 cuando Pendiente &gt; 30 días de la factura).
        /// </summary>
        public List<NotaCredito> ObtenerNotasCredito(int idTienda = 0, string estado = "")
        {
            var lista = new List<NotaCredito>();

            using (var cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerNotasCredito", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@Estado",   string.IsNullOrWhiteSpace(estado) ? "" : estado);

                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(MapearNC(dr));
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<NotaCredito>();
                }
            }

            return lista;
        }

        // ════════════════════════════════════════════════════════════════
        //  CONFIRMAR RECEPCIÓN (el proveedor trae el documento físico)
        // ════════════════════════════════════════════════════════════════

        public (bool resultado, string mensaje) ConfirmarRecepcion(
            int    idNC,
            string numeroNC,
            string numeroTimbrado,
            DateTime fechaVencTimbrado,
            DateTime fechaEmision,
            string observacion,
            int    idUsuario)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ConfirmarRecepcionNC", cn);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdNC",             idNC);
                    cmd.Parameters.AddWithValue("@NumeroNC",         (object)numeroNC?.Trim()         ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NumeroTimbrado",   (object)numeroTimbrado?.Trim()   ?? DBNull.Value);
                    cmd.Parameters.Add("@FechaVencTimbrado", SqlDbType.Date).Value = fechaVencTimbrado.Date;
                    cmd.Parameters.Add("@FechaEmision",      SqlDbType.Date).Value = fechaEmision.Date;
                    cmd.Parameters.AddWithValue("@Observacion", string.IsNullOrWhiteSpace(observacion)
                                                                    ? (object)DBNull.Value : observacion.Trim());
                    cmd.Parameters.AddWithValue("@IdUsuario",   idUsuario);

                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction         = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool   ok  = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al confirmar NC: " + ex.Message);
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        //  RECHAZAR NC
        // ════════════════════════════════════════════════════════════════

        public (bool resultado, string mensaje) Rechazar(int idNC, string observacion, int idUsuario)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RechazarNC", cn);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdNC",       idNC);
                    cmd.Parameters.AddWithValue("@Observacion", string.IsNullOrWhiteSpace(observacion)
                                                                    ? (object)DBNull.Value : observacion.Trim());
                    cmd.Parameters.AddWithValue("@IdUsuario",  idUsuario);

                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction         = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 400).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    bool   ok  = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al rechazar NC: " + ex.Message);
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        //  OBTENER NC INDIVIDUAL (para validaciones server-side)
        // ════════════════════════════════════════════════════════════════

        /// <summary>
        /// Obtiene una Nota de Crédito por su IdNC.
        /// Se usa en el controller para validar fecha de emisión vs. fecha de factura.
        /// </summary>
        public NotaCredito ObtenerPorId(int idNC)
        {
            try
            {
                using (var cn = new SqlConnection(Conexion.CN))
                {
                    cn.Open();
                    var cmd = new SqlCommand(
                        @"SELECT nc.IdNC, nc.IdCompra,
                                 c.NumeroFactura, c.FechaFactura,
                                 c.MontoTotal    AS MontoFactura,
                                 nc.NumeroNC, nc.NumeroTimbrado,
                                 nc.FechaVencTimbrado, nc.FechaEmision,
                                 nc.MontoNC, nc.Estado, nc.Observacion,
                                 nc.FechaRegistro, nc.FechaConfirmacion,
                                 DATEDIFF(DAY, c.FechaFactura, GETDATE()) AS DiasTranscurridos,
                                 CASE WHEN nc.Estado='Pendiente'
                                       AND DATEDIFF(DAY, c.FechaFactura, GETDATE()) > 30
                                      THEN 1 ELSE 0 END AS EsMorosa,
                                 ISNULL(u.Nombres + ' ' + u.Apellidos, '') AS UsuarioRegistro,
                                 mn.Descripcion  AS MotivoNC,
                                 p.RazonSocial   AS Proveedor,
                                 p.RUC           AS RucProveedor,
                                 t.Nombre        AS Tienda
                          FROM   dbo.NOTA_CREDITO nc
                          JOIN   dbo.COMPRA        c  ON c.IdCompra   = nc.IdCompra
                          JOIN   dbo.PROVEEDOR     p  ON p.IdProveedor = c.IdProveedor
                          JOIN   dbo.TIENDA        t  ON t.IdTienda   = c.IdTienda
                          LEFT JOIN dbo.USUARIO    u  ON u.IdUsuario  = nc.IdUsuarioRegistro
                          LEFT JOIN dbo.MOTIVO_NC  mn ON mn.IdMotivoNC = nc.IdMotivoNC
                          WHERE  nc.IdNC = @IdNC", cn);
                    cmd.Parameters.AddWithValue("@IdNC", idNC);

                    using (var dr = cmd.ExecuteReader())
                    {
                        if (dr.Read()) return MapearNC(dr);
                    }
                }
            }
            catch { /* log si se desea */ }
            return null;
        }

        // ════════════════════════════════════════════════════════════════
        //  HELPER PRIVADO — MAPEAR DATAREADER → MODELO
        // ════════════════════════════════════════════════════════════════

        private static NotaCredito MapearNC(SqlDataReader dr)
        {
            return new NotaCredito
            {
                IdNC              = LeerInt(dr,     "IdNC"),
                IdCompra          = LeerInt(dr,     "IdCompra"),
                NumeroFactura     = LeerStr(dr,     "NumeroFactura"),
                FechaFactura      = LeerStr(dr,     "FechaFactura"),
                MontoFactura      = LeerDecimal(dr, "MontoFactura"),
                NumeroNC          = LeerStr(dr,     "NumeroNC"),
                NumeroTimbrado    = LeerStr(dr,     "NumeroTimbrado"),
                FechaVencTimbrado = LeerStr(dr,     "FechaVencTimbrado"),
                FechaEmision      = LeerStr(dr,     "FechaEmision"),
                MontoNC           = LeerDecimal(dr, "MontoNC"),
                Estado            = LeerStr(dr,     "Estado"),
                Observacion       = LeerStr(dr,     "Observacion"),
                FechaRegistro     = LeerStr(dr,     "FechaRegistro"),
                FechaConfirmacion = LeerStr(dr,     "FechaConfirmacion"),
                DiasTranscurridos = LeerInt(dr,     "DiasTranscurridos"),
                EsMorosa          = LeerBool(dr,    "EsMorosa"),
                UsuarioRegistro   = LeerStr(dr,     "UsuarioRegistro"),
                MotivoNC          = LeerStr(dr,     "MotivoNC"),
                Proveedor         = LeerStr(dr,     "Proveedor"),
                RucProveedor      = LeerStr(dr,     "RucProveedor"),
                Tienda            = LeerStr(dr,     "Tienda")
            };
        }

        // ── Helpers defensivos ────────────────────────────────────────
        private static int     LeerInt(SqlDataReader dr, string c)
        {
            try { return dr[c] != DBNull.Value ? Convert.ToInt32(dr[c]) : 0; } catch { return 0; }
        }
        private static decimal LeerDecimal(SqlDataReader dr, string c)
        {
            try { return dr[c] != DBNull.Value ? Convert.ToDecimal(dr[c]) : 0m; } catch { return 0m; }
        }
        private static bool    LeerBool(SqlDataReader dr, string c)
        {
            try { return dr[c] != DBNull.Value && Convert.ToBoolean(dr[c]); } catch { return false; }
        }
        private static string  LeerStr(SqlDataReader dr, string c)
        {
            try { return dr[c] != DBNull.Value ? dr[c].ToString() : ""; } catch { return ""; }
        }
    }
}
