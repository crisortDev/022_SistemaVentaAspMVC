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

            var r = CD_OrdenVenta.Instancia.RegistrarOrdenVenta(
                TiendaActiva,
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

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

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
    }
}
