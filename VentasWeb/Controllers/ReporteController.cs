using CapaDatos;
using CapaModelo;
using CapaModelo.CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Reporte", "*")]
    public class ReporteController : BaseController
    {
        // GET: Reporte
        public ActionResult Producto()
        {
            SetNombreTienda();
            return View();
        }

        // GET: Reporte
        public ActionResult Ventas()
        {
            SetNombreTienda();
            return View();
        }

        public JsonResult ObtenerProducto(int idtienda, string codigoproducto)
        {
            // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
            if (!EsAdminGlobal) idtienda = TiendaActiva;

            List<ReporteProducto> lista = CD_Reportes.Instancia.ReporteProductoTienda(idtienda, codigoproducto ?? "");

            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        // Combo de tiendas para los reportes.
        // SuperAdmin: todas las sucursales. Otros: solo la suya.
        public JsonResult ObtenerTiendas()
        {
            var todas = CD_Tienda.Instancia.ObtenerTiendas() ?? new List<Tienda>();
            var lista = EsAdminGlobal
                ? todas
                : todas.Where(t => t.IdTienda == TiendaActiva).ToList();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }


        public JsonResult ObtenerVenta(string fechainicio, string fechafin, int idtienda)
        {
            // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
            if (!EsAdminGlobal) idtienda = TiendaActiva;

            // Rango por defecto: último mes si no vienen fechas
            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddMonths(-1) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

            // Devuelve todos los registros — el filtro por estado lo aplica el JS en memoria
            List<ReporteVenta> lista = CD_Reportes.Instancia.ReporteVenta(fi, ff, idtienda);
            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        // ── PDF: Reporte de Ventas operativo ─────────────────────────────────────
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFVenta(string fechainicio, string fechafin, int idtienda = 0, string estado = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? DateTime.Today.AddMonths(-1) : Convert.ToDateTime(fechainicio);
                DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                    ? DateTime.Today : Convert.ToDateTime(fechafin);

                List<ReporteVenta> lista = CD_Reportes.Instancia.ReporteVenta(fi, ff, idtienda);

                // "Efectiva" abarca 'Activo', 'Efectiva', NULL/vacío — todo lo que no sea 'Anulada'
                if (!string.IsNullOrWhiteSpace(estado))
                {
                    bool filtroEfectiva = estado.Equals("Efectiva", StringComparison.OrdinalIgnoreCase);
                    lista = filtroEfectiva
                        ? lista.Where(v => !string.Equals(v.Estado, "Anulada", StringComparison.OrdinalIgnoreCase)).ToList()
                        : lista.Where(v => string.Equals(v.Estado, estado, StringComparison.OrdinalIgnoreCase)).ToList();
                }

                // Tienda para el header del PDF
                string nomTienda = lista.Count > 0 ? lista[0].NombreTienda : "Todas las sucursales";
                string rucTienda = lista.Count > 0 ? lista[0].RucTienda    : "";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    RucTienda     = rucTienda,
                    FechaInicio   = fi.ToString("dd/MM/yyyy"),
                    FechaFin      = ff.ToString("dd/MM/yyyy"),
                    EstadoFiltro  = estado,
                    Ventas        = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "reporte_venta_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "reporte_venta_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_venta.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombre = $"Reporte_Ventas_{fi:yyyyMMdd}_{ff:yyyyMMdd}.pdf";
                return this.File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        public ActionResult Bajas()
        {
            SetNombreTienda();
            return View();
        }

        public JsonResult ObtenerBajas(
            string fechainicio, string fechafin,
            int idtienda, string estadobaja = "")
        {
            if (!EsAdminGlobal) idtienda = TiendaActiva;

            DateTime? fi = string.IsNullOrWhiteSpace(fechainicio) ? (DateTime?)null : Convert.ToDateTime(fechainicio);
            DateTime? ff = string.IsNullOrWhiteSpace(fechafin)    ? (DateTime?)null : Convert.ToDateTime(fechafin);

            var lista = CD_Reportes.Instancia.ReporteBajas(fi, ff, idtienda, estadobaja ?? "");
            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        // ── PDF: Reporte de Bajas ────────────────────────────────────────────────
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFBajas(
            string fechainicio = "", string fechafin = "",
            int idtienda = 0, string estadobaja = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)
                    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteBajas(fi, ff, idtienda, estadobaja ?? "");

                string nomTienda = idtienda > 0
                    ? (CD_Tienda.Instancia.ObtenerTiendas()?.Find(t => t.IdTienda == idtienda)?.Nombre
                       ?? "Tienda " + idtienda)
                    : "Todas las sucursales";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    FechaInicio   = fi.HasValue ? fi.Value.ToString("dd/MM/yyyy") : "—",
                    FechaFin      = ff.HasValue ? ff.Value.ToString("dd/MM/yyyy") : "—",
                    EstadoFiltro  = estadobaja ?? "",
                    IdTienda      = idtienda,
                    Bajas         = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "rpt_bajas_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "rpt_bajas_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_bajas.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string fi_str = fi.HasValue ? fi.Value.ToString("yyyyMMdd") : "todo";
                string ff_str = ff.HasValue ? ff.Value.ToString("yyyyMMdd") : "todo";
                string nombre = $"Reporte_Bajas_{fi_str}_{ff_str}.pdf";
                return File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // =============================================
        // REPORTE NC ASOCIADAS
        // =============================================

        public ActionResult NotaCredito()
        {
            SetNombreTienda();
            return View();
        }

        [HttpGet]
        public JsonResult ObtenerReporteNC(string fechainicio, string fechafin,
            int idproveedor = 0, int idtienda = 0, string estado = "")
        {
            try
            {
                // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio) ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteNC(fi, ff, idproveedor, idtienda, estado);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<NotaCredito>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFNC(string fechainicio, string fechafin,
            int idproveedor = 0, int idtienda = 0, string estado = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio) ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteNC(fi, ff, idproveedor, idtienda, estado);

                // Nombre del proveedor para el filtro en el membrete
                string provNombre = "";
                if (idproveedor > 0 && lista.Any())
                    provNombre = lista.First().Proveedor ?? "";

                string tmpJson = System.IO.Path.Combine(System.IO.Path.GetTempPath(),
                                  "nc_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = System.IO.Path.Combine(System.IO.Path.GetTempPath(),
                                  "nc_" + Guid.NewGuid().ToString("N") + ".pdf");

                var jo = new Newtonsoft.Json.Linq.JObject();
                jo["Items"]           = Newtonsoft.Json.Linq.JArray.FromObject(lista);
                jo["FechaInicio"]     = fechainicio ?? "";
                jo["FechaFin"]        = fechafin    ?? "";
                jo["NombreProveedor"] = provNombre;
                jo["EstadoFiltro"]    = estado      ?? "";
                jo["ReporteId"]       = GetReporteId();
                jo["NombreUsuario"]   = GetNombreUsuario();
                jo["NombreEmpresa"]   = GetNombreEmpresa();
                jo["LogoPath"]        = GetLogoPath();
                System.IO.File.WriteAllText(tmpJson,
                    jo.ToString(Newtonsoft.Json.Formatting.None),
                    new System.Text.UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_nc.py");

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
                    throw new Exception("El script no generó el archivo PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string fecha = System.DateTime.Now.ToString("yyyyMMdd");
                return this.File(pdfBytes, "application/pdf", "ReporteNC_" + fecha + ".pdf");
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // =============================================
        // REPORTE PROVEEDORES
        // =============================================

        public ActionResult Proveedores()
        {
            SetNombreTienda();
            return View();
        }

        [HttpGet]
        public JsonResult ObtenerReporteProveedores(string fechainicio, string fechafin,
            int idtienda = 0, bool solodeuda = false)
        {
            try
            {
                // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio) ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteProveedores(fi, ff, idtienda, solodeuda);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<ReporteProveedor>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpGet]
        public JsonResult ObtenerProveedoresCombo()
        {
            try
            {
                var lista = CD_Proveedor.Instancia.ObtenerProveedor();
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<Proveedor>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ============================================================
        //  RENTABILIDAD POR PRODUCTO (CPP)
        // ============================================================
        public ActionResult Rentabilidad()
        {
            SetNombreTienda();
            return View();
        }

        [HttpGet]
        public JsonResult ObtenerCategorias()
        {
            try
            {
                var lista = CD_Categoria.Instancia.ObtenerCategoria();
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<object>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpGet]
        public JsonResult ObtenerRentabilidad(
            string fechainicio = "", string fechafin = "",
            int idtienda = 0, int idcategoria = 0)
        {
            try
            {
                // Aislamiento por sucursal: si no es SuperAdmin, ignora lo que mande el cliente y fuerza su tienda
                int tienda = EsAdminGlobal ? idtienda : TiendaActiva;
                DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
                DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                    ? DateTime.Today : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ObtenerRentabilidad(tienda, fi, ff, idcategoria);
                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<ReporteRentabilidad>(), error = ex.Message },
                    JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFRentabilidad(
            string fechainicio = "", string fechafin = "",
            int idtienda = 0, int idcategoria = 0)
        {
            try
            {
                // Aislamiento por sucursal: si no es SuperAdmin, ignora lo que mande el cliente y fuerza su tienda
                int tienda = EsAdminGlobal ? idtienda : TiendaActiva;
                DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
                DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                    ? DateTime.Today : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ObtenerRentabilidad(tienda, fi, ff, idcategoria);

                string nomTienda = tienda > 0
                    ? (CD_Tienda.Instancia.ObtenerTiendas()?.Find(t => t.IdTienda == tienda)?.Nombre ?? "Tienda " + tienda)
                    : "Todas las sucursales";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    FechaInicio   = fi.ToString("dd/MM/yyyy"),
                    FechaFin      = ff.ToString("dd/MM/yyyy"),
                    Datos         = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "rpt_rent_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "rpt_rent_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_rentabilidad.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombre = $"Rentabilidad_CPP_{fi:yyyyMMdd}_{ff:yyyyMMdd}.pdf";
                return File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // ── PDF: Reporte de Productos por Tienda ─────────────────────────────────
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFProductos(int idtienda = 0, string codigoproducto = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                var lista = CD_Reportes.Instancia.ReporteProductoTienda(idtienda, codigoproducto ?? "");

                string nomTienda = idtienda > 0 && lista.Count > 0
                    ? lista[0].NombreTienda
                    : "Todas las sucursales";
                string rucTienda = idtienda > 0 && lista.Count > 0
                    ? lista[0].RucTienda : "";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    RucTienda     = rucTienda,
                    CodigoFiltro  = codigoproducto ?? "",
                    IdTienda      = idtienda,
                    Productos     = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "rpt_prod_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "rpt_prod_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_productos_tienda.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string nombre = $"Reporte_Productos_{DateTime.Now:yyyyMMdd}.pdf";
                return File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // ── PDF: Reporte de Proveedores ──────────────────────────────────────────
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFProveedores(
            string fechainicio = "", string fechafin = "",
            int idtienda = 0, bool solodeuda = false)
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)
                    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteProveedores(fi, ff, idtienda, solodeuda);

                string nomTienda = idtienda > 0
                    ? (CD_Tienda.Instancia.ObtenerTiendas()?.Find(t => t.IdTienda == idtienda)?.Nombre
                       ?? "Tienda " + idtienda)
                    : "Todas las sucursales";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    FechaInicio   = fi.HasValue ? fi.Value.ToString("dd/MM/yyyy") : "—",
                    FechaFin      = ff.HasValue ? ff.Value.ToString("dd/MM/yyyy") : "—",
                    Proveedores   = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "rpt_prov_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "rpt_prov_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_proveedores.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string fi_str = fi.HasValue ? fi.Value.ToString("yyyyMMdd") : "todo";
                string ff_str = ff.HasValue ? ff.Value.ToString("yyyyMMdd") : "todo";
                string nombre = $"Reporte_Proveedores_{fi_str}_{ff_str}.pdf";
                return File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // =============================================
        // REPORTE DE TRASLADOS
        // =============================================

        public ActionResult Traslados()
        {
            SetNombreTienda();
            return View();
        }

        [HttpGet]
        public JsonResult ObtenerTraslados(
            string fechainicio, string fechafin,
            int idtienda = 0, string estadotraslado = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)
                    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteTraslados(fi, ff, idtienda, estadotraslado ?? "");
                return Json(lista, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new List<object>(), JsonRequestBehavior.AllowGet);
            }
        }

        // ── PDF: Reporte de Traslados ────────────────────────────────────────────
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DescargarPDFTraslados(
            string fechainicio = "", string fechafin = "",
            int idtienda = 0, string estadotraslado = "")
        {
            try
            {
                if (!EsAdminGlobal) idtienda = TiendaActiva;

                DateTime? fi = string.IsNullOrWhiteSpace(fechainicio)
                    ? (DateTime?)null : Convert.ToDateTime(fechainicio);
                DateTime? ff = string.IsNullOrWhiteSpace(fechafin)
                    ? (DateTime?)null : Convert.ToDateTime(fechafin);

                var lista = CD_Reportes.Instancia.ReporteTraslados(fi, ff, idtienda, estadotraslado ?? "");

                string nomTienda = idtienda > 0
                    ? (CD_Tienda.Instancia.ObtenerTiendas()?.Find(t => t.IdTienda == idtienda)?.Nombre
                       ?? "Tienda " + idtienda)
                    : "Todas las sucursales";

                var payload = new
                {
                    NombreTienda  = nomTienda,
                    FechaInicio   = fi.HasValue ? fi.Value.ToString("dd/MM/yyyy") : "—",
                    FechaFin      = ff.HasValue ? ff.Value.ToString("dd/MM/yyyy") : "—",
                    EstadoFiltro  = estadotraslado ?? "",
                    IdTienda      = idtienda,
                    Traslados     = lista,
                    ReporteId     = GetReporteId(),
                    NombreUsuario = GetNombreUsuario(),
                    NombreEmpresa = GetNombreEmpresa(),
                    LogoPath      = GetLogoPath()
                };

                string tmpJson = Path.Combine(Path.GetTempPath(),
                    "rpt_tras_" + Guid.NewGuid().ToString("N") + ".json");
                string tmpPdf  = Path.Combine(Path.GetTempPath(),
                    "rpt_tras_" + Guid.NewGuid().ToString("N") + ".pdf");

                System.IO.File.WriteAllText(tmpJson,
                    JsonConvert.SerializeObject(payload, Formatting.None),
                    new UTF8Encoding(false));

                string scriptPath = Server.MapPath("~/Scripts/PDF/generar_reporte_traslados.py");
                var psi = new ProcessStartInfo
                {
                    FileName               = FindPythonExe(),
                    Arguments              = $"\"{scriptPath}\" \"{tmpJson}\" \"{tmpPdf}\"",
                    UseShellExecute        = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    CreateNoWindow         = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(30000);
                    if (proc.ExitCode != 0)
                        throw new Exception("Error en script PDF: " + proc.StandardError.ReadToEnd());
                }

                if (!System.IO.File.Exists(tmpPdf))
                    throw new Exception("El script no generó el PDF.");

                byte[] pdfBytes = System.IO.File.ReadAllBytes(tmpPdf);
                try { System.IO.File.Delete(tmpJson); } catch { }
                try { System.IO.File.Delete(tmpPdf);  } catch { }

                string fi_str = fi.HasValue ? fi.Value.ToString("yyyyMMdd") : "todo";
                string ff_str = ff.HasValue ? ff.Value.ToString("yyyyMMdd") : "todo";
                string nombre = $"Reporte_Traslados_{fi_str}_{ff_str}.pdf";
                return File(pdfBytes, "application/pdf", nombre);
            }
            catch (Exception ex)
            {
                return Content("Error al generar PDF: " + ex.Message);
            }
        }

        // ── Helper: pasa el nombre de la sucursal activa al ViewBag ──
        private void SetNombreTienda()
        {
            if (!EsAdminGlobal && TiendaActiva > 0)
            {
                var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                      ?.Find(t => t.IdTienda == TiendaActiva);
                ViewBag.NombreTiendaActual = tienda?.Nombre ?? "Sucursal " + TiendaActiva;
            }
        }
    }
}