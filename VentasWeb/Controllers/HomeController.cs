using CapaDatos;
using CapaModelo;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class HomeController : BaseController
    {
        public ActionResult Index()
        {
            Usuario usuario = (Usuario)Session["Usuario"];

            if (usuario == null)
                return RedirectToAction("Index", "Login");

            ViewBag.NombreUsuario = usuario.Nombres + " " + usuario.Apellidos;
            ViewBag.RolUsuario    = usuario.oRol?.Descripcion ?? "";
            ViewBag.EsSuperAdmin  = EsSuperAdmin;

            bool esSuperAdmin = usuario.IdRol == 14;
            if (esSuperAdmin)
                ViewBag.NombreSucursal = "Todas las sucursales";
            else if (usuario.oTienda != null && !string.IsNullOrEmpty(usuario.oTienda.Nombre))
                ViewBag.NombreSucursal = usuario.oTienda.Nombre;
            else
                ViewBag.NombreSucursal = "Sin sucursal asignada";

            // Construir set de controladores a los que el usuario tiene acceso
            // basado en su oListaMenu (ya filtrado por permisos en BD)
            var controladores = new System.Collections.Generic.HashSet<string>(
                System.StringComparer.OrdinalIgnoreCase);

            if (usuario.oListaMenu != null)
            {
                foreach (var menu in usuario.oListaMenu)
                {
                    if (menu.oSubMenu == null) continue;
                    foreach (var sub in menu.oSubMenu)
                    {
                        if (sub.Activo && !string.IsNullOrEmpty(sub.Controlador))
                            controladores.Add(sub.Controlador.Trim());
                    }
                }
            }

            ViewBag.Controladores = controladores;

            return View();
        }

        public ActionResult Salir()
        {
            var usuario = Session["Usuario"] as Usuario;
            if (usuario != null)
                CD_Auditoria.Instancia.Registrar(usuario.IdUsuario, CD_Auditoria.LOGOUT,
                    usuario.Correo, Request?.UserHostAddress);

            Session["Usuario"] = null;
            Session["EsSuperAdmin"] = null;
            Session["TiendaActiva"] = null;
            return RedirectToAction("Index", "Login");
        }
        public ActionResult AccesoDenegado()
        {
            return View();
        }

        /// <summary>
        /// Página genérica de error del servidor.
        /// Invocada por GlobalExceptionFilter para peticiones no-AJAX.
        /// No requiere autenticación para que funcione incluso si la sesión expiró.
        /// </summary>
        public ActionResult Error()
        {
            return View();
        }

        public ActionResult ObtenerMenu()
        {
            if (Session["Usuario"] != null)
            {
                var usuario = (Usuario)Session["Usuario"];
                return PartialView("_Menu", usuario.oListaMenu);
            }
            return new EmptyResult();
        }

        public ActionResult RecargarMenu()
        {
            // Usar la versión que no requiere HtmlHelper
            return Content(Helpers.Helpers.ActionLinkAllowString());
        }
    }
}