using CapaModelo;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Mvc;

namespace VentasWeb.Helpers
{
    public static class Helpers
    {
        /// <summary>
        /// Genera el HTML del menú de navegación según los permisos del usuario.
        /// Usa directamente la sesión — sin llamadas adicionales a la BD.
        /// </summary>
        public static MvcHtmlString ActionLinkAllow(this HtmlHelper helper)
        {
            return new MvcHtmlString(ConstruirMenu());
        }

        /// <summary>
        /// Versión string del menú de navegación (usada desde Razor sin HtmlHelper).
        /// </summary>
        public static string ActionLinkAllowString()
        {
            return ConstruirMenu();
        }

        // ── Lógica central compartida ─────────────────────────────
        private static string ConstruirMenu()
        {
            var session = HttpContext.Current.Session;

            if (session["Usuario"] == null)
                return string.Empty;

            // El menú ya fue cargado en sesión durante el login — sin llamada extra a BD
            Usuario oUsuario = (Usuario)session["Usuario"];

            if (oUsuario.oListaMenu == null || !oUsuario.oListaMenu.Any())
                return string.Empty;

            StringBuilder sb = new StringBuilder();

            foreach (Menu item in oUsuario.oListaMenu)
            {
                if (item.oSubMenu == null || !item.oSubMenu.Any()) continue;

                // Filtrar submenús activos
                var subMenusActivos = item.oSubMenu.Where(s => s.Activo).ToList();
                if (!subMenusActivos.Any()) continue;

                sb.AppendLine($@"
<li class='nav-item dropdown'>
    <a class='nav-link dropdown-toggle' href='#' data-toggle='dropdown'>
        <i class='{item.Icono}'></i> {item.Nombre}
    </a>
    <div class='dropdown-menu drop-menu'>");

                foreach (SubMenu subitem in subMenusActivos)
                {
                    sb.AppendLine($@"        <a class='dropdown-item' name='{subitem.Nombre}' href='/{subitem.Controlador}/{subitem.Vista}'>
            <i class='{subitem.Icono}'></i> {subitem.Nombre}
        </a>");
                }

                sb.AppendLine("    </div>");
                sb.AppendLine("</li>");
            }

            return sb.ToString();
        }
    }
}