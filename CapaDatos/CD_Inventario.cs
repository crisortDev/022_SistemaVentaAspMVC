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

        /// <summary>
        /// Registra un traslado en estado Pendiente (NO mueve stock hasta que se apruebe).
        /// Reemplaza al antiguo RegistrarTraslado que movía stock directo.
        /// </summary>
        public (bool resultado, string mensaje, int idTraslado) RegistrarTrasladoPendiente(
            int idProducto, int idTiendaOrigen, int idTiendaDestino,
            int cantidad, string observaciones, int idUsuario)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_RegistrarTrasladoPendiente", oConexion)
            { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdProducto",      idProducto);
                cmd.Parameters.AddWithValue("@IdTiendaOrigen",  idTiendaOrigen);
                cmd.Parameters.AddWithValue("@IdTiendaDestino", idTiendaDestino);
                cmd.Parameters.AddWithValue("@Cantidad",        cantidad);
                cmd.Parameters.AddWithValue("@Observaciones",   observaciones ?? "");
                cmd.Parameters.AddWithValue("@IdUsuario",       idUsuario);
                var pR = cmd.Parameters.Add("@Resultado",   SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",     SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                var pI = cmd.Parameters.Add("@IdTraslado",  SqlDbType.Int);           pI.Direction = ParameterDirection.Output;
                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    return ((bool)pR.Value, pM.Value?.ToString(), pI.Value == DBNull.Value ? 0 : (int)pI.Value);
                }
                catch (Exception ex) { return (false, "Error: " + ex.Message, 0); }
            }
        }

        /// <summary>
        /// Aprueba un traslado pendiente y mueve el stock de origen a destino.
        /// </summary>
        public (bool resultado, string mensaje) AprobarTraslado(int idTraslado, int idUsuarioAprueba, bool esSuperAdmin)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_AprobarTraslado", oConexion)
            { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTraslado",       idTraslado);
                cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                cmd.Parameters.AddWithValue("@EsSuperAdmin",     esSuperAdmin);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        /// <summary>
        /// Rechaza un traslado pendiente. No mueve stock.
        /// </summary>
        public (bool resultado, string mensaje) RechazarTraslado(int idTraslado, int idUsuarioAprueba, string motivoRechazo)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_RechazarTraslado", oConexion)
            { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTraslado",       idTraslado);
                cmd.Parameters.AddWithValue("@IdUsuarioAprueba", idUsuarioAprueba);
                cmd.Parameters.AddWithValue("@MotivoRechazo",    motivoRechazo ?? "");
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        /// <summary>
        /// Retorna el IdTiendaDestino de un traslado. 0 si no existe.
        /// </summary>
        public int ObtenerTiendaDestinoDeTraslado(int idTraslado)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("SELECT IdTiendaDestino FROM dbo.TRASLADO WHERE IdTraslado = @Id", oConexion))
            {
                cmd.Parameters.AddWithValue("@Id", idTraslado);
                try
                {
                    oConexion.Open();
                    var val = cmd.ExecuteScalar();
                    return val != null && val != DBNull.Value ? Convert.ToInt32(val) : 0;
                }
                catch { return 0; }
            }
        }

        /// <summary>
        /// Retorna el IdTiendaOrigen de un traslado. 0 si no existe.
        /// Se usa para validar que el aprobador pertenece a la sucursal origen.
        /// </summary>
        public int ObtenerTiendaOrigenDeTraslado(int idTraslado)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("SELECT IdTiendaOrigen FROM dbo.TRASLADO WHERE IdTraslado = @Id", oConexion))
            {
                cmd.Parameters.AddWithValue("@Id", idTraslado);
                try
                {
                    oConexion.Open();
                    var val = cmd.ExecuteScalar();
                    return val != null && val != DBNull.Value ? Convert.ToInt32(val) : 0;
                }
                catch { return 0; }
            }
        }

        public List<Traslado> ObtenerHistorialTraslados(DateTime fechaInicio, DateTime fechaFin, int idTienda, string estadoAprobacion = "")
        {
            List<Traslado> lista = new List<Traslado>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerTrasladosHistorial", oConexion)
                { CommandType = CommandType.StoredProcedure };

                cmd.Parameters.AddWithValue("@FechaInicio",       fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FechaFin",          fechaFin.Date);
                cmd.Parameters.AddWithValue("@IdTienda",          idTienda);
                cmd.Parameters.AddWithValue("@EstadoAprobacion",  estadoAprobacion ?? "");

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new Traslado
                        {
                            IdTraslado       = Convert.ToInt32(dr["IdTraslado"]),
                            Numero           = dr["Numero"]?.ToString(),
                            NombreProducto   = dr["NombreProducto"].ToString(),
                            CodigoProducto   = dr["CodigoProducto"].ToString(),
                            TiendaOrigen     = dr["TiendaOrigen"].ToString(),
                            TiendaDestino    = dr["TiendaDestino"].ToString(),
                            Cantidad         = Convert.ToInt32(dr["Cantidad"]),
                            Observaciones    = dr["Observaciones"].ToString(),
                            Usuario          = dr["Usuario"].ToString(),
                            FechaTraslado    = dr["FechaTraslado"].ToString(),
                            EstadoAprobacion = dr["EstadoAprobacion"]?.ToString(),
                            UsuarioAprueba   = dr["UsuarioAprueba"]?.ToString(),
                            FechaAprobacion  = dr["FechaAprobacion"]?.ToString(),
                            MotivoRechazo    = dr["MotivoRechazo"]?.ToString(),
                            IdTiendaDestino  = dr["IdTiendaDestino"] == DBNull.Value ? 0 : Convert.ToInt32(dr["IdTiendaDestino"])
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

        /// <summary>
        /// OBSOLETO: descuenta el stock directamente sin pasar por aprobación.
        /// Usar RegistrarBajaPendiente en su lugar.
        /// </summary>
        [Obsolete("Usar RegistrarBajaPendiente. Este método saltea el flujo de aprobación.")]
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
                                    Numero           = dr["Numero"]?.ToString(),
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

        // ─── NUEVO FLUJO SUPERVISOR / OPERADOR ───────────────────────────────────

        public (bool resultado, string mensaje, int idInventario) CrearInventario(
            int idTienda, int idSupervisor, string observacion)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_CrearInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@IdSupervisor", idSupervisor);
                cmd.Parameters.AddWithValue("@Observacion", observacion ?? "");
                var pR = cmd.Parameters.Add("@Resultado",    SqlDbType.Bit);       pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",      SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                var pI = cmd.Parameters.Add("@IdInventario", SqlDbType.Int);       pI.Direction = ParameterDirection.Output;
                try
                {
                    oConexion.Open(); cmd.ExecuteNonQuery();
                    return ((bool)pR.Value, pM.Value?.ToString(), pI.Value == DBNull.Value ? 0 : (int)pI.Value);
                }
                catch (Exception ex) { return (false, "Error: " + ex.Message, 0); }
            }
        }

        public (bool resultado, string mensaje) AsignarOperadorInventario(int idInventario, int idOperador)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_AsignarOperadorInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                cmd.Parameters.AddWithValue("@IdOperador",   idOperador);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        public (bool resultado, string mensaje) IniciarConteoInventario(int idInventario, int idOperador)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_IniciarConteoInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                cmd.Parameters.AddWithValue("@IdOperador",   idOperador);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        public (bool resultado, string mensaje) FinalizarConteoInventario(
            int idInventario, int idOperador, string detalleXml, string observacion)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_FinalizarConteoInventario", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                cmd.Parameters.AddWithValue("@IdOperador",   idOperador);
                cmd.Parameters.Add("@DetalleXml", SqlDbType.Xml).Value = detalleXml ?? "<Detalle/>";
                cmd.Parameters.AddWithValue("@Observacion",  observacion ?? "");
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { oConexion.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        public List<dynamic> ObtenerInventariosSupervisor(int idTienda, string estado)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerInventariosSupervisor", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@Estado",   estado ?? "");
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                        while (dr.Read())
                            lista.Add(new {
                                IdInventario       = Convert.ToInt32(dr["IdInventario"]),
                                IdTienda           = Convert.ToInt32(dr["IdTienda"]),
                                Numero             = dr["Numero"]?.ToString(),
                                NombreTienda       = dr["NombreTienda"]?.ToString(),
                                Estado             = dr["Estado"]?.ToString(),
                                Observacion        = dr["Observacion"]?.ToString(),
                                MotivoRechazo      = dr["MotivoRechazo"]?.ToString(),
                                FechaRegistro      = dr["FechaRegistro"]?.ToString(),
                                FechaInicio        = dr["FechaInicio"]?.ToString(),
                                FechaFinalizacion  = dr["FechaFinalizacion"]?.ToString(),
                                Supervisor         = dr["Supervisor"]?.ToString(),
                                Aprobador          = dr["Aprobador"]?.ToString(),
                                Operadores         = dr["Operadores"]?.ToString(),
                                FechaAprobacion    = dr["FechaAprobacion"]?.ToString(),
                                CantItems          = Convert.ToInt32(dr["CantItems"]),
                                CantDiferencias    = Convert.ToInt32(dr["CantDiferencias"])
                            });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerInventariosSupervisor ERROR: " + ex.Message); }
            }
            return lista;
        }

        public List<dynamic> ObtenerInventariosOperador(int idOperador)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerInventariosOperador", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdOperador", idOperador);
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                        while (dr.Read())
                            lista.Add(new {
                                IdInventario   = Convert.ToInt32(dr["IdInventario"]),
                                Numero         = dr["Numero"]?.ToString(),
                                NombreTienda   = dr["NombreTienda"]?.ToString(),
                                IdTienda       = Convert.ToInt32(dr["IdTienda"]),
                                Estado         = dr["Estado"]?.ToString(),
                                MotivoRechazo  = dr["MotivoRechazo"]?.ToString(),
                                FechaRegistro  = dr["FechaRegistro"]?.ToString(),
                                FechaInicio    = dr["FechaInicio"]?.ToString()
                            });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerInventariosOperador ERROR: " + ex.Message); }
            }
            return lista;
        }

        public List<dynamic> ObtenerProductosParaConteo(int idTienda)
        {
            var lista = new List<dynamic>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerProductosParaConteo", oConexion) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                        while (dr.Read())
                            lista.Add(new {
                                IdProducto = Convert.ToInt32(dr["IdProducto"]),
                                Codigo     = dr["Codigo"]?.ToString(),
                                Nombre     = dr["Nombre"]?.ToString(),
                                Categoria  = dr["Categoria"]?.ToString()
                            });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("ObtenerProductosParaConteo ERROR: " + ex.Message); }
            }
            return lista;
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
                                Categoria      = dr["Categoria"]?.ToString(),
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
        /// Retorna el IdTienda al que pertenece una baja (HISTORIAL_MOVIMIENTO). 0 si no existe.
        /// Se usa para validar que el aprobador pertenece a la misma sucursal que la baja.
        /// </summary>
        public int ObtenerTiendaDeBaja(int idHistorial)
        {
            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("SELECT IdTienda FROM dbo.HISTORIAL_MOVIMIENTO WHERE IdHistorial = @Id", oConexion))
            {
                cmd.Parameters.AddWithValue("@Id", idHistorial);
                try
                {
                    oConexion.Open();
                    var val = cmd.ExecuteScalar();
                    return val != null && val != DBNull.Value ? Convert.ToInt32(val) : 0;
                }
                catch { return 0; }
            }
        }

        /// <summary>
        /// Retorna el IdTienda al que pertenece un inventario. 0 si no existe.
        /// Se usa para validar que el aprobador pertenece a la misma sucursal.
        /// </summary>
        /// <summary>
        /// Anula un inventario que aún no fue aprobado.
        /// </summary>
        public (bool resultado, string mensaje) AnularInventario(int idInventario, int idUsuarioAnula)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_AnularInventario", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario",   idInventario);
                cmd.Parameters.AddWithValue("@IdUsuarioAnula", idUsuarioAnula);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);          pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try { cn.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

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
                            Categoria = dr["Categoria"].ToString(),
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