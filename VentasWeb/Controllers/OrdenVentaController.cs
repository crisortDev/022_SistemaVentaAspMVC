using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Módulo Pre-Venta (Orden de Venta).
    /// El empleado de mostrador registra el presupuesto; el Cajero lo factura.
    /// </summary>
    [AuthorizeRol("OrdenVenta", "*")]
    public class OrdenVentaController : BaseController
    {
        // ============================================================
        //  VISTAS
        // ============================================================

        /// <summary>Formulario para registrar una nueva pre-venta.</summary>
        [AuthorizeRol("OrdenVenta", "Registrar Pre-venta")]
        public ActionResult Crear()
        {
            if (UsuarioActual == null) return RedirectToAction("Index", "Login");
            return View();
        }

        /// <summary>Lista de pre-ventas (con botón Facturar para el Cajero).</summary>
        [AuthorizeRol("OrdenVenta", "Consultar Pre-ventas")]
        public ActionResult Consultar()
        {
            return View();
        }

        // ============================================================
        //  JSON — REGISTRAR PRE-VENTA
        // ============================================================

        [HttpPost]
        [ValidateInput(false)]
        [AuthorizeRol("OrdenVenta", "Registrar Pre-venta")]
        public JsonResult Guardar(
            int idCliente, string observacion,
            string fechaVencimiento, string detalleXml)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(detalleXml))
                return Json(new { resultado = false, mensaje = "Debe agregar al menos un producto." });

            if (string.IsNullOrWhiteSpace(fechaVencimiento))
                return Json(new { resultado = false, mensaje = "Debe indicar la fecha de vencimiento." });

            // SuperAdmin (TiendaActiva=0): usar tienda 1 por defecto
            int idTienda = TiendaActiva > 0 ? TiendaActiva : 1;

            var r = CD_OrdenVenta.Instancia.RegistrarOrdenVenta(
                idTienda,
                idCliente > 0 ? (int?)idCliente : null,
                UsuarioActual.IdUsuario,
                observacion,
                fechaVencimiento,
                detalleXml);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje, idGenerado = r.idGenerado });
        }

        // ============================================================
        //  JSON — LISTAR
        // ============================================================

        [HttpGet]
        [AuthorizeRol("OrdenVenta", "Consultar Pre-ventas")]
        public JsonResult Obtener(
            string fechainicio = "", string fechafin = "",
            string estado = "", string numerooV = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;

            DateTime fi = ParseFecha(fechainicio, DateTime.Today.AddDays(-30));
            DateTime ff = ParseFecha(fechafin,   DateTime.Today);

            var lista = CD_OrdenVenta.Instancia.ObtenerListaOrdenVenta(
                idTienda, estado, fi, ff, numerooV);

            return Json(new { data = lista ?? new List<OrdenVenta>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — DETALLE (para modal de confirmación de factura)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerDetalle(int idOrdenVenta)
        {
            var ov = CD_OrdenVenta.Instancia.ObtenerDetalleOrdenVenta(idOrdenVenta);
            if (ov == null)
                return Json(new { resultado = false, mensaje = "Pre-venta no encontrada." },
                            JsonRequestBehavior.AllowGet);

            return Json(new { resultado = true, datos = ov }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — ANULAR PRE-VENTA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("OrdenVenta", "Consultar Pre-ventas")]
        public JsonResult Anular(int idOrdenVenta, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(motivo))
                return Json(new { resultado = false, mensaje = "Debe ingresar el motivo de anulación." });

            var r = CD_OrdenVenta.Instancia.AnularOrdenVenta(
                idOrdenVenta, UsuarioActual.IdUsuario, motivo);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        // ── Helper: parsea fechas dd/MM/yyyy enviadas por el datepicker ──
        private static DateTime ParseFecha(string valor, DateTime fallback)
        {
            if (string.IsNullOrWhiteSpace(valor)) return fallback;
            DateTime resultado;
            if (DateTime.TryParseExact(valor, "dd/MM/yyyy",
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out resultado))
                return resultado;
            // Fallback a conversión estándar
            return DateTime.TryParse(valor, out resultado) ? resultado : fallback;
        }
    }
}
