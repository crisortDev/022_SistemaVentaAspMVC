using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace VentasWeb.Filters
{
    public class AuthorizeRolAttribute : AuthorizeAttribute
    {
        private readonly string _controlador;
        private readonly string _vista;

        // Mapeo de vistas personalizadas
        private static readonly Dictionary<string, string> mapeoVistas = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
{
    { "Producto|Obtener", "ConsultarPrecioVenta" },
    { "Rol|Obtener", "ObtenerRol" },
    { "Permisos|Crear", "Crear" },
    { "Usuario|Crear", "Usuarios" },
    { "Categoria|Crear", "Categorias" },
    { "Producto|Crear", "Productos" },
    { "Producto|ConsultarPrecioVenta", "Precios y Vigencia" },
    { "Cliente|Crear", "Clientes" },
    { "Proveedor|Crear", "Proveedores" },
    { "Producto|Asignar", "Asignar producto a Tienda" },
    { "Compra|Crear", "Registrar Compra" },
    { "Compra|Consultar", "Consultar Compra" },
    { "Tienda|Crear", "Tiendas" },
    { "Venta|Crear", "Registrar Venta" },
    { "Venta|Consultar", "Consultar Venta" },
    { "Reporte|Producto", "Productos por tienda" },
    { "Reporte|Ventas", "Ventas" },
    { "ConsultarCajaCompra|ConsultarCajaCompra", "Caja Compra" },
    { "ConsultarCajaVenta|ConsultarCajaVenta", "Caja Venta" },
    { "Usuario|CambioContraseña", "Cambio de Contraseña" } 
};


        public AuthorizeRolAttribute(string controlador, string vista)
        {
            _controlador = controlador;
            _vista = vista;
        }

        protected override bool AuthorizeCore(HttpContextBase httpContext)
        {
            if (httpContext.Session["Usuario"] == null)
                return false;

            Usuario usuario = (Usuario)httpContext.Session["Usuario"];
            Usuario usuarioDetalle = CapaDatos.CD_Usuario.Instancia.ObtenerDetalleUsuario(usuario.IdUsuario);

            string controladorValidar = _controlador;
            string vistaValidar = _vista;

            // Mapear vistas si existe en el diccionario
            string key = $"{controladorValidar}|{vistaValidar}";
            if (mapeoVistas.TryGetValue(key, out string vistaMapeada))
            {
                vistaValidar = vistaMapeada;
            }

            bool tienePermiso;

            if (vistaValidar == "*")
            {
                // Permitir cualquier submenú activo del controlador
                tienePermiso = usuarioDetalle.oListaMenu
                    .SelectMany(menu => menu.oSubMenu)
                    .Any(sm => sm.Controlador.Equals(controladorValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Activo);
            }
            else
            {
                // Validar acción específica dentro del submenú
                tienePermiso = usuarioDetalle.oListaMenu
                    .SelectMany(menu => menu.oSubMenu)
                    .Any(sm => sm.Controlador.Equals(controladorValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Nombre.Equals(vistaValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Activo);
            }
            return tienePermiso;
        }

        protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
        {
            if (filterContext.HttpContext.Request.IsAjaxRequest())
            {
                filterContext.Result = new JsonResult
                {
                    Data = new { resultado = false, mensaje = "Acceso denegado" },
                    JsonRequestBehavior = JsonRequestBehavior.AllowGet
                };
            }
            else
            {
                filterContext.Result = new RedirectResult("~/Home/AccesoDenegado");
            }
        }
    }
}
