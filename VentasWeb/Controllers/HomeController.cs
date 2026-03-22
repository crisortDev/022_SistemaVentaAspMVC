using CapaModelo;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class HomeController : Controller
    {
        private static Usuario SesionUsuario;
        public ActionResult Index()
        {
            // Línea 20 probablemente es algo como esto:
            Usuario usuario = (Usuario)Session["Usuario"]; // ← null si no hay sesión

            if (usuario == null)
                return RedirectToAction("Index", "Login");

            ViewBag.NombreUsuario = usuario.Nombres + " " + usuario.Apellidos;
            ViewBag.RolUsuario = usuario.oRol?.Descripcion ?? "";

            return View();
        }

        public ActionResult Salir()
        {
            Session["Usuario"] = null;
            return RedirectToAction("Index", "Login");
        }
        public ActionResult AccesoDenegado()
        {
            // Si quieres mostrar el mismo layout y navbar que Index
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