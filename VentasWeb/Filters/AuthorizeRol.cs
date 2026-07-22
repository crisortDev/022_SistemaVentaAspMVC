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
        private readonly string[] _vistas;   // admite una o varias vistas (OR lógico)

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
            { "Compra|Consultar",                          "Consultar Compras"          },
            { "Compra|Recepcion",                          "Recepción de Compras"       },
            { "OrdenCompra|Crear",                         "Registrar Orden de Compra"  },
            { "OrdenCompra|Consultar",                     "Consultar Orden de Compra"  },
            { "OrdenCompra|Aprobaciones",                  "Aprobar Orden de Compra"    },
            { "OrdenCompra|Aprobar",                       "Aprobar Orden de Compra"    },
            { "OrdenCompra|Rechazar",                      "Aprobar Orden de Compra"    },
            { "OrdenCompra|Anular",                        "Anular Orden Compra"        },
            { "Compra|Revision",                           "Revisión de Compras"        },
            { "Compra|OrdenPago",                          "Órdenes de Pago"            },
            { "OrdenPago|Consultar",                       "Órdenes de Pago"            },
            { "OrdenPago|Aprobar",                         "Aprobar Orden de Pago"      },
            { "OrdenPago|CuentasPorPagar",                 "Cuentas por Pagar"          },
            { "Tienda|Crear",                              "Tiendas"                    },
            { "Venta|Crear",                               "Registrar Venta Directa"    },
            { "Venta|Consultar",                           "Consultar Ventas"           },
            { "Reporte|Producto",                          "Productos por tienda"       },
            { "Reporte|Ventas",                            "Ventas"                     },
            { "ConsultarCajaCompra|ConsultarCajaCompra",   "Caja Compra"                },
            { "ConsultarCajaVenta|ConsultarCajaVenta",     "Caja Venta"                 },
            { "Usuario|CambioContraseña",                  "Cambio de Contraseña"       },
            { "NotaCredito|Index",                         "Registrar Nota de Crédito"  },
            { "ReporteGerencia|Index",                     "Reporte Gerencial de Compras" },
            // ── Módulo Ventas v2 ──────────────────────────────────────
            { "Venta|Facturar",                            "Registrar Venta Directa"    },
            { "Venta|Guardar",                             "Registrar Venta Directa"    },
            { "Venta|Anular",                              "Anular Venta"               },
            { "OrdenVenta|Crear",                          "Registrar Pre-venta"        },
            { "OrdenVenta|Consultar",                      "Consultar Pre-ventas"       },
            { "OrdenVenta|Guardar",                        "Registrar Pre-venta"        },
            { "OrdenVenta|Anular",                         "Anular Pre-venta"           },
            { "ComprobanteCobro|Index",                    "Comprobantes de Cobro"      },
            { "ComprobanteCobro|Obtener",                  "Comprobantes de Cobro"      },
            { "NotaCreditoVenta|Index",                    "Nota de Crédito Venta"      },
            // ── Módulo Garantías ──────────────────────────────────────
            { "Garantia|Index",                            "Garantías"                  },
            { "Garantia|ObtenerVentas",                    "Garantías"                  },
            { "Garantia|ObtenerDetalle",                   "Garantías"                  },
            { "Garantia|ProcesarGarantia",                 "Garantías"                  },
            { "NotaCreditoVenta|Registrar",                "Nota de Crédito Venta"      },
            { "NotaCreditoVenta|AprobarRechazar",          "Nota de Crédito Venta"      },
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
            { "Inventario|AnularInventario",               "Inventarios"                },
        };

        /// <summary>
        /// Constructor que acepta una o varias vistas (OR lógico).
        /// Ejemplo: [AuthorizeRol("Compra", "Recepcion", "Revision")]
        /// El usuario pasa si tiene permiso a CUALQUIERA de las vistas indicadas.
        /// </summary>
        public AuthorizeRolAttribute(string controlador, params string[] vistas)
        {
            _controlador = controlador;
            _vistas      = vistas ?? new[] { "*" };
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
            Usuario usuario = (Usuario)httpContext.Session["Usuario"];
            var listaMenu = usuario.oListaMenu;

            if (listaMenu == null || !listaMenu.Any())
                return false;

            // Aplanar todos los submenús del usuario de una sola vez
            var todosLosSubmenus = listaMenu
                .SelectMany(menu => menu.oSubMenu ?? Enumerable.Empty<SubMenu>())
                .Where(sm => !string.IsNullOrEmpty(sm.Controlador))
                .ToList();

            // OR lógico: el usuario pasa si tiene permiso a CUALQUIERA de las vistas
            foreach (var vistaParam in _vistas)
            {
                string vistaValidar = vistaParam;

                // Mapear vista si existe en el diccionario
                string key = $"{_controlador}|{vistaValidar}";
                if (mapeoVistas.TryGetValue(key, out string vistaMapeada))
                    vistaValidar = vistaMapeada;

                bool tieneEsta;

                if (vistaValidar == "*")
                {
                    // Wildcard: basta con que tenga CUALQUIER submenú del controlador
                    tieneEsta = todosLosSubmenus
                        .Any(sm => sm.Controlador.Equals(_controlador, StringComparison.OrdinalIgnoreCase));
                }
                else
                {
                    tieneEsta = todosLosSubmenus
                        .Any(sm => sm.Controlador.Equals(_controlador, StringComparison.OrdinalIgnoreCase)
                                   && sm.Nombre.Equals(vistaValidar, StringComparison.OrdinalIgnoreCase)
                                   && sm.Activo);
                }

                if (tieneEsta) return true;
            }

            return false;
        }

        protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
        {
            var session = filterContext.HttpContext.Session;
            var request = filterContext.HttpContext.Request;
            bool sinSesion = session["Usuario"] == null;

            // ── Auditoría: registrar intento de acceso denegado ───
            try
            {
                var usuario = session["Usuario"] as CapaModelo.Usuario;
                string user = usuario != null
                    ? $"{usuario.Correo} (IdUsuario={usuario.IdUsuario})"
                    : "Sin sesión";
                string url  = request.Url?.PathAndQuery ?? "desconocida";
                string ip   = request.UserHostAddress ?? "IP desconocida";
                string msg  = $"[ACCESO DENEGADO] {DateTime.Now:yyyy-MM-dd HH:mm:ss} | " +
                              $"Usuario: {user} | URL: {url} | IP: {ip} | " +
                              $"Controlador: {_controlador} | Vista(s): {string.Join("|", _vistas)}";

                System.Diagnostics.Trace.TraceWarning(msg);
            }
            catch
            {
                // El log nunca debe interrumpir el flujo de la aplicación
            }

            if (request.IsAjaxRequest())
            {
                string mensaje = sinSesion ? "Sesión expirada. Por favor, iniciá sesión nuevamente." : "Acceso denegado";
                filterContext.Result = new JsonResult
                {
                    Data = new { resultado = false, mensaje = mensaje },
                    JsonRequestBehavior = JsonRequestBehavior.AllowGet
                };
            }
            else if (sinSesion)
            {
                // Sesión expirada o no autenticado → redirigir al login
                filterContext.Result = new RedirectResult("~/Login/Index");
            }
            else
            {
                // Autenticado pero sin permisos → AccesoDenegado
                filterContext.Result = new RedirectResult("~/Home/AccesoDenegado");
            }
        }
    }
}