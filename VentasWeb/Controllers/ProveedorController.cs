using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;
using VentasWeb.Utilidades;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Proveedor", "*")]
    public class ProveedorController : BaseController
    {
        // GET: Proveedor
        public ActionResult Crear()
        {
            ViewBag.EsSuperAdmin = EsSuperAdmin;
            return View();
        }

        public JsonResult Obtener()
        {
            try
            {
                List<Proveedor> olista = CD_Proveedor.Instancia.ObtenerProveedor();
                return Json(new { data = olista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError(
                    $"[ProveedorController.Obtener] {DateTime.Now:yyyy-MM-dd HH:mm:ss} | Error: {ex.Message}");
                return Json(new { data = new List<Proveedor>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpPost]
        public JsonResult Guardar(Proveedor objeto)
        {
            bool respuesta = false;

            if (objeto.IdProveedor == 0)
            {
                respuesta = CD_Proveedor.Instancia.RegistrarProveedor(objeto);
            }
            else
            {
                respuesta = CD_Proveedor.Instancia.ModificarProveedor(objeto);
            }

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        public JsonResult VerificarRuc(string ruc = "")
        {
            bool existe = CD_Proveedor.Instancia.VerificarRucExistente(ruc);
            return Json(new { existe }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Reactivar(int id = 0)
        {
            bool respuesta = CD_Proveedor.Instancia.ReactivarProveedor(id);
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        public JsonResult TieneCompras(int id = 0)
        {
            bool tiene = CD_Proveedor.Instancia.TieneCompras(id);
            return Json(new { tieneCompras = tiene }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Desactivar(int id = 0)
        {
            bool respuesta = CD_Proveedor.Instancia.DesactivarProveedor(id);
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Eliminar(int id = 0)
        {
            // Solo SuperAdmin puede eliminar físicamente un proveedor
            if (!EsSuperAdmin)
                return Json(new { resultado = false, mensaje = "No tiene permisos para eliminar proveedores." }, JsonRequestBehavior.AllowGet);

            var (resultado, mensaje) = CD_Proveedor.Instancia.EliminarProveedor(id);
            return Json(new { resultado, mensaje }, JsonRequestBehavior.AllowGet);
        }

    }
}