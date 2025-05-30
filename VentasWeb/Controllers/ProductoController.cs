using CapaDatos;
using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class ProductoController : Controller
    {
        private readonly CD_Producto _productoService = CD_Producto.Instancia;
        private readonly CD_ProductoTienda _productoTiendaService = CD_ProductoTienda.Instancia;

        // GET: Producto
        public ActionResult Crear()
        {
            return View();
        }

        // GET: Asignación de productos a tiendas
        public ActionResult Asignar()
        {
            return View();
        }

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
                var productos = _productoService.ObtenerProducto()
                    .Where(x => x.Activo == true)
                    .ToList();

                if (IdTienda != 0)
                {
                    var productosTienda = _productoTiendaService.ObtenerProductoTienda()
                        .Where(x => x.oTienda.IdTienda == IdTienda)
                        .ToList();

                    productos = (from producto in productos
                                 join productoTienda in productosTienda
                                 on producto.IdProducto equals productoTienda.oProducto.IdProducto
                                 select producto).ToList();
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
                bool respuesta;

                if (objeto.IdProducto == 0)
                {
                    respuesta = _productoService.RegistrarProducto(objeto);
                }
                else
                {
                    respuesta = _productoService.ModificarProducto(objeto);
                }

                return Json(new
                {
                    resultado = respuesta,
                    message = respuesta ? "Operación exitosa" : "Error al guardar"
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        [HttpPost]
        public JsonResult Eliminar(int id)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "ID inválido" });

                bool resultado = CD_Producto.Instancia.EliminarProducto(id);
                return Json(new
                {
                    resultado = resultado,
                    mensaje = resultado ? "Producto eliminado correctamente" : "No se pudo eliminar el producto"
                });
            }
            catch (Exception ex)
            {
                return Json(new
                {
                    resultado = false,
                    mensaje = "Error: " + ex.Message
                });
            }
        }

        [HttpPost]
        public JsonResult RegistrarProductoTienda(ProductoTienda objeto)
        {
            try
            {
                // Validar StockMínimo y StockMáximo

                if (objeto.StockMinimo < 0 || objeto.StockMaximo < 0)
                {
                    return Json(new { resultado = false, mensaje = "Los stocks no pueden ser negativos." });
                }

                if (objeto.StockMaximo <= objeto.StockMinimo)
                {
                    return Json(new { resultado = false, mensaje = "Stock máximo debe ser mayor que stock mínimo." });
                }

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
                    mensaje = resultado
                        ? "Asignación eliminada correctamente"
                        : "No se pudo eliminar (el producto ya está en uso)"
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
        public JsonResult BajaStockProductoTienda(int idProductoTienda, int cantidad, string motivo, int idProducto)
        {
            try
            {
                // Llamamos al servicio que maneja la baja de stock, pasando todos los parámetros
                string resultado = _productoTiendaService.BajaStockProductoTienda(idProductoTienda, cantidad, motivo, idProducto);

                if (resultado.Contains("Error"))
                {
                    return Json(new { resultado = false, mensaje = resultado });
                }

                return Json(new { resultado = true, mensaje = "Stock reducido correctamente" });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Error: " + ex.Message });
            }
        }

        [HttpPost]
        public JsonResult GuardarPrecioVenta(PrecioVenta objeto)
        {
            try
            {
                bool resultado = false;

                if (objeto.IdPrecioVenta == 0)
                {
                    resultado = CD_Producto.Instancia.RegistrarPrecioVenta(objeto);
                }
                else
                {
                    resultado = CD_Producto.Instancia.ModificarPrecioVenta(objeto);
                }

                return Json(new
                {
                    resultado = resultado,
                    message = resultado ? "Operación exitosa" : "Error al guardar el precio"
                });
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

                return Json(new
                {
                    resultado = resultado,
                    message = resultado ? "Precio eliminado correctamente" : "No se pudo eliminar"
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
            }
        }

        public ActionResult ConsultarPrecioVenta()
        {
            return View();
        }

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
                {
                    return Json(new { resultado = false, message = "El código de producto es requerido." }, JsonRequestBehavior.AllowGet);
                }

                var producto = CD_Producto.Instancia.ObtenerProducto()
                                .FirstOrDefault(p => p.Codigo.Equals(codigo, StringComparison.OrdinalIgnoreCase));

                if (producto == null)
                {
                    return Json(new { resultado = false, message = "Producto no encontrado." }, JsonRequestBehavior.AllowGet);
                }

                // Solo devolver el producto, para que el cliente JS haga otra llamada para obtener el historial con IdProducto
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
                    if (precio.IdPrecioVenta == 0)
                    {
                        // Nuevo registro
                        bool resInsert = CD_Producto.Instancia.RegistrarPrecioVenta(precio);
                        if (!resInsert)
                            return Json(new { resultado = false, message = "Error al insertar un precio." });
                    }
                    else
                    {
                        // Actualizar existente
                        bool resUpdate = CD_Producto.Instancia.ModificarPrecioVenta(precio);
                        if (!resUpdate)
                            return Json(new { resultado = false, message = "Error al actualizar un precio." });
                    }
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

                var precio = CD_Producto.Instancia.ObtenerHistorialPreciosVentaPorId(IdPrecioVenta); // <-- usa método que devuelve UNO

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


    }
}