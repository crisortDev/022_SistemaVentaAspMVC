using CapaDatos;
using CapaModelo;
using System;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    public class GarantiaController : BaseController
    {
        // ══════════════════════════════════════════════════════════════════════
        //  INDEX — pantalla principal de garantías
        // ══════════════════════════════════════════════════════════════════════
        [AuthorizeRol("Garantia", "Index")]
        public ActionResult Index()
        {
            ViewBag.MotivosNC = CD_MotivoNotaCredito.Instancia.Obtener();
            return View();
        }

        // ══════════════════════════════════════════════════════════════════════
        //  JSON: buscar ventas por número de factura o cliente
        // ══════════════════════════════════════════════════════════════════════
        [HttpGet]
        [AuthorizeRol("Garantia", "Index")]
        public JsonResult ObtenerVentas(string numerofactura, string documento = "")
        {
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

            var lista = CD_Garantia.Instancia.ObtenerVentasParaGarantia(
                numerofactura ?? "", 0, idTienda, documento ?? "");

            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ══════════════════════════════════════════════════════════════════════
        //  JSON: obtener ítems de una venta
        // ══════════════════════════════════════════════════════════════════════
        [HttpGet]
        [AuthorizeRol("Garantia", "Index")]
        public JsonResult ObtenerDetalle(int idventa)
        {
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

            var items = CD_Garantia.Instancia.ObtenerDetalleParaGarantia(idventa, idTienda);
            return Json(new { data = items }, JsonRequestBehavior.AllowGet);
        }

        // ══════════════════════════════════════════════════════════════════════
        //  JSON: procesar garantía (reemplazo o NC + cuotas)
        // ══════════════════════════════════════════════════════════════════════
        [HttpPost]
        [AuthorizeRol("Garantia", "Index")]
        public JsonResult ProcesarGarantia(
            int idventa, int iddetalleventa,
            int idmotivonc, bool haystock, int cantidadgarantia = 0)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var (ok, msg, montoNC, saldo) = CD_Garantia.Instancia.ProcesarGarantia(
                idventa, iddetalleventa, idmotivonc, haystock, UsuarioActual.IdUsuario, cantidadgarantia);

            return Json(new
            {
                resultado      = ok,
                mensaje        = msg,
                montoNC        = montoNC,
                saldoGenerado  = saldo
            });
        }
    }
}
