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
    /// Extensión partial de CompraController — recepción, confirmación,
    /// nota de crédito y generación de Orden de Pago.
    ///
    /// REQUISITO PREVIO: CD_Compra.cs ya debe decir
    ///     public partial class CD_Compra
    /// y CompraController.cs debe decir
    ///     public partial class CompraController
    /// </summary>
    public partial class CompraController : BaseController
    {
        // ============================================================
        //  VISTA RECEPCION
        // ============================================================

        [AuthorizeRol("Compra", "Recepcion")]
        public ActionResult Recepcion(int idcompra = 0)
        {
            Compra oCompra = idcompra > 0
                ? CD_Compra.Instancia.ObtenerDetalleCompra(idcompra)
                : null;

            ViewBag.MotivosNC = CD_MotivoNotaCredito.Instancia.Obtener();
            return View(oCompra ?? new Compra());
        }

        // ============================================================
        //  JSON: LINEAS PARA RECEPCION
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerLineasRecepcion(int idcompra)
        {
            var lineas = CD_Compra.Instancia.ObtenerLineasParaRecepcion(idcompra);
            return Json(new { data = lineas }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON: REGISTRAR RECEPCION
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Recepcion")]
        public JsonResult RegistrarRecepcion(
            int idcompra,
            string fechafactura,
            string fechaentrega,
            List<DetalleRecepcion> lineas)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (lineas == null || lineas.Count == 0)
                return Json(new { resultado = false, mensaje = "Debe ingresar al menos una línea." });

            DateTime ff, fe;
            if (!DateTime.TryParseExact(fechafactura, "dd/MM/yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out ff))
                return Json(new { resultado = false, mensaje = "Fecha de factura inválida." });

            if (string.IsNullOrWhiteSpace(fechaentrega) ||
                !DateTime.TryParseExact(fechaentrega, "dd/MM/yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out fe))
                fe = DateTime.Today;

            var rpt = CD_Compra.Instancia.RegistrarRecepcion(idcompra, ff, fe, lineas);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: CONFIRMAR COMPRA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "Confirmar")]
        public JsonResult ConfirmarCompra(int idcompra)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_Compra.Instancia.ConfirmarCompra(idcompra);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: NOTA DE CREDITO
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Compra", "NotaCredito")]
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
