using CapaDatos;
using CapaModelo;
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

        [HttpDelete]
        public JsonResult EliminarProductoTienda(int id)
        {
            try
            {
                bool respuesta = _productoTiendaService.EliminarProductoTienda(id);
                return Json(new { resultado = respuesta });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, message = ex.Message });
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
    }
}