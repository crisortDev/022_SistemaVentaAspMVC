using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Extensión partial de CompraController — recepción desde OC, confirmación,
    /// nota de crédito y generación de Orden de Pago.
    /// </summary>
    public partial class CompraController : BaseController
    {
        // ============================================================
        //  DEBUG TEMPORAL — eliminar después de verificar el fix
        // ============================================================

        [HttpGet]
        public JsonResult DebugMiMenu()
        {
            var u = UsuarioActual;
            if (u == null)
                return Json(new { error = "sin sesion" }, JsonRequestBehavior.AllowGet);

            var subs = (u.oListaMenu ?? new List<CapaModelo.Menu>())
                .SelectMany(m => m.oSubMenu ?? System.Linq.Enumerable.Empty<SubMenu>())
                .Select(sm => new { sm.Controlador, sm.Nombre, sm.Activo })
                .ToList();

            return Json(new { correo = u.Correo, submenus = subs }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  VISTA RECEPCION
        // ============================================================

        [AuthorizeRol("Compra", "Recepcion")]
        public ActionResult Recepcion()
        {
            ViewBag.MotivosNC = CD_MotivoNotaCredito.Instancia.Obtener();
            return View(new Compra());
        }

        // ============================================================
        //  JSON: LÍNEAS DE UNA OC APROBADA (para cargar en recepción)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerLineasOC(int idordencompra)
        {
            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);

            if (oc == null)
                return Json(new { resultado = false, mensaje = "Orden de Compra no encontrada." },
                            JsonRequestBehavior.AllowGet);

            if (oc.Estado != "Aprobada")
                return Json(new { resultado = false, mensaje = "La OC no está en estado Aprobada. Estado actual: " + oc.Estado },
                            JsonRequestBehavior.AllowGet);

            return Json(new { resultado = true, data = oc }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON: REGISTRAR RECEPCIÓN DESDE OC (crea Compra + Detalle)
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Recepcion")]
        public JsonResult RegistrarRecepcionDesdeOC(
            int    idordencompra,
            string numerofactura,
            string numerotimbrado,
            string fechavencTimbrado,
            string fechafactura,
            string fechaentrega,
            List<CapaModelo.LineaRecepcionOC> lineas)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (lineas == null || lineas.Count == 0)
                return Json(new { resultado = false, mensaje = "Debe ingresar al menos una línea." });

            // Parsear fechas (formato dd/MM/yyyy del datepicker)
            DateTime ff, fe, fvt;

            if (!DateTime.TryParseExact(fechafactura, "dd/MM/yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out ff))
                return Json(new { resultado = false, mensaje = "Fecha de Factura inválida." });

            if (!DateTime.TryParseExact(fechavencTimbrado, "dd/MM/yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out fvt))
                return Json(new { resultado = false, mensaje = "Fecha de Vencimiento de Timbrado inválida." });

            if (string.IsNullOrWhiteSpace(fechaentrega) ||
                !DateTime.TryParseExact(fechaentrega, "dd/MM/yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out fe))
                fe = ff; // si no ingresó fecha entrega, usar fecha factura

            // ── Validar formato número de factura (SET PY: xxx-xxx-xxxxxxx) ──
            if (!System.Text.RegularExpressions.Regex.IsMatch(
                    numerofactura?.Trim() ?? "",
                    @"^\d{3}-\d{3}-\d{7}$"))
                return Json(new { resultado = false,
                    mensaje = "El número de factura debe tener el formato xxx-xxx-xxxxxxx (ej: 001-001-0000001)." });

            // ── Obtener y resolver fecha de creación de la OC ───────────────
            // FechaRegistro (DateTime) puede venir como MinValue si el SP no la mapea.
            // En ese caso usamos FechaOrden (string "dd/MM/yyyy") como fuente de verdad.
            var oc = CD_OrdenCompra.Instancia.ObtenerDetalleOrdenCompra(idordencompra);
            DateTime fechaCreacionOC = DateTime.MinValue;
            if (oc != null)
            {
                fechaCreacionOC = oc.FechaRegistro.Year > 1900
                    ? oc.FechaRegistro.Date
                    : (DateTime.TryParseExact(oc.FechaOrden,
                           new[] { "dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy" },
                           CultureInfo.InvariantCulture, DateTimeStyles.None, out var dfo)
                       ? dfo.Date
                       : DateTime.MinValue);
            }

            // ── Validar fecha de factura >= fecha de creación de la OC ──────
            if (oc != null && fechaCreacionOC > DateTime.MinValue && ff.Date < fechaCreacionOC)
                return Json(new { resultado = false,
                    mensaje = string.Format(
                        "La Fecha de Factura ({0:dd/MM/yyyy}) no puede ser anterior a la fecha de registro de la OC ({1:dd/MM/yyyy}).",
                        ff, fechaCreacionOC) });

            // ── Validar fecha de entrega >= fecha de creación de la OC ──────
            if (oc != null && fechaCreacionOC > DateTime.MinValue && fe.Date < fechaCreacionOC)
                return Json(new { resultado = false,
                    mensaje = string.Format(
                        "La Fecha de Entrega ({0:dd/MM/yyyy}) no puede ser anterior a la fecha de registro de la OC ({1:dd/MM/yyyy}).",
                        fe, fechaCreacionOC) });

            var rpt = CD_Compra.Instancia.RegistrarRecepcionDesdeOC(
                idordencompra,
                UsuarioActual.IdUsuario,
                numerofactura?.Trim()  ?? "",
                numerotimbrado?.Trim() ?? "",
                fvt, ff, fe,
                lineas);

            return Json(new
            {
                resultado = rpt.resultado,
                mensaje   = rpt.mensaje,
                idcompra  = rpt.idCompra
            });
        }

        // ============================================================
        //  VISTA REVISION (compras pendientes de confirmación)
        // ============================================================

        [AuthorizeRol("Compra", "Revision")]
        public ActionResult Revision()
        {
            ViewBag.MotivosNC = CD_MotivoNotaCredito.Instancia.Obtener();
            return View();
        }

        // ============================================================
        //  JSON: LISTA PARA REVISION
        // ============================================================

        [HttpGet]
        [AuthorizeRol("Compra", "Revision")]
        public JsonResult ObtenerRevision(string fechainicio, string fechafin,
                                          int idproveedor, int idtienda, string estado)
        {
            if (!EsAdminGlobal)
                idtienda = TiendaActiva;

            var lista = CD_Compra.Instancia.ObtenerListaRevision(
                Convert.ToDateTime(fechainicio),
                Convert.ToDateTime(fechafin),
                idproveedor,
                idtienda,
                string.IsNullOrWhiteSpace(estado) ? "Todos" : estado
            );
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON: CONFIRMAR COMPRA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Revision")]
        public JsonResult ConfirmarCompra(int idcompra)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_Compra.Instancia.ConfirmarCompra(idcompra, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: ANULAR COMPRA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Revision")]
        public JsonResult AnularCompra(int idcompra, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(motivo))
                return Json(new { resultado = false, mensaje = "Debe ingresar un motivo de anulación." });

            var rpt = CD_Compra.Instancia.AnularCompra(idcompra, UsuarioActual.IdUsuario, motivo);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: NOTA DE CREDITO
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Recepcion", "Revision")]   // Recepcion = Repositor puede generar NC desde su vista
        public JsonResult GenerarNotaCredito(int idcompra, int idmotivoNC)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (idmotivoNC <= 0)
                return Json(new { resultado = false, mensaje = "Debe seleccionar el motivo." });

            var rpt = CD_Compra.Instancia.GenerarNotaCredito(idcompra, idmotivoNC, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje, montonc = rpt.montoNC });
        }

        // ============================================================
        //  JSON: GENERAR ORDEN DE PAGO
        // ============================================================

        [HttpPost]
        [AuthorizeRol("OrdenPago", "Consultar")]
        public JsonResult GenerarOP(int idcompra, string modalidadPago = "Contado", int? numeroCuotas = null)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // Solo Encargado (IdRol 6) y SuperAdmin pueden generar Órdenes de Pago
            if (!EsSuperAdmin && UsuarioActual.IdRol != ID_ROL_ENCARGADO)
                return Json(new { resultado = false, mensaje = "Solo el Encargado puede generar Órdenes de Pago." });

            var rpt = CD_OrdenPago.Instancia.Generar(
                idcompra, UsuarioActual.IdUsuario, modalidadPago, numeroCuotas);
            return Json(new
            {
                resultado  = rpt.resultado,
                mensaje    = rpt.mensaje,
                idgenerado = rpt.idGenerado
            });
        }
    }

}
