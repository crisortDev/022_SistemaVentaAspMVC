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
            { "Producto|Obtener",                          "ConsultarPrecioVenta"       },
            { "Rol|Obtener",                               "ObtenerRol"                 },
            { "Permisos|Crear",                            "Crear"                      },
            { "Usuario|Crear",                             "Usuarios"                   },
            { "Categoria|Crear",                           "Categorias"                 },
            { "Producto|Crear",                            "Productos"                  },
            { "Producto|ConsultarPrecioVenta",             "Precios y Vigencia"         },
            { "Cliente|Crear",                             "Clientes"                   },
            { "Proveedor|Crear",                           "Proveedores"                },
            { "Producto|Asignar",                          "Asignar producto a Tienda"  },
            { "Compra|Crear",                              "Registrar Compra"           },
            { "Compra|Consultar",                          "Consultar Compra"           },
            { "Tienda|Crear",                              "Tiendas"                    },
            { "Venta|Crear",                               "Registrar Venta"            },
            { "Venta|Consultar",                           "Consultar Venta"            },
            { "Reporte|Producto",                          "Productos por tienda"       },
            { "Reporte|Ventas",                            "Ventas"                     },
            { "ConsultarCajaCompra|ConsultarCajaCompra",   "Caja Compra"                },
            { "ConsultarCajaVenta|ConsultarCajaVenta",     "Caja Venta"                 },
            { "Usuario|CambioContraseña",                  "Cambio de Contraseña"       }
        };

        public AuthorizeRolAttribute(string controlador, string vista)
        {
            _controlador = controlador;
            _vista = vista;
        }

        protected override bool AuthorizeCore(HttpContextBase httpContext)
        {
            // ── Sin sesión: denegar siempre ───────────────────────
            if (httpContext.Session["Usuario"] == null)
                return false;

            // ── SuperAdmin: acceso total sin validar menú ─────────
            if (httpContext.Session["EsSuperAdmin"] is bool esSuperAdmin && esSuperAdmin)
                return true;

            // ── Usuarios normales: validar por menú en sesión ─────
            // El menú ya fue cargado durante el login — sin llamada extra a BD
            Usuario usuario = (Usuario)httpContext.Session["Usuario"];
            var listaMenu = usuario.oListaMenu;

            if (listaMenu == null || !listaMenu.Any())
                return false;

            string controladorValidar = _controlador;
            string vistaValidar = _vista;

            // Mapear vista si existe en el diccionario
            string key = $"{controladorValidar}|{vistaValidar}";
            if (mapeoVistas.TryGetValue(key, out string vistaMapeada))
                vistaValidar = vistaMapeada;

            bool tienePermiso;

            if (vistaValidar == "*")
            {
                // Permitir si tiene cualquier submenú activo del controlador
                tienePermiso = listaMenu
                    .SelectMany(menu => menu.oSubMenu ?? Enumerable.Empty<SubMenu>())
                    .Any(sm => sm.Controlador.Equals(controladorValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Activo);
            }
            else
            {
                // Validar acción específica dentro del submenú
                tienePermiso = listaMenu
                    .SelectMany(menu => menu.oSubMenu ?? Enumerable.Empty<SubMenu>())
                    .Any(sm => sm.Controlador.Equals(controladorValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Nombre.Equals(vistaValidar, StringComparison.OrdinalIgnoreCase)
                               && sm.Activo);
            }

            return tienePermiso;
        }

        protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
        {
            // ── Auditoría: registrar intento de acceso denegado ───
            try
            {
                var session  = filterContext.HttpContext.Session;
                var request  = filterContext.HttpContext.Request;
                var usuario  = session["Usuario"] as CapaModelo.Usuario;
                string user  = usuario != null
                    ? $"{usuario.Correo} (IdUsuario={usuario.IdUsuario})"
                    : "Sin sesión";
                string url   = request.Url?.PathAndQuery ?? "desconocida";
                string ip    = request.UserHostAddress ?? "IP desconocida";
                string msg   = $"[ACCESO DENEGADO] {DateTime.Now:yyyy-MM-dd HH:mm:ss} | " +
                               $"Usuario: {user} | URL: {url} | IP: {ip} | " +
                               $"Controlador: {_controlador} | Vista: {_vista}";

                System.Diagnostics.Trace.TraceWarning(msg);
            }
            catch
            {
                // El log nunca debe interrumpir el flujo de la aplicación
            }

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