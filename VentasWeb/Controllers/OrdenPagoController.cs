using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Controlador del módulo Órdenes de Pago.
    /// Las OP se generan a partir de compras confirmadas (ver CompraController.GenerarOP).
    /// Acá solo hay vistas de consulta y de impresión PDF.
    /// </summary>
    [AuthorizeRol("OrdenPago", "*")]
    public class OrdenPagoController : BaseController
    {
        // ── Vistas ────────────────────────────────────────────

        [AuthorizeRol("OrdenPago", "Consultar")]
        public ActionResult Consultar()
        {
            return View();
        }

        public ActionResult Documento(int idordenpago = 0)
        {
            OrdenPago op = CD_OrdenPago.Instancia.Obtener(idordenpago);
            if (op == null)
                return HttpNotFound();

            // ── Aislamiento por sucursal (SuperAdmin pasa) ──
            if (!TienePermiso(op.oTienda?.IdTienda ?? 0))
                return new HttpStatusCodeResult(403, "No tiene permiso para ver una orden de pago de otra sucursal.");

            return View(op);
        }

        /// <summary>Vista de aprobación de OPs para el supervisor.</summary>
        [AuthorizeRol("OrdenPago", "Aprobar")]
        public ActionResult Aprobar()
        {
            return View();
        }

        /// <summary>Vista del módulo Cuentas por Pagar.</summary>
        [AuthorizeRol("OrdenPago", "CuentasPorPagar")]
        public ActionResult CuentasPorPagar()
        {
            return View();
        }

        // ── JSON ──────────────────────────────────────────────

        [HttpGet]
        public JsonResult Obtener(string fechainicio, string fechafin, int idtienda, string estado)
        {
            if (!EsAdminGlobal) idtienda = TiendaActiva;

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                            ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                            ? DateTime.Today : Convert.ToDateTime(fechafin);

            var lista = CD_OrdenPago.Instancia.ObtenerLista(idtienda, fi, ff, estado);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        [AuthorizeRol("OrdenPago", "Aprobar")]
        public JsonResult ObtenerParaAprobacion(string fechainicio, string fechafin,
                                                int idtienda = 0, string estadoaprobacion = "Pendiente")
        {
            if (!EsAdminGlobal) idtienda = TiendaActiva;

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                            ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                            ? DateTime.Today : Convert.ToDateTime(fechafin);

            var lista = CD_OrdenPago.Instancia.ObtenerParaAprobacion(idtienda, estadoaprobacion, fi, ff);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        [AuthorizeRol("OrdenPago", "Aprobar")]
        public JsonResult AprobarOP(int idordenpago)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_OrdenPago.Instancia.Aprobar(idordenpago, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("OrdenPago", "Aprobar")]
        public JsonResult RechazarOP(int idordenpago, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(motivo))
                return Json(new { resultado = false, mensaje = "Debe ingresar un motivo de rechazo." });

            var rpt = CD_OrdenPago.Instancia.Rechazar(idordenpago, UsuarioActual.IdUsuario, motivo);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        [HttpGet]
        [AuthorizeRol("OrdenPago", "CuentasPorPagar")]
        public JsonResult ObtenerCXP(int idtienda = 0, int idproveedor = 0, string estado = "Pendiente")
        {
            if (!EsAdminGlobal) idtienda = TiendaActiva;
            var lista = CD_OrdenPago.Instancia.ObtenerCuentasPorPagar(idtienda, idproveedor, estado);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        /// <summary>Registra el pago de una OP de modalidad Contado (Aprobada → Pagada).</summary>
        [HttpPost]
        [AuthorizeRol("OrdenPago", "Aprobar")]
        public JsonResult RegistrarPagoOP(int idordenpago)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_OrdenPago.Instancia.RegistrarPago(idordenpago, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }

        /// <summary>Registra el pago de una cuota de crédito. Si completa todas las cuotas, cierra la OP.</summary>
        [HttpPost]
        [AuthorizeRol("OrdenPago", "CuentasPorPagar")]
        public JsonResult RegistrarPagoCuota(int idcuentaporpagar)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var rpt = CD_OrdenPago.Instancia.RegistrarPagoCuota(idcuentaporpagar, UsuarioActual.IdUsuario);
            return Json(new { resultado = rpt.resultado, mensaje = rpt.mensaje });
        }
    }
}
