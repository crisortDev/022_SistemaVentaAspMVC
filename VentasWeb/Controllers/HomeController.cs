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
            ViewBag.RolUsuario = usuario.oRol?.Descripcion ?? "";
            ViewBag.EsSuperAdmin = EsSuperAdmin;

            return View();
        }

        public ActionResult Salir()
        {
            Session["Usuario"] = null;
            Session["EsSuperAdmin"] = null;
            Session["TiendaActiva"] = null;
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