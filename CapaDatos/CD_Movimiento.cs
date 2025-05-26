using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using CapaModelo;

namespace CapaDatos
{
    public class CD_Movimiento
    {
        private static CD_Movimiento _instancia = null;

        private CD_Movimiento() { }

        public static CD_Movimiento Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Movimiento();
                return _instancia;
            }
        }

        public List<Movimiento> ObtenerMovimientos(DateTime? fechaInicio, DateTime? fechaFin, int? proveedor, int? tienda)
        {
            var lista = new List<Movimiento>();

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                using (SqlCommand cmd = new SqlCommand("usp_ObtenerMovimientosCaja", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@FechaInicio", (object)fechaInicio ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FechaFin", (object)fechaFin ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Proveedor", (object)proveedor ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Tienda", (object)tienda ?? DBNull.Value);

                    cn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Movimiento()
                            {
                                IdMovimiento = Convert.ToInt32(dr["IdMovimiento"]),
                                NumeroFactura = dr["NumeroFactura"].ToString(),
                                NumeroTimbrado = dr["NumeroTimbrado"].ToString(),
                                FechaTransaccion = Convert.ToDateTime(dr["FechaTransaccion"]),
                                MontoOperacion = Convert.ToDecimal(dr["MontoOperacion"]),
                                EstadoPago = dr["EstadoPago"].ToString(),
                                IdTienda = Convert.ToInt32(dr["IdTienda"]),
                                IdUsuario = Convert.ToInt32(dr["IdUsuario"])
                                // Carga otros campos que necesites
                            });
                        }
                    }
                }
            }

            return lista;
        }

        public bool PagarMovimiento(int idMovimiento)
        {
            bool respuesta = false;

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                using (SqlCommand cmd = new SqlCommand("usp_PagarMovimiento", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdMovimiento", idMovimiento);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
            }

            return respuesta;
        }


        public bool CancelarMovimiento(int idMovimiento)
        {
            bool respuesta = false;

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                using (SqlCommand cmd = new SqlCommand("usp_CancelarMovimiento", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdMovimiento", idMovimiento);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    cn.Open();
                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
            }

            return respuesta;
        }
        public List<Movimiento> ObtenerMovimientos(DateTime? fechaInicio, DateTime? fechaFin, int pagina, int registrosPorPagina, out int totalRegistros)
        {
            var lista = new List<Movimiento>();
            totalRegistros = 0;

            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                using (SqlCommand cmd = new SqlCommand("usp_ObtenerMovimientosCaja", cn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@FechaInicio", (object)fechaInicio ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FechaFin", (object)fechaFin ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Pagina", pagina);
                    cmd.Parameters.AddWithValue("@RegistrosPorPagina", registrosPorPagina);

                    cn.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Movimiento()
                            {
                                IdMovimiento = Convert.ToInt32(dr["IdMovimiento"]),
                                NumeroFactura = dr["NumeroFactura"].ToString(),
                                NumeroTimbrado = dr["NumeroTimbrado"].ToString(),
                                FechaTransaccion = Convert.ToDateTime(dr["FechaTransaccion"]),
                                MontoOperacion = Convert.ToDecimal(dr["MontoOperacion"]),
                                EstadoPago = dr["EstadoPago"].ToString(),
                                IdTienda = Convert.ToInt32(dr["IdTienda"]),
                                IdUsuario = Convert.ToInt32(dr["IdUsuario"]),
                                IdProveedor = Convert.ToInt32(dr["IdProveedor"])
                            });
                        }

                        // Siguiente resultado: total de registros
                        if (dr.NextResult() && dr.Read())
                        {
                            totalRegistros = Convert.ToInt32(dr["TotalRegistros"]);
                        }
                    }
                }
            }

            return lista;
        }

    }
}
