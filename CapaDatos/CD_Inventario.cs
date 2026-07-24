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
        // TRASLADO — Flujo 4 pasos (Script 230)
        // =============================================

        private Traslado MapTraslado(SqlDataReader dr)
        {
            return new Traslado
            {
                IdTraslado       = Convert.ToInt32(dr["IdTraslado"]),
                Numero           = dr["Numero"]?.ToString(),
                TiendaOrigen     = dr["TiendaOrigen"]?.ToString(),
                TiendaDestino    = dr["TiendaDestino"]?.ToString(),
                IdTiendaOrigen   = dr["IdTiendaOrigen"]  == DBNull.Value ? 0 : Convert.ToInt32(dr["IdTiendaOrigen"]),
                IdTiendaDestino  = dr["IdTiendaDestino"] == DBNull.Value ? 0 : Convert.ToInt32(dr["IdTiendaDestino"]),
                Observaciones    = dr["Observaciones"]?.ToString(),
                Usuario          = dr["Usuario"]?.ToString(),
                FechaTraslado    = dr["FechaTraslado"]?.ToString(),
                EstadoAprobacion = dr["EstadoAprobacion"]?.ToString(),
                MotivoRechazo    = dr["MotivoRechazo"]?.ToString(),
                // Paso 2 — Supervisor ORIGEN
                UsuarioAprueba   = dr["UsuarioAprueba"]?.ToString(),
                FechaAprobacion  = dr["FechaAprobacion"]?.ToString(),
                // Paso 3 — Operador ORIGEN despacha
                UsuarioDespacha  = dr["UsuarioDespacha"]?.ToString(),
                FechaDespacho    = dr["FechaDespacho"]?.ToString(),
                // Paso 4 — Operador DESTINO recepciona
                UsuarioRecibe    = dr["UsuarioRecibe"]?.ToString(),
                FechaRecepcion   = dr["FechaRecepcion"]?.ToString(),
                // Resumen
                CantidadItems    = dr["CantidadItems"]  == DBNull.Value ? 0 : Convert.ToInt32(dr["CantidadItems"]),
                TotalUnidades    = dr["TotalUnidades"]  == DBNull.Value ? 0 : Convert.ToInt32(dr["TotalUnidades"]),
            };
        }

        private (bool resultado, string mensaje) EjecutarSpTraslado(string sp, Action<SqlCommand> addParams)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand(sp, cn) { CommandType = CommandType.StoredProcedure })
            {
                addParams(cmd);
                var pR = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);           pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",   SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                try   { cn.Open(); cmd.ExecuteNonQuery(); return ((bool)pR.Value, pM.Value?.ToString()); }
                catch (Exception ex) { return (false, "Error: " + ex.Message); }
            }
        }

        /// <summary>Paso 1 — Operador DESTINO crea la solicitud con N productos (XML).</summary>
        public (bool resultado, string mensaje, int idTraslado) CrearSolicitudTraslado(
            int idTiendaOrigen, int idTiendaDestino, int idUsuario,
            string detalleXml, string observaciones)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_CrearSolicitudTraslado", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTiendaOrigen",  idTiendaOrigen);
                cmd.Parameters.AddWithValue("@IdTiendaDestino", idTiendaDestino);
                cmd.Parameters.AddWithValue("@IdUsuario",       idUsuario);
                cmd.Parameters.Add("@DetalleXml", SqlDbType.Xml).Value = detalleXml;
                cmd.Parameters.AddWithValue("@Observaciones",   (object)observaciones ?? DBNull.Value);
                var pR = cmd.Parameters.Add("@Resultado",  SqlDbType.Bit);           pR.Direction = ParameterDirection.Output;
                var pM = cmd.Parameters.Add("@Mensaje",    SqlDbType.NVarChar, 300); pM.Direction = ParameterDirection.Output;
                var pI = cmd.Parameters.Add("@IdTraslado", SqlDbType.Int);            pI.Direction = ParameterDirection.Output;
                try
                {
                    cn.Open(); cmd.ExecuteNonQuery();
                    return ((bool)pR.Value, pM.Value?.ToString(), pI.Value == DBNull.Value ? 0 : (int)pI.Value);
                }
                catch (Exception ex) { return (false, "Error: " + ex.Message, 0); }
            }
        }

        /// <summary>Paso 2 — Supervisor ORIGEN aprueba o rechaza.</summary>
        public (bool resultado, string mensaje) AprobarRechazarSolicitudTraslado(
            int idTraslado, int idUsuario, bool aprobar, string motivoRechazo = null)
        {
            return EjecutarSpTraslado("usp_AprobarRechazarSolicitudTraslado", cmd =>
            {
                cmd.Parameters.AddWithValue("@IdTraslado",    idTraslado);
                cmd.Parameters.AddWithValue("@IdUsuario",     idUsuario);
                cmd.Parameters.AddWithValue("@Aprobar",       aprobar ? 1 : 0);
                cmd.Parameters.AddWithValue("@MotivoRechazo", (object)motivoRechazo ?? DBNull.Value);
            });
        }

        /// <summary>Paso 3 — Operador ORIGEN despacha y descuenta stock en origen.</summary>
        public (bool resultado, string mensaje) DespacharTraslado(int idTraslado, int idUsuario)
        {
            return EjecutarSpTraslado("usp_DespacharTraslado", cmd =>
            {
                cmd.Parameters.AddWithValue("@IdTraslado", idTraslado);
                cmd.Parameters.AddWithValue("@IdUsuario",  idUsuario);
            });
        }

        /// <summary>Paso 4 — Operador DESTINO recepciona y acredita stock en destino.</summary>
        public (bool resultado, string mensaje) RecepcionarTraslado(int idTraslado, int idUsuario)
        {
            return EjecutarSpTraslado("usp_RecepcionarTraslado", cmd =>
            {
                cmd.Parameters.AddWithValue("@IdTraslado", idTraslado);
                cmd.Parameters.AddWithValue("@IdUsuario",  idUsuario);
            });
        }

        /// <summary>Lista de traslados filtrada por estado y/o tienda origen/destino.</summary>
        public List<Traslado> ObtenerTraslados(string estado = "", int idTiendaOrigen = 0, int idTiendaDestino = 0)
        {
            var lista = new List<Traslado>();
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerTraslados", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@Estado",          estado          ?? "");
                cmd.Parameters.AddWithValue("@IdTiendaOrigen",  idTiendaOrigen);
                cmd.Parameters.AddWithValue("@IdTiendaDestino", idTiendaDestino);
                try
                {
                    cn.Open();
                    var dr = cmd.ExecuteReader();
                    while (dr.Read()) lista.Add(MapTraslado(dr));
                }
                catch { lista = new List<Traslado>(); }
            }
            return lista;
        }

        /// <summary>Historial de traslados con filtro de fecha.</summary>
        public List<Traslado> ObtenerHistorialTraslados(
            DateTime fechaInicio, DateTime fechaFin,
            int idTiendaOrigen = 0, int idTiendaDestino = 0, string estado = "")
        {
            var lista = new List<Traslado>();
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerHistorialTraslados", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@FechaInicio",     fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FechaFin",        fechaFin.Date);
                cmd.Parameters.AddWithValue("@IdTiendaOrigen",  idTiendaOrigen);
                cmd.Parameters.AddWithValue("@IdTiendaDestino", idTiendaDestino);
                cmd.Parameters.AddWithValue("@Estado",          estado ?? "");
                try
                {
                    cn.Open();
                    var dr = cmd.ExecuteReader();
                    while (dr.Read()) lista.Add(MapTraslado(dr));
                }
                catch { lista = new List<Traslado>(); }
            }
            return lista;
        }

        /// <summary>Detalle (ítems) de un traslado específico.</summary>
        public List<TrasladoDetalle> ObtenerDetalleTraslado(int idTraslado)
        {
            var lista = new List<TrasladoDetalle>();
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerDetalleTraslado", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdTraslado", idTraslado);
                try
                {
                    cn.Open();
                    var dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new TrasladoDetalle
                        {
                            IdTrasladoDetalle = Convert.ToInt32(dr["IdTrasladoDetalle"]),
                            IdProducto        = Convert.ToInt32(dr["IdProducto"]),
                            CodigoProducto    = dr["CodigoProducto"]?.ToString(),
                            NombreProducto    = dr["NombreProducto"]?.ToString(),
                            Cantidad          = Convert.ToInt32(dr["Cantidad"]),
                            StockOrigen       = dr["StockOrigen"] == DBNull.Value ? 0 : Convert.ToInt32(dr["StockOrigen"]),
                        });
                    }
                }
                catch { lista = new List<TrasladoDetalle>(); }
            }
            return lista;
        }

        /// <summary>Retorna tiendas de un traslado (para validaciones en controller).</summary>
        public (int idOrigen, int idDestino) ObtenerTiendasDeTraslado(int idTraslado)
        {
            using (var cn = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand(
                "SELECT IdTiendaOrigen, IdTiendaDestino FROM dbo.TRASLADO WHERE IdTraslado = @Id", cn))
            {
                cmd.Parameters.AddWithValue("@Id", idTraslado);
                try
                {
                    cn.Open();
                    var dr = cmd.ExecuteReader();
                    if (dr.Read())
                        return (Convert.ToInt32(dr["IdTiendaOrigen"]), Convert.ToInt32(dr["IdTiendaDestino"]));
                    return (0, 0);
                }
                catch { return (0, 0); }
            }
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
        // PDF HOJA DE INVENTARIO
        // =============================================

        /// <summary>
        /// Devuelve los datos necesarios para generar la hoja PDF de inventario:
        /// un objeto con Header (info del inventario) y Productos (lista de la tienda).
        /// </summary>
        public object ObtenerInventarioPDF(int idInventario)
        {
            object header = null;
            var productos = new List<object>();

            using (var oConexion = new SqlConnection(Conexion.CN))
            using (var cmd = new SqlCommand("usp_ObtenerInventarioParaPDF", oConexion)
                   { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@IdInventario", idInventario);
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        // Result set 1: cabecera
                        if (dr.Read())
                        {
                            header = new {
                                IdInventario      = Convert.ToInt32(dr["IdInventario"]),
                                Numero            = dr["Numero"]?.ToString() ?? "",
                                NombreTienda      = dr["NombreTienda"]?.ToString() ?? "",
                                Estado            = dr["Estado"]?.ToString() ?? "",
                                Observacion       = dr["Observacion"]?.ToString() ?? "",
                                FechaRegistro     = dr["FechaRegistro"]?.ToString() ?? "",
                                FechaInicio       = dr["FechaInicio"]?.ToString() ?? "",
                                FechaFinalizacion = dr["FechaFinalizacion"]?.ToString() ?? "",
                                Supervisor        = dr["Supervisor"]?.ToString() ?? "",
                                Operadores        = dr["Operadores"]?.ToString() ?? ""
                            };
                        }
                        // Result set 2: productos
                        if (dr.NextResult())
                        {
                            while (dr.Read())
                            {
                                productos.Add(new {
                                    NumFila   = Convert.ToInt32(dr["NumFila"]),
                                    Codigo    = dr["Codigo"]?.ToString() ?? "",
                                    Nombre    = dr["Nombre"]?.ToString() ?? "",
                                    Categoria = dr["Categoria"]?.ToString() ?? "",
                                    Stock     = Convert.ToInt32(dr["Stock"])
                                });
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("ObtenerInventarioPDF ERROR: " + ex.Message);
                }
            }

            return new { Header = header, Productos = productos };
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
                            EstadoStock  = dr["EstadoStock"].ToString(),
                            Descripcion  = dr["Descripcion"].ToString(),
                            CostoUnitario = Convert.ToDecimal(dr["CostoUnitario"]),
                            PrecioVenta   = Convert.ToDecimal(dr["PrecioVenta"])
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