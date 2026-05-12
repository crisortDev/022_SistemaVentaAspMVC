using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Controlador del módulo Órdenes de Compra.
    /// ──────────────────────────────────────────
    ///  * Los usuarios operativos crean la OC → queda Pendiente.
    ///  * El administrador de la sucursal la Aprueba o la Rechaza.
    ///  * La OC aprobada es la base para una factura (Compra).
    ///  * 1 OC puede recibir 1..N facturas y 1 factura puede cubrir
    ///    1..N OCs (tabla intermedia CompraOrdenCompra).
    ///  * Cada línea de detalle se controla con CantidadFacturada ≤
    ///    Cantidad para evitar que se use más de una vez.
    ///
    /// Las acciones usan [AuthorizeRol("OrdenCompra", "*")] a nivel
    /// de clase para exigir sesión y al menos UN submenú activo del
    /// módulo. Las acciones sensibles (Aprobar/Rechazar/Anular)
    /// refuerzan la validación apuntando a su submenú específico.
    /// </summary>
    [AuthorizeRol("OrdenCompra", "*")]
    public partial class OrdenCompraController : BaseController
    {
        // ============================================================
        //  VISTAS
        // ============================================================

        [AuthorizeRol("OrdenCompra", "Crear")]
        public ActionResult Crear()
        {
            ViewBag.IdUsuario   = UsuarioActual?.IdUsuario ?? 0;
            ViewBag.Categorias  = CD_CategoriaOC.Instancia.Obtener();
            return View();
        }

        [AuthorizeRol("OrdenCompra", "Consultar")]
        public ActionResult Consultar()
        {
            return View();
        }

        [AuthorizeRol("OrdenCompra", "Aprobaciones")]
        public ActionResult Aprobaciones()
        {
            ViewBag.MotivosRechazo = CD_MotivoRechazoOC.Instancia.Obtener();
            return View();
        }

        public ActionResult Documento(int idordencompra = 0)
        {
            OrdenCompra oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra)
                           ?? new OrdenCompra() { oListaDetalle = new List<DetalleOrdenCompra>() };

            if (oc.oListaDetalle == null)
                oc.oListaDetalle = new List<DetalleOrdenCompra>();

            return View(oc);
        }

        // ============================================================
        //  LOOKUPS
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerProveedores()
        {
            List<Proveedor> lista = CD_Proveedor.Instancia.ObtenerProveedor();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }


        [HttpGet]
        public JsonResult ObtenerDetalleOrdenCompra(int idordencompra)
        {
            try
            {
                OrdenCompra oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
                if (oc == null)
                    return Json(new { resultado = false, mensaje = "Orden no encontrada." }, JsonRequestBehavior.AllowGet);

                return Json(new { resultado = true, data = oc }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ============================================================
        //  LISTAR
        // ============================================================

        [HttpGet]
        public JsonResult Obtener(string fechainicio, string fechafin,
                                  int idproveedor, int idtienda, string estado)
        {
            // Usuarios no SuperAdmin → forzar su propia tienda
            if (!EsSuperAdmin)
                idtienda = TiendaActiva;

            List<OrdenCompra> lista = CD_OrdenCompra.Instancia.ObtenerListaOrdenCompra(
                Convert.ToDateTime(fechainicio),
                Convert.ToDateTime(fechafin),
                idproveedor,
                idtienda,
                estado ?? ""
            );
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        public JsonResult ObtenerOrden(int idordencompra)
        {
            OrdenCompra oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            if (oc == null)
                return Json(new { resultado = false, mensaje = "Orden no encontrada." }, JsonRequestBehavior.AllowGet);

            return Json(new { resultado = true, data = oc }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  REGISTRAR
        // ============================================================

        [HttpPost]
        public JsonResult Guardar(int idproveedor, int idtienda,
                                  string fechaentrega, string observacion,
                                  int idcategoriaoc, string fechatopeentrega,
                                  List<DetalleOrdenCompra> detalle)
        {
            try
            {
                var usuario = UsuarioActual;
                if (usuario == null)
                    return Json(new { resultado = false, mensaje = "Sesión expirada." });

                if (detalle == null || !detalle.Any())
                    return Json(new { resultado = false, mensaje = "Debe agregar al menos un producto al detalle." });

                if (idproveedor <= 0)
                    return Json(new { resultado = false, mensaje = "Debe seleccionar un proveedor." });

                // Si no es SuperAdmin, la tienda es la propia
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                if (idtienda <= 0)
                    return Json(new { resultado = false, mensaje = "Debe seleccionar una tienda." });

                if (!TienePermiso(idtienda))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para registrar órdenes en esta sucursal." });

                // ── Calcular totales server-side (no confiar en valores del cliente) ──
                var ci = System.Globalization.CultureInfo.InvariantCulture;
                decimal totalEstimado    = 0;
                decimal totalEstimadoIva = 0;

                // El SP usp_RegistrarOrdenCompra espera:
                //   cabecera en /OrdenCompra/*
                //   productos en /OrdenCompra/Detalle/Item
                StringBuilder xmlItems = new StringBuilder();
                foreach (var d in detalle)
                {
                    if (d.oProducto == null || d.oProducto.IdProducto <= 0)
                        return Json(new { resultado = false, mensaje = "Hay un ítem sin producto." });
                    if (d.Cantidad <= 0)
                        return Json(new { resultado = false, mensaje = "La cantidad de cada ítem debe ser mayor a 0." });
                    if (d.PrecioUnitario <= 0)
                        return Json(new { resultado = false, mensaje = "El precio unitario debe ser mayor a 0." });

                    // Recalcular siempre en el servidor
                    decimal iva          = d.IvaPorcentaje > 0 ? d.IvaPorcentaje : 10;
                    decimal linea        = d.Cantidad * d.PrecioUnitario;
                    decimal lineaIva     = linea * (1 + iva / 100m);
                    totalEstimado        += linea;
                    totalEstimadoIva     += lineaIva;

                    xmlItems.Append("<Item>");
                    xmlItems.Append("<IdProducto>").Append(d.oProducto.IdProducto).Append("</IdProducto>");
                    xmlItems.Append("<Cantidad>").Append(d.Cantidad).Append("</Cantidad>");
                    xmlItems.Append("<PrecioUnitario>").Append(d.PrecioUnitario.ToString(ci)).Append("</PrecioUnitario>");
                    xmlItems.Append("<IvaPorcentaje>").Append(iva.ToString(ci)).Append("</IvaPorcentaje>");
                    xmlItems.Append("<TotalLinea>").Append(linea.ToString(ci)).Append("</TotalLinea>");
                    xmlItems.Append("<TotalLineaIva>").Append(lineaIva.ToString(ci)).Append("</TotalLineaIva>");
                    xmlItems.Append("</Item>");
                }

                StringBuilder xml = new StringBuilder();
                xml.Append("<OrdenCompra>");
                xml.Append("<IdProveedor>").Append(idproveedor).Append("</IdProveedor>");
                xml.Append("<IdTienda>").Append(idtienda).Append("</IdTienda>");
                xml.Append("<IdUsuario>").Append(usuario.IdUsuario).Append("</IdUsuario>");
                xml.Append("<FechaEntregaEstimada>").Append(LimpiarFecha(fechaentrega)).Append("</FechaEntregaEstimada>");
                xml.Append("<FechaTopeEntrega>").Append(LimpiarFecha(fechatopeentrega)).Append("</FechaTopeEntrega>");
                xml.Append("<Observacion>").Append(EscaparXml(observacion)).Append("</Observacion>");
                xml.Append("<TotalEstimado>").Append(totalEstimado.ToString(ci)).Append("</TotalEstimado>");
                xml.Append("<TotalEstimadoIva>").Append(totalEstimadoIva.ToString(ci)).Append("</TotalEstimadoIva>");
                xml.Append("<IdCategoriaOC>").Append(idcategoriaoc > 0 ? idcategoriaoc : 0).Append("</IdCategoriaOC>");
                xml.Append("<Detalle>").Append(xmlItems).Append("</Detalle>");
                xml.Append("</OrdenCompra>");

                var rpt = CD_OrdenCompra.Instancia.RegistrarOrdenCompra(xml.ToString());
                return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje, idgenerado = rpt.idGenerado });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        // ============================================================
        //  APROBAR / RECHAZAR / ANULAR
        // ============================================================

        [HttpPost]
        [AuthorizeRol("OrdenCompra", "Aprobar")]
        public JsonResult Aprobar(int idordencompra)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // ── Validar permiso por sucursal ──────────────────
            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            if (oc == null || oc.oTienda == null)
                return Json(new { resultado = false, mensaje = "Orden no encontrada." });

            if (!TienePermiso(oc.oTienda.IdTienda))
                return Json(new { resultado = false, mensaje = "No puede aprobar órdenes de otra sucursal." });

            var rpt = CD_OrdenCompra.Instancia.AprobarOrdenCompra(idordencompra, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("OrdenCompra", "Aprobar")]
        public JsonResult Rechazar(int idordencompra, int idmotivorechazo, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (idmotivorechazo <= 0)
                return Json(new { resultado = false, mensaje = "Debe seleccionar un motivo de rechazo." });

            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            if (oc == null || oc.oTienda == null)
                return Json(new { resultado = false, mensaje = "Orden no encontrada." });

            if (!TienePermiso(oc.oTienda.IdTienda))
                return Json(new { resultado = false, mensaje = "No puede rechazar órdenes de otra sucursal." });

            var rpt = CD_OrdenCompra.Instancia.RechazarOrdenCompra(
                idordencompra, UsuarioActual.IdUsuario, idmotivorechazo, motivo ?? "");
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("OrdenCompra", "Anular")]
        public JsonResult Anular(int idordencompra)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            if (oc == null || oc.oTienda == null)
                return Json(new { resultado = false, mensaje = "Orden no encontrada." });

            if (!TienePermiso(oc.oTienda.IdTienda))
                return Json(new { resultado = false, mensaje = "No puede anular órdenes de otra sucursal." });

            var rpt = CD_OrdenCompra.Instancia.AnularOrdenCompra(idordencompra, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  APOYO: órdenes aprobadas abiertas (para vincular a factura)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerOrdenesAprobadas(int idproveedor = 0, int idtienda = 0)
        {
            try
            {
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                var lista = CD_OrdenCompra.Instancia.ObtenerOrdenesAprobadasPorProveedor(idproveedor, idtienda);
                return Json(new { data = lista ?? new List<OrdenCompra>() }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<OrdenCompra>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ============================================================
        //  VALIDAR STOCK — ítem individual (para alerta en tiempo real)
        // ============================================================

        /// <summary>
        /// Consulta rápida para un solo producto: devuelve stock actual,
        /// StockMaximo y si la cantidad pedida lo superaría.
        /// Usado por el JS para la alerta inline al escribir la cantidad.
        /// </summary>
        [HttpGet]
        public JsonResult ValidarStockItem(int idtienda, int idproducto, int cantidad)
        {
            if (!EsSuperAdmin) idtienda = TiendaActiva;

            try
            {
                using (var cn = new System.Data.SqlClient.SqlConnection(CapaDatos.Conexion.CN))
                {
                    cn.Open();
                    var cmd = new System.Data.SqlClient.SqlCommand(@"
                        SELECT ISNULL(pt.Stock,  0) AS StockActual,
                               ISNULL(p.StockMaximo, 0) AS StockMaximo
                        FROM dbo.PRODUCTO p
                        LEFT JOIN dbo.PRODUCTO_TIENDA pt
                               ON pt.IdProducto = p.IdProducto
                              AND pt.IdTienda   = @IdTienda
                        WHERE p.IdProducto = @IdProducto", cn);

                    cmd.Parameters.AddWithValue("@IdProducto", idproducto);
                    cmd.Parameters.AddWithValue("@IdTienda",   idtienda);

                    using (var dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            int stockMax    = Convert.ToInt32(dr["StockMaximo"]);
                            int stockActual = Convert.ToInt32(dr["StockActual"]);
                            bool supera     = stockMax > 0 && (stockActual + cantidad) > stockMax;

                            return Json(new
                            {
                                stockActual,
                                stockMax,
                                supera,
                                proyectado = stockActual + cantidad
                            }, JsonRequestBehavior.AllowGet);
                        }
                    }
                }
            }
            catch { /* silencioso — no romper la UX */ }

            return Json(new { stockActual = 0, stockMax = 0, supera = false, proyectado = cantidad },
                        JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  VALIDAR STOCK MÁXIMO ANTES DE GUARDAR LA OC
        // ============================================================

        /// <summary>
        /// Verifica si algún producto de la OC superaría el StockMaximo
        /// de la tienda destino. Devuelve lista de advertencias (vacía = OK).
        /// No bloquea: solo informa para que el usuario decida.
        /// </summary>
        [HttpPost]
        public JsonResult ValidarStock(int idtienda, List<ItemStockValidacion> items)
        {
            if (items == null || !items.Any())
                return Json(new { advertencias = new System.Collections.Generic.List<object>() });

            if (!EsSuperAdmin) idtienda = TiendaActiva;

            var advertencias = new System.Collections.Generic.List<object>();

            try
            {
                using (var cn = new System.Data.SqlClient.SqlConnection(CapaDatos.Conexion.CN))
                {
                    cn.Open();
                    foreach (var item in items)
                    {
                        var cmd = new System.Data.SqlClient.SqlCommand(@"
                            SELECT p.Nombre,
                                   ISNULL(pt.Stock,       0) AS StockActual,
                                   ISNULL(p.StockMaximo,  0) AS StockMaximo
                            FROM dbo.PRODUCTO p
                            LEFT JOIN dbo.PRODUCTO_TIENDA pt
                                   ON pt.IdProducto = p.IdProducto
                                  AND pt.IdTienda   = @IdTienda
                            WHERE p.IdProducto = @IdProducto", cn);

                        cmd.Parameters.AddWithValue("@IdProducto", item.IdProducto);
                        cmd.Parameters.AddWithValue("@IdTienda",   idtienda);

                        using (var dr = cmd.ExecuteReader())
                        {
                            if (dr.Read())
                            {
                                int stockMax    = Convert.ToInt32(dr["StockMaximo"]);
                                int stockActual = Convert.ToInt32(dr["StockActual"]);
                                int proyectado  = stockActual + item.Cantidad;

                                if (stockMax > 0 && proyectado > stockMax)
                                {
                                    advertencias.Add(new
                                    {
                                        Producto    = dr["Nombre"].ToString(),
                                        StockActual = stockActual,
                                        Pedido      = item.Cantidad,
                                        Proyectado  = proyectado,
                                        StockMax    = stockMax
                                    });
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                return Json(new { advertencias = new System.Collections.Generic.List<object>(), error = ex.Message });
            }

            return Json(new { advertencias });
        }

        // ============================================================
        //  HELPERS PRIVADOS
        // ============================================================

        private static string LimpiarFecha(string fecha)
        {
            if (string.IsNullOrWhiteSpace(fecha)) return "";
            // Intentar parsear dd/MM/yyyy → yyyy-MM-dd (formato ISO que SQL Server entiende sin ambigüedad)
            DateTime dt;
            if (DateTime.TryParseExact(fecha, new[] { "dd/MM/yyyy", "d/M/yyyy", "yyyy-MM-dd" },
                new System.Globalization.CultureInfo("es-PY"), System.Globalization.DateTimeStyles.None, out dt))
                return dt.ToString("yyyy-MM-dd");
            if (DateTime.TryParse(fecha, out dt))
                return dt.ToString("yyyy-MM-dd");
            return "";
        }

        private static string EscaparXml(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("&", "&amp;")
                    .Replace("<", "&lt;")
                    .Replace(">", "&gt;")
                    .Replace("\"", "&quot;")
                    .Replace("'", "&apos;");
        }
    }

    /// <summary>DTO para validación de stock por ítem de OC.</summary>
    public class ItemStockValidacion
    {
        public int IdProducto { get; set; }
        public int Cantidad   { get; set; }
    }
}
