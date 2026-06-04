using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_CajaVenta
    {
        private static readonly CD_CajaVenta _instancia = new CD_CajaVenta();
        public static CD_CajaVenta Instancia => _instancia;
        private CD_CajaVenta() { }

        // ── Cajas disponibles (activas, sin sesión abierta) ───────
        public List<object> ObtenerCajasDisponibles(int idTienda)
        {
            var lista = new List<object>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                oConexion.Open();
                using (var cmd = new SqlCommand("usp_ObtenerCajasDisponibles", oConexion))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new
                            {
                                IdPuntoCaja     = Convert.ToInt32(dr["IdPuntoCaja"]),
                                Codigo          = dr["Codigo"].ToString(),
                                Nombre          = dr["Nombre"].ToString(),
                                PuntoExpedicion = dr["PuntoExpedicion"].ToString(),
                                NombreTienda    = dr["NombreTienda"].ToString()
                            });
                        }
                    }
                }
            }
            return lista;
        }

        // ── Abrir caja ────────────────────────────────────────────
        public (bool resultado, string mensaje, int idCaja) AbrirCaja(
            int idTienda, int idUsuario, decimal montoApertura, int idPuntoCaja)
        {
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_AbrirCaja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdTienda",      idTienda);
                        cmd.Parameters.AddWithValue("@IdUsuario",     idUsuario);
                        cmd.Parameters.AddWithValue("@MontoApertura", montoApertura);
                        cmd.Parameters.AddWithValue("@IdPuntoCaja",   idPuntoCaja);

                        var pResultado = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);
                        pResultado.Direction = ParameterDirection.Output;
                        var pMensaje = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300);
                        pMensaje.Direction = ParameterDirection.Output;
                        var pIdCaja = cmd.Parameters.Add("@IdCaja", SqlDbType.Int);
                        pIdCaja.Direction = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();

                        return (
                            (bool)pResultado.Value,
                            pMensaje.Value?.ToString(),
                            pIdCaja.Value == DBNull.Value ? 0 : (int)pIdCaja.Value
                        );
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error: " + ex.Message, 0);
            }
        }

        // ── Obtener caja activa de la tienda ──────────────────────
        public SesionCaja ObtenerCajaActiva(int idTienda, int idUsuario = 0)
        {
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerCajaActiva", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                        cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);

                        using (var dr = cmd.ExecuteReader())
                        {
                            if (dr.Read())
                            {
                                return new SesionCaja
                                {
                                    IdCaja              = Convert.ToInt32(dr["IdCaja"]),
                                    IdTienda            = Convert.ToInt32(dr["IdTienda"]),
                                    NombreTienda        = dr["NombreTienda"].ToString(),
                                    IdUsuario           = Convert.ToInt32(dr["IdUsuario"]),
                                    NombreUsuario       = dr["NombreUsuario"].ToString(),
                                    FechaApertura       = Convert.ToDateTime(dr["FechaApertura"]),
                                    MontoApertura       = Convert.ToDecimal(dr["MontoApertura"]),
                                    Estado              = dr["Estado"].ToString(),
                                    TotalVentas         = Convert.ToDecimal(dr["TotalVentas"]),
                                    CantidadVentas      = Convert.ToInt32(dr["CantidadVentas"]),
                                    // Nuevos campos (script 82)
                                    TotalVentasContado  = Convert.ToDecimal(dr["TotalVentasContado"]),
                                    CantVentasContado   = Convert.ToInt32(dr["CantVentasContado"]),
                                    TotalVentasCredito  = Convert.ToDecimal(dr["TotalVentasCredito"]),
                                    CantVentasCredito   = Convert.ToInt32(dr["CantVentasCredito"]),
                                    TotalCobrosCXC      = Convert.ToDecimal(dr["TotalCobrosCXC"]),
                                    CantCobrosCXC       = Convert.ToInt32(dr["CantCobrosCXC"])
                                };
                            }
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        // ── Obtener operaciones de una caja ───────────────────────
        public (List<OperacionCaja> operaciones, List<ResumenFormaCobro> resumen)
            ObtenerOperaciones(int idCaja)
        {
            var operaciones = new List<OperacionCaja>();
            var resumen     = new List<ResumenFormaCobro>();

            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerOperacionesCaja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdCaja", idCaja);

                        using (var ds = new DataSet())
                        using (var da = new SqlDataAdapter(cmd))
                        {
                            da.Fill(ds);

                            if (ds.Tables.Count > 0)
                            {
                                var cols0 = ds.Tables[0].Columns;
                                foreach (DataRow dr in ds.Tables[0].Rows)
                                {
                                    operaciones.Add(new OperacionCaja
                                    {
                                        IdVenta       = Convert.ToInt32(dr["IdVenta"]),
                                        NumeroFactura = dr["NumeroFactura"].ToString(),
                                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                                        NombreCliente = dr["NombreCliente"].ToString(),
                                        FormaCobro    = dr["FormaCobro"].ToString(),
                                        Monto         = Convert.ToDecimal(dr["Monto"]),
                                        MontoRecibido = dr["MontoRecibido"] == DBNull.Value ? 0 : Convert.ToDecimal(dr["MontoRecibido"]),
                                        MontoCambio   = dr["MontoCambio"]   == DBNull.Value ? 0 : Convert.ToDecimal(dr["MontoCambio"]),
                                        NombreCajero  = dr["NombreCajero"].ToString(),
                                        Estado        = cols0.Contains("Estado")    ? dr["Estado"].ToString()    : "Activa",
                                        Condicion     = cols0.Contains("Condicion") ? dr["Condicion"].ToString() : "Contado"
                                    });
                                }
                            }

                            if (ds.Tables.Count > 1)
                            {
                                foreach (DataRow dr in ds.Tables[1].Rows)
                                {
                                    resumen.Add(new ResumenFormaCobro
                                    {
                                        FormaCobro = dr["FormaCobro"].ToString(),
                                        Cantidad   = Convert.ToInt32(dr["Cantidad"]),
                                        TotalMonto = Convert.ToDecimal(dr["TotalMonto"])
                                    });
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("ObtenerOperaciones ERROR: " + ex.Message);
            }

            return (operaciones, resumen);
        }

        // ── Cerrar caja ───────────────────────────────────────────
        public (bool resultado, string mensaje) CerrarCaja(
            int idCaja, int idUsuario, decimal montoContado, string observacion)
        {
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_CerrarCaja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdCaja",       idCaja);
                        cmd.Parameters.AddWithValue("@IdUsuario",    idUsuario);
                        cmd.Parameters.AddWithValue("@MontoContado", montoContado);
                        cmd.Parameters.AddWithValue("@Observacion",  observacion ?? "");

                        var pResultado = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);
                        pResultado.Direction = ParameterDirection.Output;
                        var pMensaje = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 300);
                        pMensaje.Direction = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();

                        return ((bool)pResultado.Value, pMensaje.Value?.ToString());
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error: " + ex.Message);
            }
        }

        // ── Obtener detalle completo de una caja (apertura + ops + resumen) ──
        public DetalleCaja ObtenerDetalleCaja(int idCaja)
        {
            DetalleCaja detalle = null;
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerDetalleCaja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdCaja", idCaja);

                        using (var ds = new DataSet())
                        using (var da = new SqlDataAdapter(cmd))
                        {
                            da.Fill(ds);

                            // RS1 — cabecera
                            if (ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                            {
                                var dr = ds.Tables[0].Rows[0];
                                detalle = new DetalleCaja
                                {
                                    IdCaja          = Convert.ToInt32(dr["IdCaja"]),
                                    IdTienda        = Convert.ToInt32(dr["IdTienda"]),
                                    NombreTienda    = dr["NombreTienda"].ToString(),
                                    DireccionTienda = dr["DireccionTienda"].ToString(),
                                    TelefonoTienda  = dr["TelefonoTienda"].ToString(),
                                    Aperturista     = dr["Aperturista"].ToString(),
                                    FechaApertura   = Convert.ToDateTime(dr["FechaApertura"]),
                                    MontoApertura   = Convert.ToDecimal(dr["MontoApertura"]),
                                    FechaCierre     = dr["FechaCierre"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaCierre"]),
                                    UsuarioCierre   = dr["UsuarioCierre"].ToString(),
                                    MontoSistema    = Convert.ToDecimal(dr["MontoSistema"]),
                                    MontoContado    = Convert.ToDecimal(dr["MontoContado"]),
                                    Diferencia      = Convert.ToDecimal(dr["Diferencia"]),
                                    Estado          = dr["Estado"].ToString(),
                                    Observacion     = dr["Observacion"].ToString(),
                                    RazonSocial     = dr["RazonSocial"].ToString(),
                                    NumeroTimbrado  = dr["NumeroTimbrado"].ToString(),
                                    Establecimiento = dr["Establecimiento"].ToString(),
                                    PuntoExpedicion = dr["PuntoExpedicion"].ToString(),
                                    CodigoCaja      = dr.Table.Columns.Contains("CodigoCaja") ? dr["CodigoCaja"].ToString() : "",
                                    NombreCaja      = dr.Table.Columns.Contains("NombreCaja") ? dr["NombreCaja"].ToString() : "",
                                    CantidadVentas  = Convert.ToInt32(dr["CantidadVentas"]),
                                    TotalVentas     = Convert.ToDecimal(dr["TotalVentas"])
                                };
                            }

                            if (detalle == null) return null;

                            // RS2 — operaciones
                            if (ds.Tables.Count > 1)
                            {
                                foreach (DataRow dr in ds.Tables[1].Rows)
                                {
                                    var cols = dr.Table.Columns;
                                    detalle.Operaciones.Add(new OperacionCaja
                                    {
                                        IdVenta       = Convert.ToInt32(dr["IdVenta"]),
                                        NumeroFactura = dr["NumeroFactura"].ToString(),
                                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                                        NombreCliente = dr["NombreCliente"].ToString(),
                                        FormaCobro    = dr["FormaCobro"].ToString(),
                                        Monto         = Convert.ToDecimal(dr["Monto"]),
                                        MontoRecibido = Convert.ToDecimal(dr["MontoRecibido"]),
                                        MontoCambio   = Convert.ToDecimal(dr["MontoCambio"]),
                                        NombreCajero  = dr["NombreCajero"].ToString(),
                                        Estado        = cols.Contains("Estado") ? dr["Estado"].ToString() : "Activa"
                                    });
                                }
                            }

                            // RS3 — resumen
                            if (ds.Tables.Count > 2)
                            {
                                foreach (DataRow dr in ds.Tables[2].Rows)
                                {
                                    detalle.Resumen.Add(new ResumenFormaCobro
                                    {
                                        FormaCobro = dr["FormaCobro"].ToString(),
                                        Cantidad   = Convert.ToInt32(dr["Cantidad"]),
                                        TotalMonto = Convert.ToDecimal(dr["TotalMonto"])
                                    });
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("ObtenerDetalleCaja ERROR: " + ex.Message);
            }
            return detalle;
        }

        // ── Cobros de crédito de una sesión de caja ──────────────
        public List<CobroCXC> ObtenerCobrosCXC(int idCaja)
        {
            var lista = new List<CobroCXC>();
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerCobrosCXC_Caja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdCaja", idCaja);
                        using (var dr = cmd.ExecuteReader())
                        {
                            while (dr.Read())
                            {
                                lista.Add(new CobroCXC
                                {
                                    IdCobroCXC     = Convert.ToInt32(dr["IdCobroCXC"]),
                                    FechaCobro     = Convert.ToDateTime(dr["FechaCobro"]),
                                    NumeroCobro    = dr["NumeroCobro"].ToString(),
                                    NumeroFactura  = dr["NumeroFactura"].ToString(),
                                    NombreCliente  = dr["NombreCliente"].ToString(),
                                    FormaCobro     = dr["FormaCobro"].ToString(),
                                    MontoFactura   = Convert.ToDecimal(dr["MontoFactura"]),
                                    MontoRecibido  = Convert.ToDecimal(dr["MontoRecibido"]),
                                    MontoCambio    = Convert.ToDecimal(dr["MontoCambio"]),
                                    NombreCobrador = dr["NombreCobrador"].ToString()
                                });
                            }
                        }
                    }
                }
            }
            catch { }
            return lista;
        }

        // ── Historial de cajas cerradas ───────────────────────────
        public List<SesionCaja> ObtenerHistorial(int idTienda)
        {
            var lista = new List<SesionCaja>();
            try
            {
                using (var oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (var cmd = new SqlCommand("usp_ObtenerHistorialCaja", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                        using (var dr = cmd.ExecuteReader())
                        {
                            while (dr.Read())
                            {
                                lista.Add(new SesionCaja
                                {
                                    IdCaja        = Convert.ToInt32(dr["IdCaja"]),
                                    NombreTienda  = dr["NombreTienda"].ToString(),
                                    NombreUsuario = dr["Aperturista"].ToString(),
                                    FechaApertura = Convert.ToDateTime(dr["FechaApertura"]),
                                    MontoApertura = Convert.ToDecimal(dr["MontoApertura"]),
                                    FechaCierre   = dr["FechaCierre"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaCierre"]),
                                    Cierre        = dr["Cierre"].ToString(),
                                    MontoSistema  = dr["MontoSistema"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["MontoSistema"]),
                                    MontoContado  = dr["MontoContado"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["MontoContado"]),
                                    Diferencia    = dr["Diferencia"]   == DBNull.Value ? (decimal?)null : Convert.ToDecimal(dr["Diferencia"]),
                                    Estado        = dr["Estado"].ToString(),
                                    Observacion   = dr["Observacion"]?.ToString()
                                });
                            }
                        }
                    }
                }
            }
            catch { }
            return lista;
        }
    }
}
