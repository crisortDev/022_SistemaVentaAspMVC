using CapaModelo;
using CapaModelo.CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaDatos
{
    public class CD_Reportes
    {
        public static CD_Reportes _instancia = null;

        private CD_Reportes() { }

        public static CD_Reportes Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Reportes();
                return _instancia;
            }
        }

        // Formato: coma como separador de miles, punto como decimal → 100,000.00
        private static readonly NumberFormatInfo _formato = new NumberFormatInfo
        {
            NumberGroupSeparator = ",",
            NumberDecimalSeparator = ".",
            NumberDecimalDigits = 2
        };

        private string FormatearDecimal(object valor)
        {
            if (valor == null || valor == DBNull.Value) return "0.00";
            if (decimal.TryParse(valor.ToString(), out decimal resultado))
                return resultado.ToString("N", _formato);
            return "0.00";
        }

        public List<ReporteProducto> ReporteProductoTienda(int IdTienda, string CodigoProducto)
        {
            List<ReporteProducto> lista = new List<ReporteProducto>();

            string codigo = string.IsNullOrEmpty(CodigoProducto) ? "" : CodigoProducto.Trim();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_rptProductoTienda", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda", IdTienda);
                cmd.Parameters.AddWithValue("@Codigo", codigo);

                try
                {
                    oConexion.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteProducto()
                            {
                                RucTienda = dr["Ruc Tienda"].ToString(),
                                NombreTienda = dr["Nombre Tienda"].ToString(),
                                DireccionTienda = dr["Direccion Tienda"].ToString(),
                                CodigoProducto = dr["Codigo Producto"].ToString(),
                                NombreProducto = dr["Nombre Producto"].ToString(),
                                DescripcionProducto = dr["Descripcion Producto"].ToString(),
                                StockenTienda = dr["Stock en tienda"].ToString(),
                                PrecioCompra = FormatearDecimal(dr["Precio Compra"]),
                                PrecioVenta = FormatearDecimal(dr["Precio Venta"])
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error en ReporteProductoTienda: " + ex.Message);
                    lista = new List<ReporteProducto>();
                }
            }

            return lista;
        }

        public List<ReporteVenta> ReporteVenta(DateTime FechaInicio, DateTime FechaFin, int IdTienda)
        {
            List<ReporteVenta> lista = new List<ReporteVenta>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_rptVenta", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FechaInicio", FechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", FechaFin);
                cmd.Parameters.AddWithValue("@IdTienda", IdTienda);

                try
                {
                    oConexion.Open();

                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteVenta()
                            {
                                FechaVenta = dr["Fecha Venta"].ToString(),
                                NumeroDocumento = dr["Numero Documento"].ToString(),
                                TipoDocumento = dr["Tipo Documento"].ToString(),
                                NombreTienda = dr["Nombre Tienda"].ToString(),
                                RucTienda = dr["Ruc Tienda"].ToString(),
                                NombreEmpleado = dr["Nombre Empleado"].ToString(),
                                CantidadUnidadesVendidas = dr["Cantidad Unidades Vendidas"].ToString(),
                                CantidadProductos = dr["Cantidad Productos"].ToString(),
                                TotalVenta = FormatearDecimal(dr["Total Venta"])
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error en ReporteVenta: " + ex.Message);
                    lista = new List<ReporteVenta>();
                }
            }

            return lista;
        }

        public List<ReporteBaja> ReporteBajas(DateTime fechaInicio, DateTime fechaFin, int idTienda)
        {
            List<ReporteBaja> lista = new List<ReporteBaja>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_rptBajasProducto", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin.Date);
                cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                try
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteBaja
                            {
                                IdHistorial = Convert.ToInt32(dr["IdHistorial"]),
                                FechaMovimiento = dr["FechaMovimiento"].ToString(),
                                CodigoProducto = dr["CodigoProducto"].ToString(),
                                NombreProducto = dr["NombreProducto"].ToString(),
                                NombreTienda = dr["NombreTienda"].ToString(),
                                RucTienda = dr["RucTienda"].ToString(),
                                Observaciones = dr["Observaciones"].ToString(),
                                Cantidad = Convert.ToInt32(dr["Cantidad"])
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ReporteBajas: " + ex.Message);
                }
            }
            return lista;
        }
    }
}