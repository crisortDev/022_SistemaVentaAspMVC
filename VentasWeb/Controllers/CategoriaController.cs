using CapaDatos;
using CapaModelo;
using System;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Categoria", "*")]
    public class CategoriaController : BaseController
    {
        /// <summary>
        /// Lee el usuario autenticado desde Session["Usuario"] y devuelve "Nombres Apellidos".
        /// Si la sesión no existe devuelve "SISTEMA" como fallback.
        /// </summary>
        private string UsuarioActual
        {
            get
            {
                var usuario = Session["Usuario"] as Usuario;
                if (usuario == null) return "SISTEMA";
                return $"{usuario.Nombres} {usuario.Apellidos}".Trim();
            }
        }

        public ActionResult Crear() => View();

        public JsonResult Obtener()
        {
            var lista = CD_Categoria.Instancia.ObtenerCategoria();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Guardar(Categoria objeto)
        {
            if (objeto == null || string.IsNullOrWhiteSpace(objeto.Descripcion))
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            objeto.Descripcion = objeto.Descripcion.Trim().ToUpper();
            objeto.UsuarioModificacion = UsuarioActual;

            // PorcentajeGanancia viene del frontend; si llega negativo lo forzamos a 0
            if (objeto.PorcentajeGanancia < 0)
                objeto.PorcentajeGanancia = 0;

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

        [HttpPost]
        public JsonResult CambiarEstado(int id, bool activo)
        {
            if (id <= 0)
                return Json(new { resultado = false, mensaje = "Id inválido." });

            try
            {
                bool respuesta = CD_Categoria.Instancia.CambiarEstadoCategoria(id, activo, UsuarioActual);
                string mensaje = activo ? "Categoría activada." : "Categoría desactivada.";
                return Json(new { resultado = respuesta, mensaje = mensaje });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message });
            }
        }
    }
}