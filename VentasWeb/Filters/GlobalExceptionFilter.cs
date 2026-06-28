using System;
using System.Web.Mvc;

namespace VentasWeb.Filters
{
    /// <summary>
    /// Filtro global de excepciones no manejadas.
    /// - Peticiones AJAX  → JSON { resultado: false, mensaje: "..." }
    /// - Peticiones normales → redirige a /Home/Error con un mensaje genérico
    /// Registrar en FilterConfig ANTES de HandleErrorAttribute.
    /// </summary>
    public class GlobalExceptionFilter : IExceptionFilter
    {
        public void OnException(ExceptionContext filterContext)
        {
            if (filterContext == null || filterContext.ExceptionHandled)
                return;

            var ex      = filterContext.Exception;
            var request = filterContext.HttpContext.Request;

            // ── Log del error ──────────────────────────────────────────
            try
            {
                var usuario = filterContext.HttpContext.Session?["Usuario"] as CapaModelo.Usuario;
                string user = usuario != null
                    ? $"{usuario.Correo} (IdUsuario={usuario.IdUsuario})"
                    : "Sin sesión";

                string url = request.Url?.PathAndQuery ?? "desconocida";
                string ip  = request.UserHostAddress   ?? "IP desconocida";

                string msg = $"[EXCEPCION GLOBAL] {DateTime.Now:yyyy-MM-dd HH:mm:ss} | " +
                             $"Usuario: {user} | URL: {url} | IP: {ip} | " +
                             $"Tipo: {ex.GetType().Name} | Mensaje: {ex.Message}";

                System.Diagnostics.Trace.TraceError(msg);
                System.Diagnostics.Trace.TraceError(ex.StackTrace ?? "Sin stack trace");
            }
            catch
            {
                // El log nunca debe interrumpir el flujo
            }

            // ── Respuesta según tipo de petición ───────────────────────
            if (request.IsAjaxRequest())
            {
                // Para AJAX: JSON estándar con resultado false
                filterContext.Result = new JsonResult
                {
                    Data = new
                    {
                        resultado = false,
                        mensaje   = "Ocurrió un error inesperado en el servidor. Intentá de nuevo o contactá al administrador."
                    },
                    JsonRequestBehavior = JsonRequestBehavior.AllowGet
                };
                filterContext.HttpContext.Response.StatusCode = 200; // evitar que jQuery rechace el JSON por el 500
            }
            else
            {
                // Para peticiones normales: redirigir a la página de error
                filterContext.Result = new RedirectResult("~/Home/Error");
            }

            filterContext.ExceptionHandled = true;
        }
    }
}
