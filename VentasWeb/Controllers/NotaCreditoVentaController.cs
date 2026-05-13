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

        [AuthorizeRol("NotaCreditoVenta", "Notas de Crédito Venta")]
        public ActionResult Index()
        {
            ViewBag.Tiendas = CD_Tienda.Instancia.ObtenerTiendas();
            return View();
        }

        // ============================================================
        //  JSON — LISTAR
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Notas de Crédito Venta")]
        public JsonResult Obtener(
            string fechainicio = "", string fechafin = "", string estado = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

            var lista = CD_NotaCreditoVenta.Instancia.ObtenerListaNotaCreditoVenta(
                idTienda, estado, fi, ff);

            return Json(new { data = lista ?? new List<CapaModelo.NotaCreditoVenta>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — REGISTRAR NC
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCreditoVenta", "Notas de Crédito Venta")]
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
        [AuthorizeRol("NotaCreditoVenta", "Notas de Crédito Venta")]
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

        [HttpGet]
        public JsonResult ObtenerMotivos()
        {
            var lista = CD_MotivoNotaCredito.Instancia.Obtener();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
    }
}
