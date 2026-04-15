using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Tienda", "*")]
    public class TiendaController : BaseController
    {
        // GET: Tienda
        public ActionResult Crear()
        {
            return View();
        }

        [HttpGet]
        public JsonResult Obtener()
        {
            try
            {
                List<Tienda> lista = CD_Tienda.Instancia.ObtenerTiendas();
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError(
                    $"[TiendaController.Obtener] {DateTime.Now:yyyy-MM-dd HH:mm:ss} | Error: {ex.Message}");
                return Json(new { data = new List<Tienda>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult Guardar(Tienda objeto)
        {
            // Solo SuperAdmin puede crear o modificar tiendas
            if (!EsSuperAdmin)
                return Json(new { resultado = false, mensaje = "Solo el administrador global puede gestionar tiendas." });

            bool respuesta = false;

            if (objeto.IdTienda == 0)
            {
                respuesta = CD_Tienda.Instancia.RegistrarTienda(objeto);
            }
            else
            {
                respuesta = CD_Tienda.Instancia.ModificarTienda(objeto);
            }

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        public JsonResult ObtenerTiendasActivas()
        {
            List<Tienda> lista = CD_Tienda.Instancia.ObtenerTiendas()
                                  .Where(t => t.Activo).ToList();
            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Eliminar(int id = 0)
        {
            // Solo SuperAdmin puede eliminar tiendas
            if (!EsSuperAdmin)
                return Json(new { resultado = false, mensaje = "Solo el administrador global puede eliminar tiendas." }, JsonRequestBehavior.AllowGet);

            bool respuesta = CD_Tienda.Instancia.EliminarTienda(id);
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }
    }
}