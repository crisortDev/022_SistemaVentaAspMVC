using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using Newtonsoft.Json;

namespace CapaDatos
{
    public class CD_Producto
    {
        public static CD_Producto _instancia = null;

        private CD_Producto() { }

        public static CD_Producto Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Producto();
                return _instancia;
            }
        }

        public List<Producto> ObtenerProducto()
        {
            List<Producto> rptListaProducto = new List<Producto>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerProductos", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaProducto.Add(new Producto()
                        {
                            IdProducto    = Convert.ToInt32(dr["IdProducto"].ToString()),
                            Codigo        = dr["Codigo"].ToString(),
                            ValorCodigo   = Convert.ToInt32(dr["ValorCodigo"].ToString()),
                            Nombre        = dr["Nombre"].ToString(),
                            Descripcion   = dr["DescripcionProducto"].ToString(),
                            IdCategoria   = Convert.ToInt32(dr["IdCategoria"].ToString()),
                            IvaPorcentaje = dr["IvaPorcentaje"] == DBNull.Value ? 10m  : Convert.ToDecimal(dr["IvaPorcentaje"]),
                            StockMaximo   = dr["StockMaximo"]  == DBNull.Value ? 0    : Convert.ToInt32(dr["StockMaximo"]),
                            oCategoria    = new Categoria() { Descripcion = dr["DescripcionCategoria"].ToString() },
                            Activo        = Convert.ToBoolean(dr["Activo"].ToString())
                        });
                    }
                    dr.Close();
                    return rptListaProducto;
                }
                catch
                {
                    return null;
                }
            }
        }

        public bool RegistrarProducto(Producto oProducto)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarProducto", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("Nombre",        oProducto.Nombre);
                    cmd.Parameters.AddWithValue("Descripcion",   oProducto.Descripcion);
                    cmd.Parameters.AddWithValue("IdCategoria",   oProducto.IdCategoria);
                    cmd.Parameters.AddWithValue("IvaPorcentaje", oProducto.IvaPorcentaje);
                    cmd.Parameters.AddWithValue("StockMaximo",   oProducto.StockMaximo);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        public bool ModificarProducto(Producto oProducto)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarProducto", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("IdProducto",    oProducto.IdProducto);
                    cmd.Parameters.AddWithValue("Nombre",        oProducto.Nombre);
                    cmd.Parameters.AddWithValue("Descripcion",   oProducto.Descripcion);
                    cmd.Parameters.AddWithValue("IdCategoria",   oProducto.IdCategoria);
                    cmd.Parameters.AddWithValue("IvaPorcentaje", oProducto.IvaPorcentaje);
                    cmd.Parameters.AddWithValue("StockMaximo",   oProducto.StockMaximo);
                    cmd.Parameters.AddWithValue("Activo",        oProducto.Activo);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        // ── Borrado lógico ────────────────────────────────────────
        public bool CambiarEstadoProducto(int idProducto, bool activo)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    string query = "UPDATE PRODUCTO SET Activo = @Activo WHERE IdProducto = @IdProducto";
                    using (SqlCommand cmd = new SqlCommand(query, oConexion))
                    {
                        cmd.Parameters.AddWithValue("@Activo", activo);
                        cmd.Parameters.AddWithValue("@IdProducto", idProducto);
                        oConexion.Open();
                        respuesta = cmd.ExecuteNonQuery() > 0;
                    }
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        // ── Precio Venta ──────────────────────────────────────────
        // BUG FIX: Este método usaba nombres de columna distintos (FechaInicioVigencia/FechaFinVigencia)
        // al SP real que devuelve FechaInicio/FechaFin. Unificado con ObtenerHistorialPreciosVentaPorProducto.
        // Mantenemos el método por compatibilidad pero delega al método correcto.
        public List<PrecioVenta> ObtenerPorProducto(int idProducto)
        {
            return ObtenerHistorialPreciosVentaPorProducto(idProducto);
        }

        public bool RegistrarPrecioVenta(PrecioVenta precio)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_RegistrarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("IdProducto", precio.IdProducto);
                cmd.Parameters.AddWithValue("PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("FechaInicio", precio.FechaInicioVigencia);
                cmd.Parameters.AddWithValue("FechaFin", (object)precio.FechaFinVigencia ?? DBNull.Value);
                cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { resultado = false; }
            }
            return resultado;
        }

        public bool ModificarPrecioVenta(PrecioVenta precio)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ModificarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("IdPrecioVenta", precio.IdPrecioVenta);
                cmd.Parameters.AddWithValue("IdProducto", precio.IdProducto);
                cmd.Parameters.AddWithValue("PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("FechaInicioVigencia", precio.FechaInicioVigencia);
                cmd.Parameters.AddWithValue("FechaFinVigencia", (object)precio.FechaFinVigencia ?? DBNull.Value);
                cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { resultado = false; }
            }
            return resultado;
        }

        public bool EliminarPrecioVenta(int idPrecioVenta)
        {
            bool resultado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_EliminarPrecioVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("IdPrecioVenta", idPrecioVenta);
                cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                try
                {
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { resultado = false; }
            }
            return resultado;
        }

        public List<PrecioVenta> ObtenerHistorialPreciosVentaPorProducto(int idProducto)
        {
            List<PrecioVenta> lista = new List<PrecioVenta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerHistorialPreciosVentaPorProducto", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdProducto", idProducto);
                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new PrecioVenta()
                        {
                            IdPrecioVenta = Convert.ToInt32(dr["IdPrecioVenta"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"]),
                            FechaInicioVigencia = Convert.ToDateTime(dr["FechaInicio"]),
                            FechaFinVigencia = dr["FechaFin"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaFin"])
                        });
                    }
                    dr.Close();
                }
                catch { lista = null; }
            }
            return lista;
        }

        public bool ActualizarPrecioVenta(PrecioVenta precio)
        {
            using (SqlConnection conn = new SqlConnection(Conexion.CN))
            using (SqlCommand cmd = new SqlCommand("sp_ActualizarPrecioVenta", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdPrecioVenta", precio.IdPrecioVenta);
                cmd.Parameters.AddWithValue("@PrecioVenta", precio.PrecioUnidadVenta);
                cmd.Parameters.AddWithValue("@FechaInicio", precio.FechaInicioVigencia);
                cmd.Parameters.AddWithValue("@FechaFin", (object)precio.FechaFinVigencia ?? DBNull.Value);
                cmd.Parameters.Add("@FilasAfectadas", SqlDbType.Int).Direction = ParameterDirection.Output;
                conn.Open();
                cmd.ExecuteNonQuery();
                return (int)cmd.Parameters["@FilasAfectadas"].Value > 0;
            }
        }

        public PrecioVenta ObtenerHistorialPreciosVentaPorId(int idPrecioVenta)
        {
            PrecioVenta resultado = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerPrecioVentaPorId", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdPrecioVenta", idPrecioVenta);
                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    if (dr.Read())
                    {
                        resultado = new PrecioVenta()
                        {
                            IdPrecioVenta = Convert.ToInt32(dr["IdPrecioVenta"]),
                            IdProducto = Convert.ToInt32(dr["IdProducto"]),
                            PrecioUnidadVenta = Convert.ToDecimal(dr["PrecioVenta"]),
                            FechaInicioVigencia = Convert.ToDateTime(dr["FechaInicio"]),
                            FechaFinVigencia = dr["FechaFin"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaFin"])
                        };
                    }
                    dr.Close();
                }
                catch { resultado = null; }
            }
            return resultado;
        }
    }
}