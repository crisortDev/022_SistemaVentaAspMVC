using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_ComprobanteCobro
    {
        private static CD_ComprobanteCobro _instancia = null;
        private CD_ComprobanteCobro() { }
        public static CD_ComprobanteCobro Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_ComprobanteCobro();
                return _instancia;
            }
        }

        // ----------------------------------------------------------------
        //  HISTORIAL DE COMPROBANTES (contado + crédito cobrado)
        // ----------------------------------------------------------------
        public List<ComprobanteCobro> ObtenerListaComprobanteCobro(
            int idTienda, DateTime fechaInicio, DateTime fechaFin)
        {
            List<ComprobanteCobro> lista = new List<ComprobanteCobro>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaComprobanteCobro", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin",    fechaFin);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(MapearComprobante(dr));
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<ComprobanteCobro>();
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  CUENTAS POR COBRAR (crédito pendiente de pago)
        // ----------------------------------------------------------------
        public List<ComprobanteCobro> ObtenerCuentasPorCobrar(
            int idTienda, bool soloVencidas = false)
        {
            List<ComprobanteCobro> lista = new List<ComprobanteCobro>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerCuentasPorCobrar", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda",     idTienda);
                cmd.Parameters.AddWithValue("@SoloVencidas", soloVencidas ? 1 : 0);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ComprobanteCobro
                            {
                                IdComprobanteCobro = Convert.ToInt32(dr["IdComprobanteCobro"]),
                                NumeroCobro        = dr["NumeroCobro"].ToString(),
                                Estado             = dr["Estado"].ToString(),
                                MontoTotal         = Convert.ToDecimal(dr["MontoTotal"]),
                                MontoRecibido      = Convert.ToDecimal(dr["MontoRecibido"]),
                                MontoCambio        = Convert.ToDecimal(dr["MontoCambio"]),
                                FechaRegistro      = dr["FechaEmision"].ToString(),
                                NumeroFactura      = dr["NumeroFactura"].ToString(),
                                CodigoVenta        = dr["CodigoVenta"].ToString(),
                                Condicion          = dr["Condicion"].ToString(),
                                PlazoCredito       = dr["PlazoCredito"] == DBNull.Value ? (int?)null : Convert.ToInt32(dr["PlazoCredito"]),
                                FechaVencimiento   = dr["FechaVencimiento"].ToString(),
                                DiasParaVencer     = dr["DiasParaVencer"] == DBNull.Value ? (int?)null : Convert.ToInt32(dr["DiasParaVencer"]),
                                NombreCliente      = dr["NombreCliente"].ToString(),
                                NumeroDocumento    = dr["NumeroDocumento"].ToString(),
                                TelefonoCliente    = dr["TelefonoCliente"].ToString(),
                                NombreTienda       = dr["NombreTienda"].ToString(),
                                NombreCajero       = dr["NombreCajero"].ToString(),
                                FormaCobro         = dr["FormaCobroOriginal"].ToString()
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<ComprobanteCobro>();
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  REGISTRAR COBRO DE CRÉDITO
        //  Retorna: resultado, mensaje e idCompCobro (para abrir recibo)
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idCompCobro) CobrarCuenta(
            int     idCompCobro,
            int     idCaja,
            int     idUsuario,
            int     idFormaCobro,
            decimal montoRecibido,
            string  observacion = "")
        {
            try
            {
                using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (SqlCommand cmd = new SqlCommand("usp_CobrarCuentaPendiente", oConexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@IdCompCobro",   idCompCobro);
                        cmd.Parameters.AddWithValue("@IdCaja",        idCaja);
                        cmd.Parameters.AddWithValue("@IdUsuario",     idUsuario);
                        cmd.Parameters.AddWithValue("@IdFormaCobro",  idFormaCobro);
                        cmd.Parameters.AddWithValue("@MontoRecibido", montoRecibido);
                        cmd.Parameters.AddWithValue("@Observacion",   observacion ?? "");

                        SqlParameter pRes = cmd.Parameters.Add("@Resultado", SqlDbType.Bit);
                        pRes.Direction = ParameterDirection.Output;
                        SqlParameter pMsg = cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 400);
                        pMsg.Direction = ParameterDirection.Output;
                        SqlParameter pId  = cmd.Parameters.Add("@IdCompCobroOut", SqlDbType.Int);
                        pId.Direction = ParameterDirection.Output;

                        cmd.ExecuteNonQuery();

                        int retId = pId.Value != null && pId.Value != DBNull.Value
                                    ? Convert.ToInt32(pId.Value) : idCompCobro;

                        return ((bool)pRes.Value, pMsg.Value?.ToString(), retId);
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error: " + ex.Message, 0);
            }
        }

        // ----------------------------------------------------------------
        //  OBTENER DATOS DEL RECIBO PARA IMPRIMIR
        // ----------------------------------------------------------------
        public ComprobanteCobro ObtenerReciboCobro(int idCompCobro)
        {
            ComprobanteCobro recibo = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerReciboCobro", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdCompCobro", idCompCobro);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            recibo = new ComprobanteCobro
                            {
                                IdComprobanteCobro = Convert.ToInt32(dr["IdComprobanteCobro"]),
                                NumeroCobro        = dr["NumeroCobro"].ToString(),
                                NumeroFactura      = dr["NumeroFactura"].ToString(),
                                Condicion          = dr["Condicion"].ToString(),
                                NombreCliente      = dr["NombreCliente"].ToString(),
                                NumeroDocumento    = dr["NumeroDocumento"].ToString(),
                                TelefonoCliente    = dr["TelefonoCliente"].ToString(),
                                DireccionCliente   = dr["DireccionCliente"].ToString(),
                                MontoTotal         = Convert.ToDecimal(dr["MontoTotal"]),
                                MontoRecibido      = Convert.ToDecimal(dr["MontoRecibido"]),
                                MontoCambio        = Convert.ToDecimal(dr["MontoCambio"]),
                                FormaCobro         = dr["FormaCobro"].ToString(),
                                FechaRegistro      = dr["FechaEmision"].ToString(),
                                FechaCobro         = dr["FechaCobro"].ToString(),
                                PlazoCredito       = dr["PlazoCredito"] == DBNull.Value ? (int?)null : Convert.ToInt32(dr["PlazoCredito"]),
                                FechaVencimiento   = dr["FechaVencimiento"].ToString(),
                                NombreCobrador     = dr["NombreCobrador"].ToString(),
                                Observacion        = dr["Observacion"].ToString(),
                                NombreTienda       = dr["NombreTienda"].ToString(),
                                DireccionTienda    = dr["DireccionTienda"].ToString(),
                                TelefonoTienda     = dr["TelefonoTienda"].ToString(),
                            };
                        }
                    }
                }
                catch (Exception)
                {
                    recibo = null;
                }
            }
            return recibo;
        }

        // ----------------------------------------------------------------
        //  HELPER: mapear fila del SP de historial
        // ----------------------------------------------------------------
        private ComprobanteCobro MapearComprobante(SqlDataReader dr)
        {
            return new ComprobanteCobro
            {
                IdComprobanteCobro = Convert.ToInt32(dr["IdComprobanteCobro"]),
                NumeroCobro        = dr["NumeroCobro"].ToString(),
                NumeroFactura      = dr["NumeroFactura"].ToString(),
                CodigoVenta        = dr["CodigoVenta"].ToString(),
                Estado             = dr["Estado"].ToString(),
                MontoTotal         = Convert.ToDecimal(dr["MontoTotal"]),
                MontoRecibido      = Convert.ToDecimal(dr["MontoRecibido"]),
                MontoCambio        = Convert.ToDecimal(dr["MontoCambio"]),
                FormaCobro         = dr["FormaCobro"].ToString(),
                FechaRegistro      = dr["FechaRegistro"].ToString(),
                NombreCliente      = dr["NombreCliente"].ToString(),
                NumeroDocumento    = dr["NumeroDocumento"].ToString(),
                NombreCajero       = dr["NombreCajero"].ToString(),
                NombreTienda       = dr["NombreTienda"].ToString(),
                Condicion          = dr.GetColumnIndex("Condicion") >= 0
                                     ? dr["Condicion"].ToString() : "Contado",
                FechaVencimiento   = dr.GetColumnIndex("FechaVencimiento") >= 0
                                     ? dr["FechaVencimiento"].ToString() : null,
                DiasParaVencer     = dr.GetColumnIndex("DiasParaVencer") >= 0 && dr["DiasParaVencer"] != DBNull.Value
                                     ? (int?)Convert.ToInt32(dr["DiasParaVencer"]) : null
            };
        }
    }

    // Extensión para verificar si una columna existe en el DataReader
    internal static class DataReaderExtensions
    {
        internal static int GetColumnIndex(this SqlDataReader dr, string columnName)
        {
            try { return dr.GetOrdinal(columnName); }
            catch { return -1; }
        }
    }
}
