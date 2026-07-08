using CapaDatos;
using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Web.Mvc;
using VentasWeb.Filters;
using System.Text;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Reporte de Gerencia — Módulo Compras.
    /// Solo accesible por SuperAdmin (por ahora).
    /// </summary>
    [AuthorizeRol("ReporteGerencia", "*")]
    public class ReporteGerenciaController : BaseController
    {
        // ============================================================
        //  VISTA
        // ============================================================

        [AuthorizeRol("ReporteGerencia", "Index")]
        public ActionResult Index()
        {
            var tiendas = CD_Tienda.Instancia.ObtenerTiendas();
            ViewBag.Tiendas = tiendas;

            // Para usuarios normales: pasar el nombre de su sucursal
            if (!EsSuperAdmin && TiendaActiva > 0)
            {
                var tiendaActual = tiendas?.Find(t => t.IdTienda == TiendaActiva);
                ViewBag.NombreTiendaActual = tiendaActual?.Nombre ?? "Sucursal " + TiendaActiva;
            }

            return View();
        }

        // ============================================================
        //  JSON: DATOS DEL REPORTE (usados por Chart.js en la vista)
        // ============================================================

        [HttpGet]
        [AuthorizeRol("ReporteGerencia", "Index")]
        public JsonResult ObtenerDatos(string fechainicio, string fechafin, int idtienda = 0)
        {
            try
            {
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                DateTime fi = ParseFecha(fechainicio, new DateTime(DateTime.Today.Year, 1, 1));
                DateTime ff = ParseFecha(fechafin,    DateTime.Today);

                if (fi > ff)
                    return Json(new { resultado = false, mensaje = "La fecha inicio no puede ser mayor a la fecha fin." },
                                JsonRequestBehavior.AllowGet);

                var reporte = CD_ReporteGerencia.Instancia.ObtenerReporte(fi, ff, idtienda);

                // Nombre de la tienda para el encabezado
                if (idtienda > 0)
                {
                    var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                        ?.Find(t => t.IdTienda == idtienda);
                    reporte.NombreTienda = tienda?.Nombre ?? "Tienda " + idtienda;
                }
                else
                {
                    reporte.NombreTienda = "Todas las tiendas";
                }

                return Json(new { resultado = true, data = reporte }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ============================================================
        //  PDF: GENERAR Y DESCARGAR
        // ============================================================

        [HttpPost]
        [AuthorizeRol("ReporteGerencia", "Index")]
        public ActionResult DescargarPDF(string fechainicio, string fechafin, int idtienda = 0)
        {
            try
            {
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                DateTime fi = ParseFecha(fechainicio, new DateTime(DateTime.Today.Year, 1, 1));
                DateTime ff = ParseFecha(fechafin,    DateTime.Today);

                var reporte = CD_ReporteGerencia.Instancia.ObtenerReporte(fi, ff, idtienda);

                if (idtienda > 0)
                {
                    var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                        ?.Find(t => t.IdTienda == idtienda);
                    reporte.NombreTienda = tienda?.Nombre ?? "Tienda " + idtienda;
                }
                else
                {
                    reporte.NombreTienda = "Todas las tiendas";
                }

                // ── Serializar datos a JSON en archivo temporal ───────────────
                string tmpJson = Path.Combine(Path.GetTempPath(),
                                              "reporte_compras_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                                              "reporte_compras_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson, JsonConvert.SerializeObject(reporte, Formatting.None));

                // ── Llamar al script Python ───────────────────────────────────
                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_compras.py");

                var psi = new ProcessStartInfo
                {
                    FileName               = "python",
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000); // 30 segundos máximo
                    if (proc.ExitCode != 0)
                    {
                        string err = proc.StandardError.ReadToEnd();
                        throw new Exception("Error en el script PDF: " + err);
                    }
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el archivo PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);

                // Limpiar temporales
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombreArchivo = $"Reporte_Compras_{fi:yyyyMM}_{ff:yyyyMM}.pdf";
                return this.File(pdfBytes, "application/pdf", nombreArchivo);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // ============================================================
        //  VENTAS GERENCIA — VISTA
        // ============================================================

        [AuthorizeRol("ReporteGerencia", "Index")]
        public ActionResult Ventas()
        {
            var tiendas = CD_Tienda.Instancia.ObtenerTiendas();
            ViewBag.Tiendas = tiendas;

            if (!EsSuperAdmin && TiendaActiva > 0)
            {
                var t = tiendas?.Find(x => x.IdTienda == TiendaActiva);
                ViewBag.NombreTiendaActual = t?.Nombre ?? "Sucursal " + TiendaActiva;
            }

            return View();
        }

        // ============================================================
        //  VENTAS GERENCIA — JSON
        // ============================================================

        [HttpGet]
        [AuthorizeRol("ReporteGerencia", "Index")]
        public JsonResult ObtenerDatosVentas(string fechainicio, string fechafin, int idtienda = 0)
        {
            try
            {
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                DateTime fi = ParseFecha(fechainicio, new DateTime(DateTime.Today.Year, 1, 1));
                DateTime ff = ParseFecha(fechafin,    DateTime.Today);

                if (fi > ff)
                    return Json(new { resultado = false, mensaje = "La fecha inicio no puede ser mayor a la fecha fin." },
                                JsonRequestBehavior.AllowGet);

                var reporte = CD_ReporteVentasGerencia.Instancia.ObtenerReporte(fi, ff, idtienda);

                if (idtienda > 0)
                {
                    var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                        ?.Find(t => t.IdTienda == idtienda);
                    reporte.NombreTienda = tienda?.Nombre ?? "Tienda " + idtienda;
                }
                else
                {
                    reporte.NombreTienda = "Todas las sucursales";
                }

                return Json(new { resultado = true, data = reporte }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ============================================================
        //  VENTAS GERENCIA — PDF
        // ============================================================

        [HttpPost]
        [AuthorizeRol("ReporteGerencia", "Index")]
        public ActionResult DescargarPDFVentas(string fechainicio, string fechafin, int idtienda = 0)
        {
            try
            {
                if (!EsSuperAdmin)
                    idtienda = TiendaActiva;

                DateTime fi = ParseFecha(fechainicio, new DateTime(DateTime.Today.Year, 1, 1));
                DateTime ff = ParseFecha(fechafin,    DateTime.Today);

                var reporte = CD_ReporteVentasGerencia.Instancia.ObtenerReporte(fi, ff, idtienda);

                if (idtienda > 0)
                {
                    var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                        ?.Find(t => t.IdTienda == idtienda);
                    reporte.NombreTienda = tienda?.Nombre ?? "Tienda " + idtienda;
                }
                else
                {
                    reporte.NombreTienda = "Todas las sucursales";
                }

                string tmpJson = Path.Combine(Path.GetTempPath(),
                                              "rptventas_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                                              "rptventas_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(reporte, Formatting.None),
                    new UTF8Encoding(false));   // sin BOM

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_ventas_gerencia.py");

                var psi = new ProcessStartInfo
                {
                    FileName               = "python",
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(60000);
                    if (proc.ExitCode != 0)
                    {
                        string err = proc.StandardError.ReadToEnd();
                        throw new Exception("Error en script PDF: " + err);
                    }
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el archivo PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombre = $"ReporteVentas_{fi:yyyyMM}_{ff:yyyyMM}.pdf";
                return this.File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // ── Helper: parsear fecha dd/MM/yyyy con fallback ─────────────────────
        private static DateTime ParseFecha(string str, DateTime fallback)
        {
            if (string.IsNullOrWhiteSpace(str)) return fallback;
            DateTime result;
            if (DateTime.TryParseExact(str, "dd/MM/yyyy",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out result))
                return result;
            if (DateTime.TryParse(str, out result)) return result;
            return fallback;
        }
    }
}
