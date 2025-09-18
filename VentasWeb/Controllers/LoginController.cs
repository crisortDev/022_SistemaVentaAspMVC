using CapaDatos;
using CapaModelo;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Utilidades;

namespace VentasWeb.Controllers
{
    public class LoginController : Controller
    {
        // GET: Login
        public ActionResult Index()
        {
            return View();
        }

        [HttpPost]
        public ActionResult Index(string correo, string clave)
        {
            var ejemplo = Encriptar.GetSHA256(clave);

            Usuario ousuario = CD_Usuario.Instancia.ObtenerUsuarios()
                .Where(u => u.Correo == correo && u.Clave == Encriptar.GetSHA256(clave))
                .FirstOrDefault();

            if (ousuario == null)
            {
                ViewBag.Error = "Usuario o contraseña no correcta";
                return View();
            }

            // Traer los detalles completos, incluyendo oListaMenu
            Usuario usuarioDetalle = CD_Usuario.Instancia.ObtenerDetalleUsuario(ousuario.IdUsuario);

            // Guardar el usuario completo en sesión
            Session["Usuario"] = usuarioDetalle;

            return RedirectToAction("Index", "Home");
        }
    }
}