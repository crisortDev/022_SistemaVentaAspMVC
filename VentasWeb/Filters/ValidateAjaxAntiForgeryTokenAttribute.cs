using System;
using System.Web.Helpers;
using System.Web.Mvc;

namespace VentasWeb.Filters
{
    /// <summary>
    /// Protección CSRF para todo el sistema.
    ///
    /// El sitio usa sesión por cookie (Session["Usuario"]) y casi todas las
    /// llamadas que modifican datos se hacen por AJAX ($.post) devolviendo JSON,
    /// no por formularios tradicionales. Por eso no alcanza con el atributo
    /// ValidateAntiForgeryToken de MVC (que solo lee el campo de formulario);
    /// acá se valida el token contra un header, y como respaldo contra el campo
    /// de formulario si algún formulario tradicional lo envía así (ej. Login).
    ///
    /// Se registra como filtro GLOBAL en FilterConfig.cs, así que aplica a
    /// TODAS las acciones POST/PUT/DELETE de todos los controladores sin tener
    /// que decorar cada una a mano. Requiere que la vista emita
    /// Html.AntiForgeryToken() y que el JS mande ese valor en el header
    /// "RequestVerificationToken" en cada request que no sea GET
    /// (ver _Layout.cshtml y Login/Index.cshtml).
    /// </summary>
    public class ValidateAjaxAntiForgeryTokenAttribute : FilterAttribute, IAuthorizationFilter
    {
        private const string HeaderName = "RequestVerificationToken";
        private const string FormFieldName = "__RequestVerificationToken";

        public void OnAuthorization(AuthorizationContext filterContext)
        {
            var request = filterContext.HttpContext.Request;
            var metodo = request.HttpMethod;

            // Solo se valida en verbos que modifican estado; los GET no tocan datos.
            bool esVerboSensible =
                string.Equals(metodo, "POST", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(metodo, "PUT", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(metodo, "DELETE", StringComparison.OrdinalIgnoreCase);

            if (!esVerboSensible)
                return;

            // Escape hatch puntual, a usar solo si aparece un caso legítimo que no puede mandar el token
            // (ej. un webhook externo). No usar para evitar corregir el JS.
            if (filterContext.ActionDescriptor.IsDefined(typeof(SkipAjaxAntiForgeryAttribute), true) ||
                filterContext.ActionDescriptor.ControllerDescriptor.IsDefined(typeof(SkipAjaxAntiForgeryAttribute), true))
            {
                return;
            }

            string cookieToken = null;
            var cookieName = AntiForgeryConfig.CookieName;
            var cookie = request.Cookies[cookieName];
            if (cookie != null) cookieToken = cookie.Value;

            // Preferimos el header (llamadas AJAX). Si no vino, probamos el campo de formulario
            // (por si algún <form> tradicional sigue posteando de forma clásica).
            string clienteToken = request.Headers[HeaderName];
            if (string.IsNullOrEmpty(clienteToken))
                clienteToken = request.Form[FormFieldName];

            try
            {
                AntiForgery.Validate(cookieToken, clienteToken);
            }
            catch (Exception)
            {
                filterContext.Result = new JsonResult
                {
                    Data = new
                    {
                        resultado = false,
                        success = false,
                        mensaje = "No se pudo validar la solicitud (token de seguridad ausente o inválido). Recargue la página e intente nuevamente."
                    },
                    JsonRequestBehavior = JsonRequestBehavior.AllowGet
                };
            }
        }
    }

    /// <summary>Marca una acción o controlador para omitir la validación CSRF global. Usar con criterio.</summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
    public class SkipAjaxAntiForgeryAttribute : Attribute
    {
    }
}
