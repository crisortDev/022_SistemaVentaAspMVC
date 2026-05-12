using CapaDatos;
using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Producto", "*")]
    public class ProductoController : BaseController
    {
        private readonly CD_Producto _productoService = CD_Producto.Instancia;
        private readonly CD_ProductoTienda _productoTiendaService = CD_ProductoTienda.Instancia;

        private string UsuarioActual
        {
            get
            {
                var usuario = Session["Usuario"] as Usuario;
                if (usuario == null) return "SISTEMA";
                return $"{usuario.Nombres} {usuario.Apellidos}".Trim();
            }
        }

        public ActionResult Crear() => View();

        // DESACTIVADO: La asignación de productos a tienda se realiza desde "Registrar Orden de Compra"
        // public ActionResult Asignar() => View();

        [HttpGet]
        public JsonResult Obtener()
        {
            try
            {
                var lista = _productoService.ObtenerProducto();
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpGet]
        public JsonResult ObtenerPorTienda(int IdTienda)
        {
            try
            {
                // ── Seguridad: si no es SuperAdmin, forzar su propia tienda ──
                // Evita que un usuario normal pase IdTienda=0 y obtenga
                // productos de todas las sucursales.
                if (!EsSuperAdmin)
                    IdTienda = TiendaActiva;

                var productos = _productoService.ObtenerProducto()
                    ?.Where(x => x.Activo == true)
                    .ToList() ?? new List<Producto>();

                if (IdTienda != 0)
                {
                    var productosTienda = _productoTiendaService.ObtenerProductoTienda()
                        ?.Where(x => x.oTienda != null && x.oTienda.IdTienda == IdTienda)
                        .ToList() ?? new List<ProductoTienda>();

                    if (productosTienda.Any())
                    {
                        productos = (from p in productos
                                     join pt in productosTienda on p.IdProducto equals pt.oProducto.IdProducto
                                     select p).ToList();
                    }
                    else
                    {
                        productos = new List<Producto>();
                    }
                }

                return Json(new { data = productos }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult Guardar(Producto objeto)
        {
            try
            {
                bool respuesta = objeto.IdProducto == 0
                    ? _productoService.RegistrarProducto(objeto)
                    : _productoService.ModificarProducto(objeto);

                return Json(new
                {
                    resultado = respuesta,
                    mensaje = respuesta ? "Operación exitosa" : "Error al guardar"
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        // ── Borrado lógico ────────────────────────────────────────
        [HttpPost]
        public JsonResult CambiarEstado(int id, bool activo)
        {
            if (id <= 0)
                return Json(new { resultado = false, mensaje = "ID inválido." });

            try
            {
                bool respuesta = CD_Producto.Instancia.CambiarEstadoProducto(id, activo);
                string mensaje = activo ? "Producto activado correctamente." : "Producto desactivado correctamente.";
                return Json(new { resultado = respuesta, mensaje = mensaje });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        [HttpPost]
        public JsonResult RegistrarProductoTienda(ProductoTienda objeto)
        {
            try
            {
                if (!TienePermiso(objeto.oTienda?.IdTienda ?? 0))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para asignar productos en esta sucursal." });

                if (objeto.StockMinimo < 0 || objeto.StockMaximo < 0)
                    return Json(new { resultado = false, mensaje = "Los stocks no pueden ser negativos." });

                if (objeto.StockMaximo <= objeto.StockMinimo)
                    return Json(new { resultado = false, mensaje = "Stock máximo debe ser mayor que stock mínimo." });

                bool respuesta = _productoTiendaService.RegistrarProductoTienda(objeto);
                return Json(new { resultado = respuesta });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        [HttpPut]
        public JsonResult ModificarProductoTienda(ProductoTienda objeto)
        {
            try
            {
                bool respuesta = _productoTiendaService.ModificarProductoTienda(objeto);
                return Json(new { resultado = respuesta });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        [HttpPost]
        public JsonResult EliminarProductoTienda(int id)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "ID inválido" });

                bool resultado = CD_ProductoTienda.Instancia.EliminarProductoTienda(id);
                return Json(new
                {
                    resultado = resultado,
                    mensaje = resultado ? "Asignación eliminada correctamente" : "No se pudo eliminar (el producto ya está en uso)"
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Error: " + ex.Message });
            }
        }

        [HttpGet]
        public JsonResult ObtenerAsignaciones()
        {
            try
            {
                var lista = _productoTiendaService.ObtenerProductoTienda();
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult GuardarPrecioVenta(PrecioVenta objeto)
        {
            try
            {
                bool resultado = objeto.IdPrecioVenta == 0
                    ? CD_Producto.Instancia.RegistrarPrecioVenta(objeto)
                    : CD_Producto.Instancia.ModificarPrecioVenta(objeto);

                return Json(new { resultado = resultado, message = resultado ? "Operación exitosa" : "Error al guardar el precio" });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        [HttpPost]
        public JsonResult EliminarPrecioVenta(int id)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, message = "ID inválido" });

                bool resultado = CD_Producto.Instancia.EliminarPrecioVenta(id);
                return Json(new { resultado = resultado, message = resultado ? "Precio eliminado correctamente" : "No se pudo eliminar" });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        public ActionResult ConsultarPrecioVenta() => View();

        [HttpGet]
        public ContentResult ObtenerHistorialPrecios(int idProducto)
        {
            var lista = CD_Producto.Instancia.ObtenerPorProducto(idProducto);
            var json = JsonConvert.SerializeObject(new { data = lista }, new JsonSerializerSettings
            {
                DateFormatHandling = DateFormatHandling.IsoDateFormat,
                DateTimeZoneHandling = DateTimeZoneHandling.Utc
            });
            return Content(json, "application/json");
        }

        [HttpGet]
        public JsonResult BuscarProductoPorCodigo(string codigo)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(codigo))
                    return Json(new { resultado = false, message = "El código de producto es requerido." }, JsonRequestBehavior.AllowGet);

                var producto = CD_Producto.Instancia.ObtenerProducto()
                    .FirstOrDefault(p => p.Codigo.Equals(codigo, StringComparison.OrdinalIgnoreCase));

                if (producto == null)
                    return Json(new { resultado = false, message = "Producto no encontrado." }, JsonRequestBehavior.AllowGet);

                return Json(new { resultado = true, data = producto }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = "Error: " + ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult GuardarMultiplesPrecios(List<PrecioVenta> precios)
        {
            try
            {
                if (precios == null || !precios.Any())
                    return Json(new { resultado = false, message = "No hay precios para guardar." });

                foreach (var precio in precios)
                {
                    bool ok = precio.IdPrecioVenta == 0
                        ? CD_Producto.Instancia.RegistrarPrecioVenta(precio)
                        : CD_Producto.Instancia.ModificarPrecioVenta(precio);

                    if (!ok) return Json(new { resultado = false, message = "Error al procesar un precio." });
                }

                return Json(new { resultado = true });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        [HttpPost]
        public JsonResult ActualizarPrecioVenta(int IdPrecioVenta, decimal PrecioVenta, DateTime FechaInicio, DateTime? FechaFin)
        {
            try
            {
                if (PrecioVenta < 0)
                    return Json(new { resultado = false, message = "El precio debe ser mayor o igual a cero." });

                if (FechaFin.HasValue && FechaFin < FechaInicio)
                    return Json(new { resultado = false, message = "La fecha fin no puede ser menor que la fecha inicio." });

                var precio = CD_Producto.Instancia.ObtenerHistorialPreciosVentaPorId(IdPrecioVenta);
                if (precio == null)
                    return Json(new { resultado = false, message = "Precio no encontrado." });

                precio.PrecioUnidadVenta = PrecioVenta;
                precio.FechaInicioVigencia = FechaInicio;
                precio.FechaFinVigencia = FechaFin;

                bool actualizado = CD_Producto.Instancia.ActualizarPrecioVenta(precio);
                return Json(new { resultado = actualizado });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = "Error: " + ex.Message });
            }
        }

        [HttpGet]
        public JsonResult ObtenerMotivosBaja()
        {
            try
            {
                var lista = CD_MotivoBaja.Instancia.ObtenerMotivosBaja();
                return Json(lista, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult BajaStockProductoTienda(int idProductoTienda, int idProducto, int idMotivoBaja, int cantidad, string observaciones)
        {
            try
            {
                if (cantidad <= 0)
                    return Json(new { resultado = false, mensaje = "La cantidad debe ser mayor a cero." });

                if (idMotivoBaja <= 0)
                    return Json(new { resultado = false, mensaje = "Debe seleccionar un motivo de baja." });

                if (!TienePermiso(TiendaActiva))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para dar de baja stock en esta sucursal." });

                bool resultado = _productoTiendaService.BajaStockConHistorial(
                    idProductoTienda, idProducto, idMotivoBaja, cantidad, observaciones ?? "");

                return Json(new
                {
                    resultado = resultado,
                    mensaje = resultado ? "Baja registrada correctamente." : "No se pudo registrar la baja."
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Error: " + ex.Message });
            }
        }
    }
}