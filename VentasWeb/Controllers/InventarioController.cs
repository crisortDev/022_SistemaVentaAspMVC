using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Inventario", "*")]
    public class InventarioController : BaseController
    {
        // GET: Inventario/Traslado
        public ActionResult Traslado()
        {
            return View();
        }

        // GET: Inventario/Baja
        public ActionResult Baja()
        {
            return View();
        }

        // GET: Inventario/Stock
        public ActionResult Stock()
        {
            return View();
        }

        // =============================================
        // ENDPOINTS TRASLADO
        // =============================================

        [HttpPost]
        public JsonResult RegistrarTraslado(int idProducto, int idTiendaOrigen, int idTiendaDestino,
            int cantidad, string observaciones)
        {
            try
            {
                var usuario = (Usuario)Session["Usuario"];
                if (usuario == null)
                    return Json(new { resultado = false, mensaje = "Sesión expirada." });

                // ── Validar permiso sobre tienda origen ───────────
                if (!TienePermiso(idTiendaOrigen))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para trasladar desde esta sucursal." });

                var (resultado, mensaje) = CD_Inventario.Instancia.RegistrarTraslado(
                    idProducto, idTiendaOrigen, idTiendaDestino, cantidad, observaciones, usuario.IdUsuario);

                return Json(new { resultado, mensaje });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        [HttpGet]
        public JsonResult ObtenerHistorialTraslados(string fechainicio, string fechafin, int idtienda = 0)
        {
            try
            {
                var lista = CD_Inventario.Instancia.ObtenerHistorialTraslados(
                    Convert.ToDateTime(fechainicio),
                    Convert.ToDateTime(fechafin),
                    idtienda);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<Traslado>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // =============================================
        // ENDPOINTS BAJA
        // =============================================

        [HttpPost]
        public JsonResult BajarStock(int idProductoTienda, int idProducto, int cantidad, string motivo, int idMotivoBaja = 0)
        {
            try
            {
                if (cantidad <= 0)
                    return Json(new { resultado = false, mensaje = "La cantidad debe ser mayor a cero." });

                if (UsuarioActual == null)
                    return Json(new { resultado = false, mensaje = "Sesión expirada." });

                // ── Validar permiso por tienda activa ─────────────
                if (!TienePermiso(TiendaActiva))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para dar de baja stock en esta sucursal." });

                // La baja queda PENDIENTE de aprobación (no descuenta stock todavía)
                var r = CD_Inventario.Instancia.RegistrarBajaPendiente(
                    idProductoTienda, idProducto, cantidad, idMotivoBaja, motivo, UsuarioActual.IdUsuario);

                return Json(new { resultado = r.resultado, mensaje = r.mensaje });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        // ── Pantalla de aprobación de bajas ────────────────────────────────
        [AuthorizeRol("Inventario", "Aprobar Bajas")]
        public ActionResult AprobarBajas()
        {
            return View();
        }

        [HttpGet]
        [AuthorizeRol("Inventario", "Aprobar Bajas")]
        public JsonResult ObtenerBajas(string estado = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            var lista = CD_Inventario.Instancia.ObtenerBajas(idTienda, estado);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Aprobar Bajas")]
        public JsonResult AprobarBaja(int idHistorial)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var r = CD_Inventario.Instancia.AprobarBaja(idHistorial, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Aprobar Bajas")]
        public JsonResult RechazarBaja(int idHistorial, string motivoRechazo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var r = CD_Inventario.Instancia.RechazarBaja(idHistorial, UsuarioActual.IdUsuario, motivoRechazo);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpGet]
        public JsonResult ObtenerProductosPorTiendaBaja(int idTienda)
        {
            try
            {
                var lista = CD_Inventario.Instancia.ObtenerProductosPorTiendaBaja(idTienda);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<ProductoTiendaBaja>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // =============================================
        // ENDPOINTS STOCK
        // =============================================

        [HttpGet]
        public JsonResult ObtenerStock(int idtienda = 0, int idproducto = 0)
        {
            try
            {
                var lista = CD_Inventario.Instancia.ObtenerStockPorTienda(idtienda, idproducto);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<StockTienda>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // =============================================
        // ENDPOINT COMPARTIDO: Obtener tiendas (reutiliza Tienda controller)
        // =============================================
        [HttpGet]
        public JsonResult ObtenerTiendas()
        {
            var lista = CD_Tienda.Instancia.ObtenerTiendas();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // Obtener productos con stock para traslado (origen)
        [HttpGet]
        public JsonResult ObtenerProductosPorTienda(int idTienda)
        {
            try
            {
                var lista = CD_Inventario.Instancia.ObtenerProductosPorTiendaBaja(idTienda);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<ProductoTiendaBaja>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }
    }
}