using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Xml.Linq;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Permisos", "*")] // '*' significa todas las vistas/acciones del controlador
    public class PermisosController : Controller
    {
        // GET: Permisos
        public ActionResult Crear()
        {
            if (Session["Usuario"] == null)
                return RedirectToAction("Index", "Login"); // o donde manejes login

            var usuario = (Usuario)Session["Usuario"];

            // Asegurarse que oRol nunca sea null
            if (usuario.oRol == null)
                usuario.oRol = new Rol() { IdRol = 0, Descripcion = "" };

            return View(usuario);
        }


        [HttpGet]
        public JsonResult Obtener(int id)
        {
            List<Permisos> olista = CD_Permisos.Instancia.ObtenerPermisos(id);

            return Json(olista, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Guardar(string xml)
        {
            if (Session["Usuario"] == null)
                return Json(new { resultado = false, mensaje = "Usuario no autenticado" }, JsonRequestBehavior.AllowGet);

            var usuario = (Usuario)Session["Usuario"];
            XDocument xmlDoc = XDocument.Parse(xml);

            // Lista de permisos críticos que nunca se pueden desactivar
            List<int> permisosCriticos = new List<int> { 1, 2, 3 };

            // Si el usuario es admin
            if (usuario.oRol.Descripcion == "ADMINISTRADOR")
            {
                // Forzar los permisos críticos a activo
                foreach (int id in permisosCriticos)
                {
                    var permiso = xmlDoc.Descendants("PERMISO")
                                        .FirstOrDefault(p => (int)p.Element("IdPermisos") == id);
                    if (permiso != null)
                        permiso.Element("Activo").Value = "1"; // Siempre activo
                }
            }
            else
            {
                // Usuario no admin no puede modificar permisos de admin (criticos)
                bool intentaModificarAdmin = xmlDoc.Descendants("PERMISO")
                                                   .Any(p => permisosCriticos.Contains((int)p.Element("IdPermisos")));
                if (intentaModificarAdmin)
                {
                    return Json(new { resultado = false, mensaje = "No tiene permisos para modificar este rol" },
                                JsonRequestBehavior.AllowGet);
                }
            }

            xml = xmlDoc.ToString();
            bool Respuesta = CD_Permisos.Instancia.ActualizarPermisos(xml);

            if (Respuesta)
            {
                // 🔄 Actualiza la sesión con los menús actualizados
                usuario.oListaMenu = CD_Usuario.Instancia.ObtenerDetalleUsuario(usuario.IdUsuario).oListaMenu;
                Session["Usuario"] = usuario;
            }

            return Json(new { resultado = Respuesta }, JsonRequestBehavior.AllowGet);
        }


    }
}