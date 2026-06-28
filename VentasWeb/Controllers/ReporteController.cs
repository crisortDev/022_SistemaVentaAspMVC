using CapaDatos;
using CapaModelo;
using CapaModelo.CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
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
            return View();
        }

        public JsonResult ObtenerProducto(int idtienda, string codigoproducto)
        {
            // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
            if (!EsSuperAdmin) idtienda = TiendaActiva;

            List<ReporteProducto> lista = CD_Reportes.Instancia.ReporteProductoTienda(idtienda, codigoproducto ?? "");

            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        // Combo de tiendas para los reportes.
        // SuperAdmin: todas las sucursales. Otros: solo la suya.
        public JsonResult ObtenerTiendas()
        {
            var todas = CD_Tienda.Instancia.ObtenerTiendas() ?? new List<Tienda>();
            var lista = EsSuperAdmin
                ? todas
                : todas.Where(t => t.IdTienda == TiendaActiva).ToList();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }


        public JsonResult ObtenerVenta(string fechainicio, string fechafin, int idtienda)
        {
            // Aislamiento por sucursal: si no es SuperAdmin, fuerza su tienda
            if (!EsSuperAdmin) idtienda = TiendaActiva;

            // Rango por defecto: último mes si no vienen fechas
            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddMonths(-1) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

            List<ReporteVenta> lista = CD_Reportes.Instancia.ReporteVenta(fi, ff, idtienda);
            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        public ActionResult Bajas()
        {
            SetNombreTienda();
            return View();
        }

        public JsonResult ObtenerBajas(string fechainicio, string fechafin, int idtienda)
        {
            List<ReporteBaja> lista = CD_Reportes.Instancia.ReporteBajas(
                Convert.ToDateTime(fechainicio),
                Convert.ToDateTime(fechafin),
                idtienda);

            return Json(lista, JsonRequestBehavior.AllowGet);
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
                int tienda = idtienda > 0 ? idtienda : (EsSuperAdmin ? 0 : TiendaActiva);
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

        // ── Helper: pasa el nombre de la sucursal activa al ViewBag ──
        private void SetNombreTienda()
        {
            if (!EsSuperAdmin && TiendaActiva > 0)
            {
                var tienda = CD_Tienda.Instancia.ObtenerTiendas()
                                      ?.Find(t => t.IdTienda == TiendaActiva);
                ViewBag.NombreTiendaActual = tienda?.Nombre ?? "Sucursal " + TiendaActiva;
            }
        }
    }
}