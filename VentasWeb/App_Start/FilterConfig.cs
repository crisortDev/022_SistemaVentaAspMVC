using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;
namespace VentasWeb
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            // Manejo global de excepciones — debe ir primero para capturar todo
            filters.Add(new GlobalExceptionFilter());
            // Protección CSRF — valida token en toda acción POST/PUT/DELETE de todo el sitio
            filters.Add(new ValidateAjaxAntiForgeryTokenAttribute());
            filters.Add(new VerificarSession());
        }
    }
}
