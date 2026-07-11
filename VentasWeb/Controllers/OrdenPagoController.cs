using CapaDatos;
using CapaModelo;
using System;
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
    }
}
