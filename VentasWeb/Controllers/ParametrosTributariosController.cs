using CapaDatos;
using System;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("ParametrosTributarios", "*")]
    public class ParametrosTributariosController : BaseController
    {
        // ── Index — vista principal con datos actuales ────────────────
        [AuthorizeRol("ParametrosTributarios", "Index")]
        public ActionResult Index()
        {
            var config = CD_ParametrosTributarios.Instancia.ObtenerConfiguracion();
            return View(config);
        }

        // ── JSON — obtener configuración actual ───────────────────────
        [HttpGet]
        [AuthorizeRol("ParametrosTributarios", "Index")]
        public JsonResult Obtener()
        {
            var config = CD_ParametrosTributarios.Instancia.ObtenerConfiguracion();
            return Json(new { data = config }, JsonRequestBehavior.AllowGet);
        }

        // ── JSON — guardar / actualizar ───────────────────────────────
        [HttpPost]
        [AuthorizeRol("ParametrosTributarios", "Index")]
        public JsonResult Guardar(
            string numeroTimbrado,
            string vencimientoTimbrado,
            string establecimiento,
            string puntoExpedicion,
            string razonSocial)
        {
            if (string.IsNullOrWhiteSpace(numeroTimbrado))
                return Json(new { resultado = false, mensaje = "El número de timbrado es obligatorio." });

            if (!DateTime.TryParseExact(vencimientoTimbrado, "dd/MM/yyyy",
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out DateTime venc))
            {
                return Json(new { resultado = false, mensaje = "Formato de fecha inválido. Use dd/mm/aaaa." });
            }

            var r = CD_ParametrosTributarios.Instancia.Actualizar(
                numeroTimbrado.Trim(), venc,
                (establecimiento ?? "001").Trim(),
                (puntoExpedicion ?? "001").Trim(),
                razonSocial ?? "");

            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }
    }
}
