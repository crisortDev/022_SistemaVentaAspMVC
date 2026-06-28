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
            filters.Add(new VerificarSession());
        }
    }
}
