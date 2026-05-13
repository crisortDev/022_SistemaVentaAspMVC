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
        //  LISTAR COMPROBANTES DE COBRO
        // ----------------------------------------------------------------
        public List<ComprobanteCobro> ObtenerListaComprobanteCobro(
            int idTienda, DateTime fechaInicio, DateTime fechaFin)
        {
            List<ComprobanteCobro> lista = new List<ComprobanteCobro>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaComprobanteCobro", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin);

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ComprobanteCobro()
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
                                NombreTienda       = dr["NombreTienda"].ToString()
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
    }
}
