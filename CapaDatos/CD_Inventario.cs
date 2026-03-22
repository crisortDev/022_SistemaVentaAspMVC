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