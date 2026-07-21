using CapaDatos;
using CapaModelo;
using Newtonsoft.Json;
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
            string fechainicio = "", string fechafin = "", string estado = "", int idtienda = 0)
        {
            // Todas las sucursales pueden ver todas las NCs (para imprimir y consultar).
            // El filtro de tienda es opcional: si se pasa un valor lo aplica, si no muestra todo.
            DateTime fi = ParseFecha(fechainicio, DateTime.Today.AddDays(-30));
            DateTime ff = ParseFecha(fechafin,   DateTime.Today);

            var lista = CD_NotaCreditoVenta.Instancia.ObtenerListaNotaCreditoVenta(
                idtienda, estado, fi, ff);

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

        // ============================================================
        //  REGISTRAR NC POR CUOTAS — formulario con selección de productos
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public ActionResult RegistrarCredito(int idVenta)
        {
            ViewBag.IdVenta = idVenta;
            return View();
        }

        // ============================================================
        //  JSON — OBTENER PRODUCTOS DE VENTA PARA NC
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult ObtenerProductosVenta(int idVenta)
        {
            var r = CD_NotaCreditoVenta.Instancia.ObtenerProductosVentaParaNC(idVenta);
            if (!r.resultado)
                return Json(new { resultado = false, mensaje = r.mensaje }, JsonRequestBehavior.AllowGet);

            return Json(new
            {
                resultado    = true,
                infoVenta    = r.infoVenta,
                productos    = r.productos
            }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — REGISTRAR NC CRÉDITO (POST desde RegistrarCredito.cshtml)
        // ============================================================

        [HttpPost]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult RegistrarCredito(
            int idVenta, int idMotivoNC, string observacion, string productosJson)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            List<NotaCreditoVentaDetalle> detalle;
            try
            {
                detalle = JsonConvert.DeserializeObject<List<NotaCreditoVentaDetalle>>(productosJson ?? "[]")
                          ?? new List<NotaCreditoVentaDetalle>();
            }
            catch
            {
                return Json(new { resultado = false, mensaje = "Error al leer el detalle de productos." });
            }

            if (detalle.Count == 0)
                return Json(new { resultado = false, mensaje = "Debe seleccionar al menos un producto." });

            var r = CD_NotaCreditoVenta.Instancia.RegistrarNCVentaCredito(
                idVenta, idMotivoNC, observacion, UsuarioActual.IdUsuario, detalle);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje, idGenerado = r.idGenerado });
        }

        // ============================================================
        //  JSON — OBTENER DETALLE DE UNA NCV (para modal de aprobación)
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public JsonResult ObtenerDetalleNCV(int idNCVenta)
        {
            var lista = CD_NotaCreditoVenta.Instancia.ObtenerDetalleNCV(idNCVenta);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  PDF — IMPRIMIR NOTA DE CRÉDITO DE VENTA
        // ============================================================

        [HttpGet]
        [AuthorizeRol("NotaCreditoVenta", "Nota de Crédito Venta")]
        public ActionResult ImprimirNCV(int idNCVenta)
        {
            try
            {
                var r = CD_NotaCreditoVenta.Instancia.ObtenerNCVParaImprimir(idNCVenta);
                if (!r.resultado || r.cabecera == null)
                    return Content("Error: " + r.mensaje);

                string tmpJson = System.IO.Path.Combine(System.IO.Path.GetTempPath(),
                                   "ncv_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = System.IO.Path.Combine(System.IO.Path.GetTempPath(),
                                   "ncv_" + Guid.NewGuid().ToString("N") + ".pdf");

                var jo = new Newtonsoft.Json.Linq.JObject();
                jo["Cabecera"]      = Newtonsoft.Json.Linq.JObject.FromObject(r.cabecera);
                jo["Productos"]     = Newtonsoft.Json.Linq.JArray.FromObject(r.productos);
                jo["NombreEmpresa"] = GetNombreEmpresa();
                jo["LogoPath"]      = GetLogoPath();
                jo["NombreUsuario"] = GetNombreUsuario();
                jo["ReporteId"]     = GetReporteId();

                System.IO.File.WriteAllText(tmpJson,
                    jo.ToString(Newtonsoft.Json.Formatting.None),
                    new System.Text.UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_nc_venta_pdf.py");

                var psi = new System.Diagnostics.ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = System.Diagnostics.Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                    {
                        string err = proc.StandardError.ReadToEnd();
                        throw new Exception("Error en script PDF: " + err);
                    }
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] bytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombreArchivo = "NCV_" + r.cabecera.NumeroNCV.Replace("/", "-") + ".pdf";
                return File(bytes, "application/pdf", nombreArchivo);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }
    }
}
