using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Categoria", "*")]
    public class CategoriaController : Controller
    {
        // GET: Categoria/Crear
        public ActionResult Crear() => View();

        // GET: Obtener lista para DataTable
        public JsonResult Obtener()
        {
            var lista = CD_Categoria.Instancia.ObtenerCategoria();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // POST: Guardar (crear o modificar)
        [HttpPost]
        public JsonResult Guardar(Categoria objeto)
        {
            if (objeto == null || string.IsNullOrWhiteSpace(objeto.Descripcion))
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            // Forzar mayúsculas también en servidor
            objeto.Descripcion = objeto.Descripcion.Trim().ToUpper();

            try
            {
                bool respuesta = objeto.IdCategoria == 0
                    ? CD_Categoria.Instancia.RegistrarCategoria(objeto)
                    : CD_Categoria.Instancia.ModificarCategoria(objeto);

                return Json(new { resultado = respuesta });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }

        // GET: Eliminar
        [HttpGet]
        public JsonResult Eliminar(int id = 0)
        {
            if (id <= 0)
                return Json(new { resultado = false }, JsonRequestBehavior.AllowGet);

            bool respuesta = CD_Categoria.Instancia.EliminarCategoria(id);
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }
    }
}