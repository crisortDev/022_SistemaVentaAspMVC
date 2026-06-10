using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_Inventario
    {
        private static CD_Inventario _instancia = null;
        private CD_Inventario() { }
        public static CD_Inventario Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Inventario();
                return _instancia;
            }
        }

        // =============================================
        // TRASLADO
        // =============================================
        public (bool resultado, string mensaje) RegistrarTraslado(
            int idProducto, int idTiendaOrigen, int idTiendaDestino,
            int cantidad, string observaciones, int idUsuario)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarTraslado", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("@IdProducto", idProducto);
                    cmd.Parameters.AddWithValue("@IdTiendaOrigen", idTiendaOrigen);
                    cmd.Parameters.AddWithValue("@IdTiendaDestino", idTiendaDestino);
                    cmd.Parameters.AddWithValue("@Cantidad", cantidad);
                    cmd.Parameters.AddWithValue("@Observaciones", observaciones ?? "");
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);

                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.VarChar, 255).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool resultado = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string mensaje = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";

                    return (resultado, mensaje);
                }
                catch (Exception ex)
                {
                    return (false, "Error: " + ex.Message);
                }
            }
        }

        public List<Traslado> ObtenerHistorialTraslados(DateTime fechaInicio, DateTime fechaFin, int idTienda)
        {
            List<Traslado> lista = new List<Traslado>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerTrasladosHistorial", oConexion)
                { CommandType = CommandType.StoredProcedure };

                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin.Date);
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new Traslado
                        {
                            IdTraslado = Convert.ToInt32(dr["IdTraslado"]),
                            NombreProducto = dr["NombreProducto"].ToString(),
                            CodigoProducto = dr["CodigoProducto"].ToString(),
                            TiendaOrigen = dr["TiendaOrigen"].ToString(),
                            TiendaDestino = dr["TiendaDestino"].ToString(),
                            Cantidad = Convert.ToInt32(dr["Cantidad"]),
                            Observaciones = dr["Observaciones"].ToString(),
                            Usuario = dr["Usuario"].ToString(),
                            FechaTraslado = dr["FechaTraslado"].ToString()
                        });
                    }
                    dr.Close();
                }
                catch { lista = new List<Traslado>(); }
            }
            return lista;
        }

        // =============================================
        // BAJA DE PRODUCTOS
        // =============================================
        public string BajarStock(int idProductoTienda, int cantidad, string motivo, int idProducto, int idMotivoBaja = 0)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_BajaStockProductoTienda", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("@IdProductoTienda", idProductoTienda);
                    cmd.Parameters.AddWithValue("@Cantidad", cantidad);
                    cmd.Parameters.AddWithValue("@Motivo", motivo ?? "");
                    cmd.Parameters.AddWithValue("@IdProducto", idProducto);
                    cmd.Parameters.AddWithValue("@IdMotivoBaja", idMotivoBaja > 0 ? (object)idMotivoBaja : DBNull.Value);

                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    string resultado = "";
                    if (dr.Read())
                        resultado = dr["Resultado"].ToString();
                    dr.Close();
                    return resultado;
                }
                catch (Exception ex)
                {
                    return "Error: " + ex.Message;
                }
            }
        }

        // ── Registrar baja PENDIENTE (no descuenta hasta aprobar) ──────────
        public (bool resultado, string mensaje) RegistrarBajaPendiente(
            int idProductoTienda, int idProducto, int cantidad,
            int idMotivoBaja, string observaciones, int idUsuarioRegistro)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                using (var cmd = new SqlCommand("usp_RegistrarBajaPendiente", oConexion)
                { CommandType = CommandType.StoredProcedure })
                {
                    cmd.Parameters.AddWithValue("@IdProductoTienda",  idProductoTienda);
                    cmd.Parameters.AddWithValue("@IdProducto",        idProducto);
                    cmd.Parameters.AddWithValue("@Cantidad",          cantidad);
                    cmd.Parameters.AddWithValue("@IdMotivoBaja",      idMotivoBaja > 0 ? (object)idMotivoBaja : DBNull.Value);
                    cmd.Parameters.AddWithValue("@Observaciones",     observaciones ?? "");
                    cmd.Parameters.AddWithValue("@IdUsuarioRegistro", idUsuarioRegistro);
                    var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                    var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                    try { oConexion.Open(); cmd.ExecuteNonQuery();
                          return ((bool)pR.Value, pM.Value?.ToString()); }
                    catch (Exception ex) { return (false, "Error: " + ex.Message); }
                }
            }
        }

        // ── Aprobar baja (descuenta stock) ─────────────────────────────────
        public (bool resultado, string mensaje) AprobarBaja(int idHistorial, int idUsuarioAprueba, bool esSuperAdmin)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                using (var cmd = new SqlCommand("usp_AprobarBaja", oConexion)
                { CommandType = CommandType.StoredProcedure })
                {
                    cmd.Parameters.AddWithValue("@IdHistorial",      idHistorial);
                    cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                    cmd.Parameters.AddWithValue("@EsSuperAdmin",     esSuperAdmin);
                    var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                    var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                    try { oConexion.Open(); cmd.ExecuteNonQuery();
                          return ((bool)pR.Value, pM.Value?.ToString()); }
                    catch (Exception ex) { return (false, "Error: " + ex.Message); }
                }
            }
        }

        // ── Rechazar baja (no toca stock) ──────────────────────────────────
        public (bool resultado, string mensaje) RechazarBaja(int idHistorial, int idUsuarioAprueba, string motivoRechazo)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                using (var cmd = new SqlCommand("usp_RechazarBaja", oConexion)
                { CommandType = CommandType.StoredProcedure })
                {
                    cmd.Parameters.AddWithValue("@IdHistorial",      idHistorial);
                    cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                    cmd.Parameters.AddWithValue("@MotivoRechazo",    motivoRechazo ?? "");
                    var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                    var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                    try { oConexion.Open(); cmd.ExecuteNonQuery();
                          return ((bool)pR.Value, pM.Value?.ToString()); }
                    catch (Exception ex) { return (false, "Error: " + ex.Message); }
                }
            }
        }

        // ── Listar bajas (con filtro por estado de aprobación) ─────────────
        public List<dynamic> ObtenerBajas(int idTienda, string estadoAprobacion)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                using (var cmd = new SqlCommand("usp_ObtenerBajas", oConexion)
                { CommandType = CommandType.StoredProcedure })
                {
                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                    cmd.Parameters.AddWithValue("@EstadoAprobacion", estadoAprobacion ?? "");
                    try
                    {
                        oConexion.Open();
                        using (var dr = cmd.ExecuteReader())
                            while (dr.Read())
                                lista.Add(new {
                                    IdHistorial      = Convert.ToInt32(dr["IdHistorial"]),
                                    IdProducto       = dr["IdProducto"] == DBNull.Value ? 0 : Convert.ToInt32(dr["IdProducto"]),
                                    CodigoProducto   = dr["CodigoProducto"]?.ToString(),
                                    NombreProducto   = dr["NombreProducto"]?.ToString(),
                                    Cantidad         = Convert.ToInt32(dr["Cantidad"]),
                                    MotivoBaja       = dr["MotivoBaja"]?.ToString(),
                                    Observaciones    = dr["Observaciones"]?.ToString(),
                                    EstadoAprobacion = dr["EstadoAprobacion"]?.ToString(),
                                    NombreTienda     = dr["NombreTienda"]?.ToString(),
                                    FechaMovimiento  = dr["FechaMovimiento"]?.ToString(),
                                    UsuarioRegistro  = dr["UsuarioRegistro"]?.ToString(),
                                    UsuarioAprueba   = dr["UsuarioAprueba"]?.ToString(),
                                    FechaAprobacion  = dr["FechaAprobacion"]?.ToString(),
                                    MotivoRechazo    = dr["MotivoRechazo"]?.ToString()
                                });
                    }
                    catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerBajas ERROR: " + ex.Message); }
                }
            }
            return lista;
        }

        // ════════ TOMA DE INVENTARIO (conteo físico) ════════════════════════

        public (bool resultado, string mensaje, int idInventario) RegistrarInventario(
            int idTienda, int idUsuarioRegistro, string observacion, string detalleXml)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_RegistrarInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@IdUsuarioRegistro", idUsuarioRegistro);
                cmd.Parameters.AddWithValue("@Observacion", observacion ?? "");
                cmd.Parameters.AddWithValue("@DetalleXml", detalleXml ?? "");
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                var pI = cmd.Parameters.Add("@IdInventario", SqlDbType.Int); pI.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery();
                      return ((bool)pR.Value, pM.Value?.ToString(), pI.Value == DBNull.Value ? 0 : (int)pI.Value); }
                catch (Exception ex) { return (false, "Error: " + ex.Message, 0); }
            }
        }

        public (bool resultado, string mensaje) AprobarInventario(int idInventario, int idUsuarioAprueba, bool esSuperAdmin)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_AprobarInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                cmd.Parameters.AddWithValue("@EsSuperAdmin", esSuperAdmin);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery();
                      return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        public (bool resultado, string mensaje) RechazarInventario(int idInventario, int idUsuarioAprueba, string motivoRechazo)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_RechazarInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                cmd.Parameters.AddWithValue("@MotivoRechazo", motivoRechazo ?? "");
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit); pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery();
                      return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        public List<dynamic> ObtenerInventarios(int idTienda, string estado)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerInventarios", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@Estado", estado ?? "");
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                        while (dr.Read())
                            lista.Add(new {
                                IdInventario    = Convert.ToInt32(dr["IdInventario"]),
                                Numero          = dr["Numero"]?.ToString(),
                                NombreTienda    = dr["NombreTienda"]?.ToString(),
                                Estado          = dr["Estado"]?.ToString(),
                                Observacion     = dr["Observacion"]?.ToString(),
                                FechaRegistro   = dr["FechaRegistro"]?.ToString(),
                                UsuarioRegistro = dr["UsuarioRegistro"]?.ToString(),
                                UsuarioAprueba  = dr["UsuarioAprueba"]?.ToString(),
                                FechaAprobacion = dr["FechaAprobacion"]?.ToString(),
                                MotivoRechazo   = dr["MotivoRechazo"]?.ToString(),
                                CantItems       = Convert.ToInt32(dr["CantItems"]),
                                CantDiferencias = Convert.ToInt32(dr["CantDiferencias"])
                            });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerInventarios ERROR: " + ex.Message); }
            }
            return lista;
        }

        public List<dynamic> ObtenerDetalleInventario(int idInventario)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerDetalleInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                        while (dr.Read())
                            lista.Add(new {
                                CodigoProducto = dr["CodigoProducto"]?.ToString(),
                                NombreProducto = dr["NombreProducto"]?.ToString(),
                                StockSistema   = Convert.ToInt64(dr["StockSistema"]),
                                StockContado   = Convert.ToInt64(dr["StockContado"]),
                                Diferencia     = Convert.ToInt64(dr["Diferencia"])
                            });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerDetalleInventario ERROR: " + ex.Message); }
            }
            return lista;
        }

        /// <summary>
        /// Retorna el IdTienda al que pertenece un inventario. 0 si no existe.
        /// Se usa para validar que el aprobador pertenece a la misma sucursal.
        /// </summary>
        public int ObtenerTiendaDeInventario(int idInventario)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("SELECT IdTienda FROM dbo.INVENTARIO WHERE IdInventario = @Id", oConexion))
            {
                cmd.Parameters.AddWithValue("@Id", idInventario);
                try
                {
                    oConexion.Open();
                    var val = cmd.ExecuteScalar();
                    return val != null && val != DBNull.Value ? Convert.ToInt32(val) : 0;
                }
                catch { return 0; }
            }
        }

        public List<ProductoTiendaBaja> ObtenerProductosPorTiendaBaja(int idTienda)
        {
            List<ProductoTiendaBaja> lista = new List<ProductoTiendaBaja>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerProductosPorTiendaBaja", oConexion)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new ProductoTiendaBaja
                        {
                            IdProductoTienda = Convert.ToInt32(dr["IdProductoTienda"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            Codigo = dr["Codigo"].ToString(),
                            Nombre = dr["Nombre"].ToString(),
                            Stock = Convert.ToInt32(dr["Stock"])
                        });
                    }
                    dr.Close();
                }
                catch { lista = new List<ProductoTiendaBaja>(); }
            }
            return lista;
        }

        // =============================================
        // STOCK POR TIENDA
        // =============================================
        public List<StockTienda> ObtenerStockPorTienda(int idTienda, int idProducto)
        {
            List<StockTienda> lista = new List<StockTienda>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerStockPorTienda", oConexion)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@IdProducto", idProducto);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new StockTienda
                        {
                            IdProductoTienda = Convert.ToInt32(dr["IdProductoTienda"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            Codigo = dr["Codigo"].ToString(),
                            NombreProducto = dr["NombreProducto"].ToString(),
                            Categoria = dr["Categoria"].ToString(),
                            IdTienda = Convert.ToInt32(dr["IdTienda"]),
                            NombreTienda = dr["NombreTienda"].ToString(),
                            Stock = Convert.ToInt32(dr["Stock"]),
                            StockMinimo = Convert.ToInt32(dr["StockMinimo"]),
                            StockMaximo = Convert.ToInt32(dr["StockMaximo"]),
                            EstadoStock = dr["EstadoStock"].ToString()
                        });
                    }
                    dr.Close();
                }
                catch { lista = new List<StockTienda>(); }
            }
            return lista;
        }
    }
}