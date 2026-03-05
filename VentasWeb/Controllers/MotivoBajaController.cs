using CapaDatos;
using CapaModelo;
using System;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("MotivoBaja", "*")]
    public class MotivoBajaController : Controller
    {
        public ActionResult Crear() => View();

        public JsonResult Obtener()
        {
            var lista = CD_MotivoBaja.Instancia.ObtenerMotivosBaja();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Guardar(MotivoBaja objeto)
        {
            if (objeto == null || string.IsNullOrWhiteSpace(objeto.Descripcion))
                return Json(new { resultado = false, mensaje = "La descripción es obligatoria." });

            objeto.Descripcion = objeto.Descripcion.Trim().ToUpper();

            try
            {
                bool ok = objeto.IdMotivoBaja == 0
                    ? CD_MotivoBaja.Instancia.RegistrarMotivoBaja(objeto)
                    : CD_MotivoBaja.Instancia.ModificarMotivoBaja(objeto);

                string msg = ok
                    ? "Motivo guardado correctamente."
                    : "No se pudo guardar. Es posible que ya exista un motivo con ese nombre.";

                return Json(new { resultado = ok, mensaje = msg });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        [HttpGet]
        public JsonResult Eliminar(int id = 0)
        {
            if (id <= 0)
                return Json(new { resultado = false, mensaje = "Id inválido." }, JsonRequestBehavior.AllowGet);

            bool ok = CD_MotivoBaja.Instancia.EliminarMotivoBaja(id);
            return Json(new
            {
                resultado = ok,
                mensaje = ok ? "Motivo eliminado." : "No se pudo eliminar. Puede estar en uso."
            }, JsonRequestBehavior.AllowGet);
        }
    }
}