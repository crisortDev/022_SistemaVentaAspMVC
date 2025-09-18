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
    [AuthorizeRol("Rol", "*")] // '*' significa todas las vistas/acciones del controlador
    public class RolController : Controller
    {
        // GET: Rol
        public ActionResult Crear()
        {
            return View();
        }

        [HttpGet]
        public JsonResult Obtener()
        {
            List<Rol> olista = CD_Rol.Instancia.ObtenerRol();
           
            return Json(new { data = olista }, JsonRequestBehavior.AllowGet);
        }


        [HttpPost]
        public JsonResult Guardar(Rol objeto)
        {
            // Inicializamos directamente con el resultado de la operación
            bool respuesta = objeto.IdRol == 0
                ? CD_Rol.Instancia.RegistrarRol(objeto)
                : CD_Rol.Instancia.ModificarRol(objeto);

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }



        [HttpPost]
        public JsonResult Desactivar(int id)
        {
            var resultado = CD_Rol.Instancia.DesactivarRol(id); // retorna (bool resultado, string mensaje)
            return Json(new { resultado = resultado.resultado, mensaje = resultado.mensaje });
        }


    }
}