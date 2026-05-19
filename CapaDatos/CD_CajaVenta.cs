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

        // ── Abrir caja ────────────────────────────────────────────
        public (bool resultado, string mensaje, int idCaja) AbrirCaja(
            int idTienda, int idUsuario, decimal montoApertura)
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
        public SesionCaja ObtenerCajaActiva(int idTienda)
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

                        using (var dr = cmd.ExecuteReader())
                        {
                            if (dr.Read())
                            {
                                return new SesionCaja
                                {
                                    IdCaja         = Convert.ToInt32(dr["IdCaja"]),
                                    IdTienda       = Convert.ToInt32(dr["IdTienda"]),
                                    NombreTienda   = dr["NombreTienda"].ToString(),
                                    IdUsuario      = Convert.ToInt32(dr["IdUsuario"]),
                                    NombreUsuario  = dr["NombreUsuario"].ToString(),
                                    FechaApertura  = Convert.ToDateTime(dr["FechaApertura"]),
                                    MontoApertura  = Convert.ToDecimal(dr["MontoApertura"]),
                                    Estado         = dr["Estado"].ToString(),
                                    TotalVentas    = Convert.ToDecimal(dr["TotalVentas"]),
                                    CantidadVentas = Convert.ToInt32(dr["CantidadVentas"])
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
                                        Estado        = dr["Estado"].ToString()
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
            catch { }

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
