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
    public class OrdenCompraController : BaseController
    {
        // ============================================================
        //  VISTAS
        // ============================================================

        [AuthorizeRol("OrdenCompra", "Crear")]
        public ActionResult Crear()
        {
            ViewBag.IdUsuario = UsuarioActual?.IdUsuario ?? 0;
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
            // Reusa la vista Consultar? No. Tiene su propia vista
            // para ver solo Pendientes y con botones Aprobar/Rechazar.
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

                // ── Armar XML ─────────────────────────────────────
                decimal totalEstimado = detalle.Sum(d => d.TotalLinea);
                decimal totalEstimadoIva = detalle.Sum(d => d.TotalLineaIva);

                StringBuilder xml = new StringBuilder();
                xml.Append("<DETALLE>");
                xml.Append("<ORDEN>");
                xml.Append("<IdProveedor>").Append(idproveedor).Append("</IdProveedor>");
                xml.Append("<IdTienda>").Append(idtienda).Append("</IdTienda>");
                xml.Append("<IdUsuario>").Append(usuario.IdUsuario).Append("</IdUsuario>");
                xml.Append("<FechaEntregaEstimada>").Append(LimpiarFecha(fechaentrega)).Append("</FechaEntregaEstimada>");
                xml.Append("<Observacion>").Append(EscaparXml(observacion)).Append("</Observacion>");
                xml.Append("<TotalEstimado>").Append(totalEstimado.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</TotalEstimado>");
                xml.Append("<TotalEstimadoIva>").Append(totalEstimadoIva.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</TotalEstimadoIva>");
                xml.Append("</ORDEN>");
                xml.Append("<PRODUCTOS>");
                foreach (var d in detalle)
                {
                    if (d.oProducto == null || d.oProducto.IdProducto <= 0)
                        return Json(new { resultado = false, mensaje = "Hay un ítem sin producto." });
                    if (d.Cantidad <= 0)
                        return Json(new { resultado = false, mensaje = "La cantidad de cada ítem debe ser mayor a 0." });

                    xml.Append("<ITEM>");
                    xml.Append("<IdProducto>").Append(d.oProducto.IdProducto).Append("</IdProducto>");
                    xml.Append("<Cantidad>").Append(d.Cantidad).Append("</Cantidad>");
                    xml.Append("<PrecioUnitario>").Append(d.PrecioUnitario.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</PrecioUnitario>");
                    xml.Append("<IvaPorcentaje>").Append(d.IvaPorcentaje.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</IvaPorcentaje>");
                    xml.Append("<TotalLinea>").Append(d.TotalLinea.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</TotalLinea>");
                    xml.Append("<TotalLineaIva>").Append(d.TotalLineaIva.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append("</TotalLineaIva>");
                    xml.Append("</ITEM>");
                }
                xml.Append("</PRODUCTOS>");
                xml.Append("</DETALLE>");

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

            var rpt = CD_OrdenCompra.Instancia.AprobarOrdenCompra(idordencompra, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("OrdenCompra", "Aprobar")]
        public JsonResult Rechazar(int idordencompra, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(motivo))
                return Json(new { resultado = false, mensaje = "Debe indicar el motivo del rechazo." });

            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            if (oc == null || oc.oTienda == null)
                return Json(new { resultado = false, mensaje = "Orden no encontrada." });

            if (!TienePermiso(oc.oTienda.IdTienda))
                return Json(new { resultado = false, mensaje = "No puede rechazar órdenes de otra sucursal." });

            var rpt = CD_OrdenCompra.Instancia.RechazarOrdenCompra(idordencompra, UsuarioActual.IdUsuario, motivo);
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

            var rpt = CD_OrdenCompra.Instancia.AnularOrdenCompra(idordencompra);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  APOYO: órdenes aprobadas abiertas (para vincular a factura)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerOrdenesAprobadas(int idproveedor, int idtienda)
        {
            if (!EsSuperAdmin)
                idtienda = TiendaActiva;

            var lista = CD_OrdenCompra.Instancia.ObtenerOrdenesAprobadasPorProveedor(idproveedor, idtienda);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
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
}
