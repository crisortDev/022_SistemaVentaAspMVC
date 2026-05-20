using CapaDatos;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("PuntoCaja", "*")]
    public class PuntoCajaController : BaseController
    {
        // ── Index — lista maestro de puntos de caja ───────────────────
        [AuthorizeRol("PuntoCaja", "Index")]
        public ActionResult Index()
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            ViewBag.Puntos   = CD_PuntoCaja.Instancia.ObtenerPuntos(idTienda);
            ViewBag.Tiendas  = CD_Tienda.Instancia.ObtenerTiendas();
            ViewBag.IdTienda = idTienda;
            return View();
        }

        // ── JSON — obtener puntos (con filtro de tienda) ──────────────
        [HttpGet]
        [AuthorizeRol("PuntoCaja", "Index")]
        public JsonResult Obtener(int idTienda = 0)
        {
            if (!EsSuperAdmin) idTienda = TiendaActiva;
            var lista = CD_PuntoCaja.Instancia.ObtenerPuntos(idTienda);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ── JSON — obtener puntos activos para dropdown apertura ──────
        [HttpGet]
        [AuthorizeRol("PuntoCaja", "Index")]
        public JsonResult ObtenerActivos(int idTienda = 0)
        {
            if (!EsSuperAdmin) idTienda = TiendaActiva;
            var lista = CD_PuntoCaja.Instancia.ObtenerPuntos(idTienda);
            var activos = new System.Collections.Generic.List<object>();
            foreach (var p in lista)
                if (p.Activo)
                    activos.Add(new { p.IdPuntoCaja, p.Nombre, p.NombreTienda });
            return Json(new { data = activos }, JsonRequestBehavior.AllowGet);
        }

        // ── JSON — sesiones (detalle) de un punto de caja ────────────
        [HttpGet]
        [AuthorizeRol("PuntoCaja", "Index")]
        public JsonResult Sesiones(int idPuntoCaja)
        {
            var lista = CD_PuntoCaja.Instancia.ObtenerSesiones(idPuntoCaja);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ── JSON — guardar (crear o editar) ───────────────────────────
        [HttpPost]
        [AuthorizeRol("PuntoCaja", "Index")]
        public JsonResult Guardar(int idPuntoCaja, int idTienda, string nombre,
                                   string descripcion, bool activo = true)
        {
            if (!EsSuperAdmin) idTienda = TiendaActiva;

            if (idPuntoCaja == 0)
            {
                var r = CD_PuntoCaja.Instancia.Registrar(idTienda, nombre, descripcion);
                return Json(new { resultado = r.resultado, mensaje = r.mensaje });
            }
            else
            {
                var r = CD_PuntoCaja.Instancia.Actualizar(idPuntoCaja, nombre, descripcion, activo);
                return Json(new { resultado = r.resultado, mensaje = r.mensaje });
            }
        }
    }
}
