using CapaDatos;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Gestión de Notas de Crédito de Venta.
    /// El cajero/empleado la registra; el Encargado/Admin la aprueba o rechaza.
    /// </summary>
    [AuthorizeRol("NotaCreditoVenta", "*")]
    public class NotaCreditoVentaController : BaseController
    {
        // ============================================================
        //  VISTA PRINCIPAL
        // ============================================================

        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public ActionResult Index()
        {
            ViewBag.Tiendas = CD_Tienda.Instancia.ObtenerTiendas();
            return View();
        }

        // ============================================================
        //  JSON — LISTAR
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult Obtener(
            string fechainicio = "", string fechafin = "", string estado = "")
        {
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

            DateTime fi = ParseFecha(fechainicio, DateTime.Today.AddDays(-30));
            DateTime ff = ParseFecha(fechafin,   DateTime.Today);

            var lista = CD_NotaCreditoVenta.Instancia.ObtenerListaNotaCreditoVenta(
                idTienda, estado, fi, ff);

            return Json(new { data = lista ?? new List<CapaModelo.NotaCreditoVenta>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — REGISTRAR NC
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult Registrar(
            int idVenta, int idMotivoNC, decimal monto, string observacion)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (monto <= 0)
                return Json(new { resultado = false, mensaje = "El monto debe ser mayor a cero." });

            var r = CD_NotaCreditoVenta.Instancia.RegistrarNotaCreditoVenta(
                idVenta, idMotivoNC, monto, observacion, UsuarioActual.IdUsuario);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje, idGenerado = r.idGenerado });
        }

        // ============================================================
        //  JSON — APROBAR / RECHAZAR
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult AprobarRechazar(
            int idNCVenta, string accion, string motivoRechazo = "")
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (accion != "Aprobar" && accion != "Rechazar")
                return Json(new { resultado = false, mensaje = "Acción no válida." });

            if (accion == "Rechazar" && string.IsNullOrWhiteSpace(motivoRechazo))
                return Json(new { resultado = false, mensaje = "Debe ingresar el motivo del rechazo." });

            var r = CD_NotaCreditoVenta.Instancia.AprobarRechazarNCV(
                idNCVenta, UsuarioActual.IdUsuario, accion, motivoRechazo);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        // ============================================================
        //  JSON — MOTIVOS DE NC (para el select del modal)
        // ============================================================

        // ── Helper: parsea fechas dd/MM/yyyy del datepicker ──
        private static DateTime ParseFecha(string valor, DateTime fallback)
        {
            if (string.IsNullOrWhiteSpace(valor)) return fallback;
            DateTime resultado;
            if (DateTime.TryParseExact(valor, "dd/MM/yyyy",
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out resultado))
                return resultado;
            return DateTime.TryParse(valor, out resultado) ? resultado : fallback;
        }

        [HttpGet]
        public JsonResult ObtenerMotivos()
        {
            var lista = CD_MotivoNotaCredito.Instancia.Obtener();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
    }
}
