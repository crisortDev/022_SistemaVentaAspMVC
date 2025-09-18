using CapaDatos;
using CapaModelo;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Mvc;

namespace VentasWeb.Helpers
{
    public static class Helpers
    {
        public static MvcHtmlString ActionLinkAllow(this HtmlHelper helper)
        {
            StringBuilder sb = new StringBuilder();

            if (HttpContext.Current.Session["Usuario"] != null)
            {
                Usuario oUsuario = (Usuario)HttpContext.Current.Session["Usuario"];
                Usuario rptUsuario = CD_Usuario.Instancia.ObtenerDetalleUsuario(oUsuario.IdUsuario);

                if (rptUsuario?.oListaMenu != null)
                {
                    foreach (Menu item in rptUsuario.oListaMenu)
                    {
                        if (item.oSubMenu == null || !item.oSubMenu.Any()) continue;

                        sb.AppendLine($@"
<li class='nav-item dropdown'>
    <a class='nav-link dropdown-toggle' href='#' data-toggle='dropdown'>
        <i class='{item.Icono}'></i> {item.Nombre}
    </a>
    <div class='dropdown-menu drop-menu'>
");

                        foreach (SubMenu subitem in item.oSubMenu.Where(s => s.Activo))
                        {
                            sb.AppendLine($@"<a class='dropdown-item' name='{subitem.Nombre}' href='/{subitem.Controlador}/{subitem.Vista}'>
    <i class='{subitem.Icono}'></i> {subitem.Nombre}
</a>");
                        }

                        sb.AppendLine("</div></li>");
                    }
                }
            }

            return new MvcHtmlString(sb.ToString());
        }

        public static string ActionLinkAllowString()
        {
            StringBuilder sb = new StringBuilder();

            if (HttpContext.Current.Session["Usuario"] != null)
            {
                Usuario oUsuario = (Usuario)HttpContext.Current.Session["Usuario"];
                Usuario rptUsuario = CD_Usuario.Instancia.ObtenerDetalleUsuario(oUsuario.IdUsuario);

                if (rptUsuario?.oListaMenu != null)
                {
                    foreach (Menu item in rptUsuario.oListaMenu)
                    {
                        if (item.oSubMenu == null || !item.oSubMenu.Any()) continue;

                        sb.AppendLine($@"
<li class='nav-item dropdown'>
    <a class='nav-link dropdown-toggle' href='#' data-toggle='dropdown'>
        <i class='{item.Icono}'></i> {item.Nombre}
    </a>
    <div class='dropdown-menu drop-menu'>
");

                        foreach (SubMenu subitem in item.oSubMenu.Where(s => s.Activo))
                        {
                            sb.AppendLine($@"<a class='dropdown-item' name='{subitem.Nombre}' href='/{subitem.Controlador}/{subitem.Vista}'>
    <i class='{subitem.Icono}'></i> {subitem.Nombre}
</a>");
                        }

                        sb.AppendLine("</div></li>");
                    }
                }
            }

            return sb.ToString();
        }
    }
}
