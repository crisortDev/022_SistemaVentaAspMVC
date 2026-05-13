using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;

namespace CapaDatos
{
    public class CD_OrdenVenta
    {
        private static CD_OrdenVenta _instancia = null;
        private CD_OrdenVenta() { }
        public static CD_OrdenVenta Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_OrdenVenta();
                return _instancia;
            }
        }

        // ----------------------------------------------------------------
        //  REGISTRAR ORDEN DE VENTA (Pre-venta)
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje, int idGenerado) RegistrarOrdenVenta(
            int idTienda, int? idCliente, int idUsuarioRegistro,
            string observacion, string fechaVencimiento, string detalleXml)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarOrdenVenta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                    cmd.Parameters.AddWithValue("@IdCliente",
                        idCliente.HasValue ? (object)idCliente.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdUsuarioRegistro", idUsuarioRegistro);
                    cmd.Parameters.AddWithValue("@Observacion",
                        string.IsNullOrWhiteSpace(observacion) ? (object)DBNull.Value : observacion);
                    cmd.Parameters.AddWithValue("@FechaVencimiento", fechaVencimiento);
                    cmd.Parameters.Add("@DetalleXml", SqlDbType.Xml).Value = detalleXml;

                    cmd.Parameters.Add("@IdOVGenerada", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    int id = cmd.Parameters["@IdOVGenerada"].Value != DBNull.Value
                           ? Convert.ToInt32(cmd.Parameters["@IdOVGenerada"].Value) : 0;

                    return (ok, msg, id);
                }
                catch (Exception ex)
                {
                    return (false, "Error al registrar pre-venta: " + ex.Message, 0);
                }
            }
        }

        // ----------------------------------------------------------------
        //  LISTAR ORDENES DE VENTA
        // ----------------------------------------------------------------
        public List<OrdenVenta> ObtenerListaOrdenVenta(
            int idTienda, string estado, DateTime fechaInicio, DateTime fechaFin, string numeroOV)
        {
            List<OrdenVenta> lista = new List<OrdenVenta>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerListaOrdenVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                cmd.Parameters.AddWithValue("@Estado", estado ?? "");
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
                cmd.Parameters.AddWithValue("@NumeroOV", numeroOV ?? "");

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new OrdenVenta()
                            {
                                IdOrdenVenta      = Convert.ToInt32(dr["IdOrdenVenta"]),
                                NumeroOV          = dr["NumeroOV"].ToString(),
                                Estado            = dr["Estado"].ToString(),
                                TotalEstimado     = Convert.ToDecimal(dr["TotalEstimado"]),
                                IVA10             = Convert.ToDecimal(dr["IVA10"]),
                                IVA5              = Convert.ToDecimal(dr["IVA5"]),
                                Exento0           = Convert.ToDecimal(dr["Exento0"]),
                                FechaRegistro     = dr["FechaRegistro"].ToString(),
                                FechaVencimiento  = dr["FechaVencimiento"].ToString(),
                                AlertaVencimiento = dr["AlertaVencimiento"].ToString(),
                                NombreTienda      = dr["NombreTienda"].ToString(),
                                NombreUsuario     = dr["NombreUsuario"].ToString(),
                                NombreCliente     = dr["NombreCliente"].ToString(),
                                DocumentoCliente  = dr["DocumentoCliente"].ToString()
                            });
                        }
                    }
                }
                catch (Exception)
                {
                    lista = new List<OrdenVenta>();
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  DETALLE ORDEN DE VENTA (2 resultsets)
        // ----------------------------------------------------------------
        public OrdenVenta ObtenerDetalleOrdenVenta(int idOrdenVenta)
        {
            OrdenVenta orden = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleOrdenVenta_V", oConexion);
                cmd.Parameters.AddWithValue("@IdOrdenVenta", idOrdenVenta);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        // RS1: cabecera
                        if (dr.Read())
                        {
                            orden = new OrdenVenta()
                            {
                                IdOrdenVenta         = Convert.ToInt32(dr["IdOrdenVenta"]),
                                NumeroOV             = dr["NumeroOV"].ToString(),
                                Estado               = dr["Estado"].ToString(),
                                TotalEstimado        = Convert.ToDecimal(dr["TotalEstimado"]),
                                IVA10                = Convert.ToDecimal(dr["IVA10"]),
                                IVA5                 = Convert.ToDecimal(dr["IVA5"]),
                                Exento0              = Convert.ToDecimal(dr["Exento0"]),
                                FechaRegistro        = dr["FechaRegistro"].ToString(),
                                FechaVencimiento     = dr["FechaVencimiento"].ToString(),
                                Observacion          = dr["Observacion"].ToString(),
                                NombreTienda         = dr["NombreTienda"].ToString(),
                                RUCTienda            = dr["RUCTienda"].ToString(),
                                NombreUsuario        = dr["NombreUsuario"].ToString(),
                                NombreCliente        = dr["NombreCliente"].ToString(),
                                DocumentoCliente     = dr["DocumentoCliente"].ToString(),
                                DireccionCliente     = dr["DireccionCliente"].ToString(),
                                TelefonoCliente      = dr["TelefonoCliente"].ToString(),
                                TipoDocumentoCliente = dr["TipoDocumentoCliente"].ToString(),
                                oDetalle             = new List<DetalleOrdenVenta>()
                            };
                        }

                        // RS2: detalle de productos
                        if (orden != null && dr.NextResult())
                        {
                            while (dr.Read())
                            {
                                orden.oDetalle.Add(new DetalleOrdenVenta()
                                {
                                    IdDetalleOV     = Convert.ToInt32(dr["IdDetalleOV"]),
                                    IdProducto      = Convert.ToInt32(dr["IdProducto"]),
                                    Codigo          = dr["Codigo"].ToString(),
                                    NombreProducto  = dr["NombreProducto"].ToString(),
                                    Cantidad        = Convert.ToInt32(dr["Cantidad"]),
                                    PrecioUnidad    = Convert.ToDecimal(dr["PrecioUnidad"]),
                                    IvaPorcentaje   = Convert.ToDecimal(dr["IvaPorcentaje"]),
                                    TotalLinea      = Convert.ToDecimal(dr["TotalLinea"]),
                                    TotalLineaIva   = Convert.ToDecimal(dr["TotalLineaIva"]),
                                    StockDisponible = Convert.ToInt32(dr["StockDisponible"])
                                });
                            }
                        }
                    }
                }
                catch (Exception)
                {
                    orden = null;
                }
            }
            return orden;
        }

        // ----------------------------------------------------------------
        //  ANULAR ORDEN DE VENTA
        // ----------------------------------------------------------------
        public (bool resultado, string mensaje) AnularOrdenVenta(
            int idOrdenVenta, int idUsuario, string motivoAnulacion)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_AnularOrdenVenta", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@IdOrdenVenta", idOrdenVenta);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    cmd.Parameters.AddWithValue("@MotivoAnulacion",
                        string.IsNullOrWhiteSpace(motivoAnulacion) ? (object)DBNull.Value : motivoAnulacion);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("@Mensaje", SqlDbType.NVarChar, 500).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                    string msg = cmd.Parameters["@Mensaje"].Value?.ToString() ?? "";
                    return (ok, msg);
                }
                catch (Exception ex)
                {
                    return (false, "Error al anular pre-venta: " + ex.Message);
                }
            }
        }
    }
}
