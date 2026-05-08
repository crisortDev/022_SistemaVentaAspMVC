using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Globalization;
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
            if (!EsSuperAdmin)
                idtienda = TiendaActiva;

            var lista = CD_Compra.Instancia.ObtenerListaRevision(
                Convert.ToDateTime(fechainicio),
                Convert.ToDateTime(fechafin),
                idproveedor,
                idtienda,
                string.IsNullOrWhiteSpace(estado) ? "Pendiente" : estado
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
        [AuthorizeRol("Compra", "Revision")]
        public JsonResult GenerarNotaCredito(int idcompra, int idmotivoNC)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (idmotivoNC <= 0)
                return Json(new { resultado = false, mensaje = "Debe seleccionar el motivo." });

            var rpt = CD_Compra.Instancia.GenerarNotaCredito(idcompra, idmotivoNC);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: GENERAR ORDEN DE PAGO
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "OrdenPago")]
        public JsonResult GenerarOP(int idcompra)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_OrdenPago.Instancia.Generar(idcompra, UsuarioActual.IdUsuario);
            return Json(new
            {
                resultado  = rpt.resultado,
                mensaje    = rpt.mensaje,
                idgenerado = rpt.idGenerado
            });
        }
    }

}
