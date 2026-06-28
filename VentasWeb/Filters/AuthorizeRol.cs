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
            { "OrdenCompra|Crear",                         "Registrar Orden Compra"     },
            { "OrdenCompra|Consultar",                     "Consultar Orden Compra"     },
            { "OrdenCompra|Aprobaciones",                  "Aprobar Orden Compra"       },
            { "OrdenCompra|Aprobar",                       "Aprobar Orden Compra"       },
            { "OrdenCompra|Rechazar",                      "Aprobar Orden Compra"       },
            { "OrdenCompra|Anular",                        "Anular Orden Compra"        },
            { "Compra|Revision",                           "Revisión de Compras"        },
            { "Compra|OrdenPago",                          "Órdenes de Pago"            },
            { "Tienda|Crear",                              "Tiendas"                    },
            { "Venta|Crear",                               "Registrar Venta Directa"    },
            { "Venta|Consultar",                           "Consultar Ventas"           },
            { "Reporte|Producto",                          "Productos por tienda"       },
            { "Reporte|Ventas",                            "Ventas"                     },
            { "ConsultarCajaCompra|ConsultarCajaCompra",   "Caja Compra"                },
            { "ConsultarCajaVenta|ConsultarCajaVenta",     "Caja Venta"                 },
            { "Usuario|CambioContraseña",                  "Cambio de Contraseña"       },
            { "NotaCredito|Index",                         "Registrar NC"               },
            { "ReporteGerencia|Index",                     "Reporte Gerencia Compras"   },
            // ── Módulo Ventas v2 ──────────────────────────────────────
            { "Venta|Facturar",                            "Registrar Venta Directa"    },
            { "Venta|Guardar",                             "Registrar Venta Directa"    },
            { "Venta|Anular",                              "Consultar Ventas"           },
            { "OrdenVenta|Crear",                          "Registrar Pre-venta"        },
            { "OrdenVenta|Consultar",                      "Consultar Pre-ventas"       },
            { "OrdenVenta|Guardar",                        "Registrar Pre-venta"        },
            { "OrdenVenta|Anular",                         "Consultar Pre-ventas"       },
            { "ComprobanteCobro|Index",                    "Comprobantes de Cobro"      },
            { "ComprobanteCobro|Obtener",                  "Comprobantes de Cobro"      },
            { "NotaCreditoVenta|Index",                    "Notas de Crédito Venta"     },
            { "NotaCreditoVenta|Registrar",                "Notas de Crédito Venta"     },
            { "NotaCreditoVenta|AprobarRechazar",          "Notas de Crédito Venta"     },
            // ── Módulo Caja de Ventas ─────────────────────────────
            { "CajaVenta|Index",                           "Caja de Ventas"             },
            { "CajaVenta|Abrir",                           "Caja de Ventas"             },
            { "CajaVenta|Cerrar",                          "Caja de Ventas"             },
            { "CajaVenta|ComprobanteApertura",             "Caja de Ventas"             },
            { "CajaVenta|Arqueo",                          "Caja de Ventas"             },
            { "CajaVenta|Reporte",                         "Caja de Ventas"             },
            { "CajaVenta|ObtenerOperaciones",              "Caja de Ventas"             },
            { "CajaVenta|Historial",                       "Caja de Ventas"             },
            // ── Gestión de Cajas (PuntoCaja) ─────────────────────
            { "PuntoCaja|Index",                           "Gestión de Cajas"           },
            { "PuntoCaja|Guardar",                         "Gestión de Cajas"           },
            { "PuntoCaja|Obtener",                         "Gestión de Cajas"           },
            { "PuntoCaja|Eliminar",                        "Gestión de Cajas"           },
            // ── Parámetros Tributarios ────────────────────────────
            { "ParametrosTributarios|Index",               "Parámetros Tributarios"     },
            { "ParametrosTributarios|Guardar",             "Parámetros Tributarios"     },
            { "ParametrosTributarios|Obtener",             "Parámetros Tributarios"     },
            // ── Inventario: Aprobación de bajas ───────────────────
            { "Inventario|AprobarBajas",                   "Aprobar Bajas"              },
            { "Inventario|ObtenerBajas",                   "Aprobar Bajas"              },
            { "Inventario|AprobarBaja",                    "Aprobar Bajas"              },
            { "Inventario|RechazarBaja",                   "Aprobar Bajas"              },
            // ── Inventario: Toma de inventario (operador) ─────────
            { "Inventario|TomaInventario",                 "Toma de Inventario"         },
            { "Inventario|RegistrarInventario",            "Toma de Inventario"         },
            { "Inventario|IniciarConteo",                  "Toma de Inventario"         },
            { "Inventario|FinalizarConteo",                "Toma de Inventario"         },
            { "Inventario|ObtenerInventariosOperador",     "Toma de Inventario"         },
            { "Inventario|ObtenerProductosParaConteo",     "Toma de Inventario"         },
            // ── Inventario: gestión supervisor ────────────────────
            { "Inventario|Inventarios",                    "Inventarios"                },
            { "Inventario|CrearInventario",                "Inventarios"                },
            { "Inventario|AsignarOperadorInventario",      "Inventarios"                },
            { "Inventario|ObtenerInventarios",             "Inventarios"                },
            { "Inventario|ObtenerDetalleInventario",       "Inventarios"                },
            { "Inventario|AprobarInventario",              "Inventarios"                },
            { "Inventario|RechazarInventario",             "Inventarios"                },
            { "Inventario|AnularInventario",               "Inventarios"                }
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