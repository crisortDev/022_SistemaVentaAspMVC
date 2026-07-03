using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
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

        // GET: Inventario/AprobarTraslados
        [AuthorizeRol("Inventario", "Aprobar Traslados")]
        public ActionResult AprobarTraslados()
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
                if (UsuarioActual == null)
                    return Json(new { resultado = false, mensaje = "Sesión expirada." });

                // Validar permiso sobre tienda origen
                if (!TienePermiso(idTiendaOrigen))
                    return Json(new { resultado = false, mensaje = "No tiene permisos para trasladar desde esta sucursal." });

                // El traslado queda PENDIENTE — no mueve stock hasta que lo apruebe el encargado destino
                var r = CD_Inventario.Instancia.RegistrarTrasladoPendiente(
                    idProducto, idTiendaOrigen, idTiendaDestino, cantidad, observaciones, UsuarioActual.IdUsuario);

                return Json(new { resultado = r.resultado, mensaje = r.mensaje });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        [HttpGet]
        public JsonResult ObtenerHistorialTraslados(string fechainicio, string fechafin, int idtienda = 0, string estado = "")
        {
            try
            {
                // No-SuperAdmin solo ve traslados de su sucursal
                if (!EsSuperAdmin && idtienda == 0) idtienda = TiendaActiva;

                var lista = CD_Inventario.Instancia.ObtenerHistorialTraslados(
                    Convert.ToDateTime(fechainicio),
                    Convert.ToDateTime(fechafin),
                    idtienda, estado);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<Traslado>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpGet]
        [AuthorizeRol("Inventario", "Aprobar Traslados")]
        public JsonResult ObtenerTrasladosPendientes()
        {
            // Trae solo los Pendientes del día anterior en adelante para la sucursal del encargado
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            var lista = CD_Inventario.Instancia.ObtenerHistorialTraslados(
                DateTime.Today.AddDays(-30), DateTime.Today, idTienda, "Pendiente");
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Aprobar Traslados")]
        public JsonResult AprobarTraslado(int idTraslado)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // Validar que el aprobador sea de la sucursal DESTINO del traslado
            int idTiendaDestino = CD_Inventario.Instancia.ObtenerTiendaDestinoDeTraslado(idTraslado);
            if (!TienePermiso(idTiendaDestino))
                return Json(new { resultado = false, mensaje = "Solo puede aprobar traslados destinados a su propia sucursal." });

            var r = CD_Inventario.Instancia.AprobarTraslado(idTraslado, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Aprobar Traslados")]
        public JsonResult RechazarTraslado(int idTraslado, string motivoRechazo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idTiendaDestino = CD_Inventario.Instancia.ObtenerTiendaDestinoDeTraslado(idTraslado);
            if (!TienePermiso(idTiendaDestino))
                return Json(new { resultado = false, mensaje = "Solo puede rechazar traslados destinados a su propia sucursal." });

            var r = CD_Inventario.Instancia.RechazarTraslado(idTraslado, UsuarioActual.IdUsuario, motivoRechazo);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
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

        // ════════ TOMA DE INVENTARIO — OPERADOR ════════════════════════════════

        [AuthorizeRol("Inventario", "Toma de Inventario")]
        public ActionResult TomaInventario()
        {
            return View();
        }

        /// <summary>Inventarios asignados al operador actual (sin stock/diferencias).</summary>
        [HttpGet]
        [AuthorizeRol("Inventario", "Toma de Inventario")]
        public JsonResult ObtenerInventariosOperador()
        {
            if (UsuarioActual == null) return Json(new { data = new List<object>() }, JsonRequestBehavior.AllowGet);
            var lista = CD_Inventario.Instancia.ObtenerInventariosOperador(UsuarioActual.IdUsuario);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        /// <summary>Productos de la tienda SIN stock/costo — para el conteo del operador.</summary>
        [HttpGet]
        [AuthorizeRol("Inventario", "Toma de Inventario")]
        public JsonResult ObtenerProductosParaConteo(int idTienda)
        {
            if (idTienda == 0) idTienda = TiendaActiva;
            var lista = CD_Inventario.Instancia.ObtenerProductosParaConteo(idTienda);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        /// <summary>Operador abre el inventario asignado → estado En Progreso.</summary>
        [HttpPost]
        [AuthorizeRol("Inventario", "Toma de Inventario")]
        public JsonResult IniciarConteo(int idInventario)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });
            var r = CD_Inventario.Instancia.IniciarConteoInventario(idInventario, UsuarioActual.IdUsuario);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        /// <summary>Operador finaliza el conteo → Pendiente de Aprobación.</summary>
        [HttpPost]
        [ValidateInput(false)]
        [AuthorizeRol("Inventario", "Toma de Inventario")]
        public JsonResult FinalizarConteo(int idInventario, string detalleXml, string observacion)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });
            if (string.IsNullOrWhiteSpace(detalleXml))
                return Json(new { resultado = false, mensaje = "Debe registrar al menos un producto contado." });

            var r = CD_Inventario.Instancia.FinalizarConteoInventario(
                idInventario, UsuarioActual.IdUsuario, detalleXml, observacion);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        // ════════ GESTIÓN DE INVENTARIO — SUPERVISOR ════════════════════════════

        [AuthorizeRol("Inventario", "Inventarios")]
        public ActionResult Inventarios()
        {
            return View();
        }

        /// <summary>Supervisor crea un nuevo proceso de inventario.</summary>
        [HttpPost]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult CrearInventario(int idTienda, string observacion)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });
            if (idTienda == 0) idTienda = TiendaActiva;
            if (!TienePermiso(idTienda)) return AccesoDenegado();

            var r = CD_Inventario.Instancia.CrearInventario(idTienda, UsuarioActual.IdUsuario, observacion);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje, idInventario = r.idInventario });
        }

        /// <summary>Supervisor asigna un operador a un inventario.</summary>
        [HttpPost]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult AsignarOperadorInventario(int idInventario, int idOperador)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });
            var r = CD_Inventario.Instancia.AsignarOperadorInventario(idInventario, idOperador);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpGet]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult ObtenerInventarios(string estado = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            var lista = CD_Inventario.Instancia.ObtenerInventariosSupervisor(idTienda, estado);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult ObtenerDetalleInventario(int idInventario)
        {
            var lista = CD_Inventario.Instancia.ObtenerDetalleInventario(idInventario);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult AprobarInventario(int idInventario)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idTiendaInv = CD_Inventario.Instancia.ObtenerTiendaDeInventario(idInventario);
            if (!TienePermiso(idTiendaInv))
                return Json(new { resultado = false, mensaje = "Solo puede aprobar inventarios de su propia sucursal." });

            var r = CD_Inventario.Instancia.AprobarInventario(idInventario, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult RechazarInventario(int idInventario, string motivoRechazo)
        {
            if (UsuarioActual == null) return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idTiendaInv = CD_Inventario.Instancia.ObtenerTiendaDeInventario(idInventario);
            if (!TienePermiso(idTiendaInv))
                return Json(new { resultado = false, mensaje = "Solo puede rechazar inventarios de su propia sucursal." });

            var r = CD_Inventario.Instancia.RechazarInventario(idInventario, UsuarioActual.IdUsuario, motivoRechazo);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
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

            int idTiendaBaja = CD_Inventario.Instancia.ObtenerTiendaDeBaja(idHistorial);
            if (!TienePermiso(idTiendaBaja))
                return Json(new { resultado = false, mensaje = "Solo puede aprobar bajas de su propia sucursal." });

            var r = CD_Inventario.Instancia.AprobarBaja(idHistorial, UsuarioActual.IdUsuario, EsSuperAdmin);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Aprobar Bajas")]
        public JsonResult RechazarBaja(int idHistorial, string motivoRechazo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idTiendaBaja = CD_Inventario.Instancia.ObtenerTiendaDeBaja(idHistorial);
            if (!TienePermiso(idTiendaBaja))
                return Json(new { resultado = false, mensaje = "Solo puede rechazar bajas de su propia sucursal." });

            var r = CD_Inventario.Instancia.RechazarBaja(idHistorial, UsuarioActual.IdUsuario, motivoRechazo);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        [HttpPost]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult AnularInventario(int idInventario)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idTiendaInv = CD_Inventario.Instancia.ObtenerTiendaDeInventario(idInventario);
            if (!TienePermiso(idTiendaInv))
                return Json(new { resultado = false, mensaje = "Solo puede anular inventarios de su propia sucursal." });

            var r = CD_Inventario.Instancia.AnularInventario(idInventario, UsuarioActual.IdUsuario);
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
        // =============================================
        // ENDPOINTS COMPARTIDOS (accesibles a todos los roles con permiso Inventario)
        // =============================================

        [HttpGet]
        public JsonResult ObtenerTiendas()
        {
            var lista = CD_Tienda.Instancia.ObtenerTiendas();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        /// <summary>
        /// Devuelve motivos de baja activos.
        /// Accesible a Cajero/Repositor desde la vista de Baja (no tienen permiso en MotivoBajaController).
        /// </summary>
        [HttpGet]
        public JsonResult ObtenerMotivosBaja()
        {
            var lista = CD_MotivoBaja.Instancia.ObtenerMotivosBaja();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        /// <summary>
        /// Devuelve repositores activos (IdRol=7), opcionalmente filtrados por sucursal.
        /// Accesible a Supervisor/Encargado desde la vista de Inventarios.
        /// </summary>
        [HttpGet]
        [AuthorizeRol("Inventario", "Inventarios")]
        public JsonResult ObtenerUsuariosActivos(int idTienda = 0)
        {
            const int ID_ROL_REPOSITOR = 7;
            var lista = CapaDatos.CD_Usuario.Instancia.ObtenerUsuarios();
            var query = lista.Where(u => u.Activo && u.IdRol == ID_ROL_REPOSITOR);
            if (idTienda > 0)
                query = query.Where(u => u.IdTienda.HasValue && u.IdTienda == idTienda);
            var resultado = query
                .Select(u => new {
                    u.IdUsuario,
                    NombreCompleto = u.Nombres + " " + u.Apellidos,
                    DescripcionRol = u.oRol != null ? u.oRol.Descripcion : "",
                    u.IdTienda
                })
                .OrderBy(u => u.NombreCompleto)
                .ToList();
            return Json(new { data = resultado }, JsonRequestBehavior.AllowGet);
        }

    }
}