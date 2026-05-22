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
            return View();
        }

        // GET: Reporte
        public ActionResult Ventas()
        {
            return View();
        }

        public JsonResult ObtenerProducto(int idtienda, string codigoproducto)
        {
            List<ReporteProducto> lista = CD_Reportes.Instancia.ReporteProductoTienda(idtienda, codigoproducto);

            return Json(lista, JsonRequestBehavior.AllowGet);
        }


        public JsonResult ObtenerVenta(string fechainicio, string fechafin, int idtienda)
        {

            List<ReporteVenta> lista = CD_Reportes.Instancia.ReporteVenta(Convert.ToDateTime(fechainicio), Convert.ToDateTime(fechafin), idtienda);
            return Json(lista, JsonRequestBehavior.AllowGet);
        }

        public ActionResult Bajas()
        {
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
    }
}