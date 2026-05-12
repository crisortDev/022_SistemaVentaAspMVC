using CapaDatos;
using System;
using System.Globalization;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Gestión de Notas de Crédito (formato SET Paraguay).
    /// Permite registrar el documento físico recibido del proveedor
    /// y cambiar el estado de Pendiente a Recibida o Rechazada.
    /// </summary>
    [AuthorizeRol("NotaCredito", "*")]
    public class NotaCreditoController : BaseController
    {
        // ============================================================
        //  VISTA PRINCIPAL
        // ============================================================

        [AuthorizeRol("NotaCredito", "Index")]
        public ActionResult Index()
        {
            ViewBag.Tiendas = CapaDatos.CD_Tienda.Instancia.ObtenerTiendas();
            return View();
        }

        // ============================================================
        //  JSON: OBTENER LISTA
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCredito", "Index")]
        public JsonResult Obtener(int idtienda = 0, string estado = "")
        {
            // Seguridad: usuario no SuperAdmin solo ve su tienda
            if (!EsSuperAdmin)
                idtienda = TiendaActiva;

            var lista = CD_NotaCredito.Instancia.ObtenerNotasCredito(idtienda, estado);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON: CONFIRMAR RECEPCIÓN DEL DOCUMENTO FÍSICO
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCredito", "Index")]
        public JsonResult ConfirmarRecepcion(
            int    idnc,
            string numeronc,
            string numerotimbrado,
            string fechavencTimbrado,
            string fechaemision,
            string observacion)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(numeronc))
                return Json(new { resultado = false, mensaje = "Debe ingresar el Número de Nota de Crédito." });

            if (string.IsNullOrWhiteSpace(numerotimbrado))
                return Json(new { resultado = false, mensaje = "Debe ingresar el Número de Timbrado." });

            DateTime fvt, fems;

            if (!DateTime.TryParseExact(fechavencTimbrado, "dd/MM/yyyy",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out fvt))
                return Json(new { resultado = false, mensaje = "Fecha de Vencimiento de Timbrado inválida." });

            if (!DateTime.TryParseExact(fechaemision, "dd/MM/yyyy",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out fems))
                return Json(new { resultado = false, mensaje = "Fecha de Emisión inválida." });

            var rpt = CD_NotaCredito.Instancia.ConfirmarRecepcion(
                idnc, numeronc, numerotimbrado, fvt, fems, observacion,
                UsuarioActual.IdUsuario);

            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        // ============================================================
        //  JSON: RECHAZAR NC
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCredito", "Index")]
        public JsonResult Rechazar(int idnc, string observacion)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(observacion))
                return Json(new { resultado = false, mensaje = "Debe ingresar el motivo del rechazo." });

            var rpt = CD_NotaCredito.Instancia.Rechazar(idnc, observacion, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }
    }
}
