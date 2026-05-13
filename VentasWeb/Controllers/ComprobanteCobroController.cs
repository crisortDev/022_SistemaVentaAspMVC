using CapaDatos;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("ComprobanteCobro", "*")]
    public class ComprobanteCobroController : BaseController
    {
        [AuthorizeRol("ComprobanteCobro", "Comprobantes de Cobro")]
        public ActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [AuthorizeRol("ComprobanteCobro", "Comprobantes de Cobro")]
        public JsonResult Obtener(string fechainicio = "", string fechafin = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

            var lista = CD_ComprobanteCobro.Instancia.ObtenerListaComprobanteCobro(idTienda, fi, ff);
            return Json(new { data = lista ?? new List<CapaModelo.ComprobanteCobro>() },
                        JsonRequestBehavior.AllowGet);
        }
    }
}
