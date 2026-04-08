using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class ConsultarCajaCompraController : BaseController
    {
        // GET: ConsultarCajaCompra
        public ActionResult ConsultarCajaCompra()
        {
            ViewBag.FechaInicio = DateTime.Now.AddDays(-7).ToString("yyyy-MM-dd");
            ViewBag.FechaFin = DateTime.Now.ToString("yyyy-MM-dd");
            return View();
        }


        [HttpPost]
        public JsonResult Pagar(int idMovimiento)
        {
            bool resultado = CD_Movimiento.Instancia.PagarMovimiento(idMovimiento);
            return Json(new { resultado });
        }


        [HttpPost]
        public JsonResult Cancelar(int idMovimiento)
        {
            bool resultado = CD_Movimiento.Instancia.CancelarMovimiento(idMovimiento);
            return Json(new { resultado });
        }

        public JsonResult BuscarCompras(DateTime? FechaInicio, DateTime? FechaFin, int draw = 1, int start = 0, int length = 10)
        {
            int pagina = (start / length) + 1;
            int totalRegistros;

            var lista = CD_Movimiento.Instancia.ObtenerMovimientos(
                FechaInicio,
                FechaFin,
                pagina,
                length,
                out totalRegistros);

            return Json(new
            {
                draw = draw,
                recordsTotal = totalRegistros,
                recordsFiltered = totalRegistros,
                data = lista
            }, JsonRequestBehavior.AllowGet);
        }
    }
}