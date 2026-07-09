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
                                FechaVenta               = dr["Fecha Venta"].ToString(),
                                NumeroDocumento          = dr["Numero Documento"].ToString(),
                                TipoDocumento            = dr["Tipo Documento"].ToString(),
                                Estado                   = dr["Estado"].ToString(),
                                Cliente                  = dr["Cliente"].ToString(),
                                FormaCobro               = dr["Forma Cobro"].ToString(),
                                NombreTienda             = dr["Nombre Tienda"].ToString(),
                                RucTienda                = dr["Ruc Tienda"].ToString(),
                                NombreEmpleado           = dr["Nombre Empleado"].ToString(),
                                CantidadUnidadesVendidas = dr["Cantidad Unidades Vendidas"].ToString(),
                                CantidadProductos        = dr["Cantidad Productos"].ToString(),
                                TotalVenta               = FormatearDecimal(dr["Total Venta"])
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

        public List<ReporteBaja> ReporteBajas(
            DateTime? fechaInicio, DateTime? fechaFin,
            int idTienda, string estadoAprobacion = "")
        {
            var lista = new List<ReporteBaja>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_rptBajasProducto", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value =
                    fechaInicio.HasValue ? (object)fechaInicio.Value.Date : DBNull.Value;
                cmd.Parameters.Add("@FechaFin", SqlDbType.Date).Value =
                    fechaFin.HasValue    ? (object)fechaFin.Value.Date    : DBNull.Value;
                cmd.Parameters.AddWithValue("@IdTienda",         idTienda);
                cmd.Parameters.AddWithValue("@EstadoAprobacion", estadoAprobacion ?? "");
                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteBaja
                            {
                                IdHistorial      = LeerInt(dr,  "IdHistorial"),
                                Numero           = LeerStr(dr,  "Numero"),
                                FechaMovimiento  = LeerStr(dr,  "FechaMovimiento"),
                                CodigoProducto   = LeerStr(dr,  "CodigoProducto"),
                                NombreProducto   = LeerStr(dr,  "NombreProducto"),
                                NombreTienda     = LeerStr(dr,  "NombreTienda"),
                                RucTienda        = LeerStr(dr,  "RucTienda"),
                                MotivoBaja       = LeerStr(dr,  "MotivoBaja"),
                                Observaciones    = LeerStr(dr,  "Observaciones"),
                                Cantidad         = LeerInt(dr,  "Cantidad"),
                                EstadoAprobacion = LeerStr(dr,  "EstadoAprobacion"),
                                UsuarioRegistro  = LeerStr(dr,  "UsuarioRegistro"),
                                UsuarioAprueba   = LeerStr(dr,  "UsuarioAprueba"),
                                FechaAprobacion  = LeerStr(dr,  "FechaAprobacion"),
                                MotivoRechazo    = LeerStr(dr,     "MotivoRechazo"),
                                CostoPromedio    = LeerDecimal(dr, "CostoPromedio")
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

        // ════════════════════════════════════════════════════════
        //  REPORTE NC ASOCIADAS
        // ════════════════════════════════════════════════════════

        public List<NotaCredito> ReporteNC(
            DateTime? fechaInicio, DateTime? fechaFin,
            int idProveedor, int idTienda, string estado)
        {
            var lista = new List<NotaCredito>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_rptNotaCredito", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FechaInicio",  SqlDbType.Date).Value =
                    fechaInicio.HasValue ? (object)fechaInicio.Value.Date : DBNull.Value;
                cmd.Parameters.Add("@FechaFin",     SqlDbType.Date).Value =
                    fechaFin.HasValue    ? (object)fechaFin.Value.Date    : DBNull.Value;
                cmd.Parameters.AddWithValue("@IdProveedor", idProveedor);
                cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                cmd.Parameters.AddWithValue("@Estado",      estado ?? "");
                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new NotaCredito
                            {
                                IdNC              = LeerInt(dr,     "IdNC"),
                                IdCompra          = LeerInt(dr,     "IdCompra"),
                                NumeroFactura     = LeerStr(dr,     "NumeroFactura"),
                                FechaFactura      = LeerStr(dr,     "FechaFactura"),
                                MontoFactura      = LeerDecimal(dr, "MontoFactura"),
                                NumeroNC          = LeerStr(dr,     "NumeroNC"),
                                NumeroTimbrado    = LeerStr(dr,     "NumeroTimbrado"),
                                FechaVencTimbrado = LeerStr(dr,     "FechaVencTimbrado"),
                                FechaEmision      = LeerStr(dr,     "FechaEmision"),
                                MontoNC           = LeerDecimal(dr, "MontoNC"),
                                Estado            = LeerStr(dr,     "Estado"),
                                DiasTranscurridos = LeerInt(dr,     "DiasTranscurridos"),
                                EsMorosa          = LeerBool(dr,    "EsMorosa"),
                                MotivoNC          = LeerStr(dr,     "MotivoNC"),
                                Observacion       = LeerStr(dr,     "Observacion"),
                                FechaRegistro     = LeerStr(dr,     "FechaRegistro"),
                                FechaConfirmacion = LeerStr(dr,     "FechaConfirmacion"),
                                UsuarioRegistro   = LeerStr(dr,     "UsuarioRegistro"),
                                Proveedor         = LeerStr(dr,     "Proveedor"),
                                RucProveedor      = LeerStr(dr,     "RucProveedor"),
                                Tienda            = LeerStr(dr,     "Tienda")
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ReporteNC: " + ex.Message);
                }
            }
            return lista;
        }

        // ════════════════════════════════════════════════════════
        //  REPORTE PROVEEDORES
        // ════════════════════════════════════════════════════════

        public List<ReporteProveedor> ReporteProveedores(
            DateTime? fechaInicio, DateTime? fechaFin,
            int idTienda, bool soloConDeuda)
        {
            var lista = new List<ReporteProveedor>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_rptProveedores", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FechaInicio",  SqlDbType.Date).Value =
                    fechaInicio.HasValue ? (object)fechaInicio.Value.Date : DBNull.Value;
                cmd.Parameters.Add("@FechaFin",     SqlDbType.Date).Value =
                    fechaFin.HasValue    ? (object)fechaFin.Value.Date    : DBNull.Value;
                cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                cmd.Parameters.AddWithValue("@SoloConDeuda", soloConDeuda ? 1 : 0);
                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteProveedor
                            {
                                IdProveedor      = LeerInt(dr,     "IdProveedor"),
                                Proveedor        = LeerStr(dr,     "Proveedor"),
                                RucProveedor     = LeerStr(dr,     "RucProveedor"),
                                Telefono         = LeerStr(dr,     "Telefono"),
                                Correo           = LeerStr(dr,     "Correo"),
                                CantidadCompras  = LeerInt(dr,     "CantidadCompras"),
                                TotalCompras     = LeerDecimal(dr, "TotalCompras"),
                                CantidadNC       = LeerInt(dr,     "CantidadNC"),
                                TotalMontoNC     = LeerDecimal(dr, "TotalMontoNC"),
                                NCPendientes     = LeerInt(dr,     "NCPendientes"),
                                MontoNCPendiente = LeerDecimal(dr, "MontoNCPendiente"),
                                NCRecibidas      = LeerInt(dr,     "NCRecibidas"),
                                NCRechazadas     = LeerInt(dr,     "NCRechazadas"),
                                MontoNeto        = LeerDecimal(dr, "MontoNeto"),
                                TieneMorosa      = LeerBool(dr,    "TieneMorosa")
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ReporteProveedores: " + ex.Message);
                }
            }
            return lista;
        }

        // ----------------------------------------------------------------
        //  REPORTE DE RENTABILIDAD POR PRODUCTO (CPP)
        // ----------------------------------------------------------------
        public List<ReporteRentabilidad> ObtenerRentabilidad(
            int idTienda, DateTime fechaInicio, DateTime fechaFin, int idCategoria = 0)
        {
            var lista = new List<ReporteRentabilidad>();
            using (var oConexion = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_rptRentabilidadProducto", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdTienda",    idTienda);
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio.Date);
                cmd.Parameters.AddWithValue("@FechaFin",    fechaFin.Date);
                cmd.Parameters.AddWithValue("@IdCategoria", idCategoria);
                try
                {
                    oConexion.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ReporteRentabilidad()
                            {
                                IdProducto         = LeerInt(dr,     "IdProducto"),
                                Codigo             = LeerStr(dr,     "Codigo"),
                                Producto           = LeerStr(dr,     "Producto"),
                                Categoria          = LeerStr(dr,     "Categoria"),
                                Tienda             = LeerStr(dr,     "Tienda"),
                                StockActual        = LeerInt(dr,     "StockActual"),
                                CostoPromedio      = LeerDecimal(dr, "CostoPromedio"),
                                PrecioVentaVigente = LeerDecimal(dr, "PrecioVentaVigente"),
                                UnidadesVendidas   = LeerInt(dr,     "UnidadesVendidas"),
                                IngresosTotales    = LeerDecimal(dr, "IngresosTotales"),
                                CostoTotalVentas   = LeerDecimal(dr, "CostoTotalVentas"),
                                UtilidadBruta      = LeerDecimal(dr, "UtilidadBruta"),
                                MargenBrutoPct     = LeerDecimal(dr, "MargenBrutoPct"),
                                ValorInventarioCPP = LeerDecimal(dr, "ValorInventarioCPP")
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ObtenerRentabilidad: " + ex.Message);
                }
            }
            return lista;
        }

        // ════════════════════════════════════════════════════════
        //  REPORTE TRASLADOS
        // ════════════════════════════════════════════════════════

        public List<Traslado> ReporteTraslados(
            DateTime? fechaInicio, DateTime? fechaFin,
            int idTienda, string estadoAprobacion = "")
        {
            var lista = new List<Traslado>();
            using (var cn = new SqlConnection(Conexion.CN))
            {
                var cmd = new SqlCommand("usp_rptTraslados", cn);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value =
                    fechaInicio.HasValue ? (object)fechaInicio.Value.Date : DBNull.Value;
                cmd.Parameters.Add("@FechaFin", SqlDbType.Date).Value =
                    fechaFin.HasValue    ? (object)fechaFin.Value.Date    : DBNull.Value;
                cmd.Parameters.AddWithValue("@IdTienda",         idTienda);
                cmd.Parameters.AddWithValue("@EstadoAprobacion", estadoAprobacion ?? "");
                try
                {
                    cn.Open();
                    using (var dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Traslado
                            {
                                IdTraslado       = LeerInt(dr, "IdTraslado"),
                                Numero           = LeerStr(dr, "Numero"),
                                FechaTraslado    = LeerStr(dr, "FechaTraslado"),
                                CodigoProducto   = LeerStr(dr, "CodigoProducto"),
                                NombreProducto   = LeerStr(dr, "NombreProducto"),
                                Cantidad         = LeerInt(dr, "Cantidad"),
                                TiendaOrigen     = LeerStr(dr, "TiendaOrigen"),
                                TiendaDestino    = LeerStr(dr, "TiendaDestino"),
                                Observaciones    = LeerStr(dr, "Observaciones"),
                                EstadoAprobacion = LeerStr(dr, "EstadoAprobacion"),
                                Usuario          = LeerStr(dr, "Usuario"),
                                UsuarioAprueba   = LeerStr(dr, "UsuarioAprueba"),
                                FechaAprobacion  = LeerStr(dr, "FechaAprobacion"),
                                MotivoRechazo    = LeerStr(dr, "MotivoRechazo")
                            });
                        }
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ReporteTraslados: " + ex.Message);
                }
            }
            return lista;
        }

        // ── Helpers defensivos (reutilizados de CD_NotaCredito) ──
        private static int     LeerInt(SqlDataReader dr, string c)
        { try { return dr[c] != DBNull.Value ? Convert.ToInt32(dr[c])  : 0;  } catch { return 0; } }
        private static decimal LeerDecimal(SqlDataReader dr, string c)
        { try { return dr[c] != DBNull.Value ? Convert.ToDecimal(dr[c]): 0m; } catch { return 0m; } }
        private static bool    LeerBool(SqlDataReader dr, string c)
        { try { return dr[c] != DBNull.Value && Convert.ToBoolean(dr[c]); }   catch { return false; } }
        private static string  LeerStr(SqlDataReader dr, string c)
        { try { return dr[c] != DBNull.Value ? dr[c].ToString() : ""; }       catch { return ""; } }
    }
}