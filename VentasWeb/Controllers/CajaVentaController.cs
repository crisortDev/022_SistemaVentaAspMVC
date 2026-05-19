using CapaDatos;
using CapaModelo;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Módulo de Caja de Ventas.
    /// Gestiona apertura, operaciones operación por operación y cierre de caja.
    /// </summary>
    [AuthorizeRol("CajaVenta", "*")]
    public class CajaVentaController : BaseController
    {
        // ============================================================
        //  INDEX — estado actual de la caja
        // ============================================================

        [AuthorizeRol("CajaVenta", "Index")]
        public ActionResult Index()
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            ViewBag.CajaActiva = idTienda > 0
                ? CD_CajaVenta.Instancia.ObtenerCajaActiva(idTienda)
                : null;
            ViewBag.Tiendas = CD_Tienda.Instancia.ObtenerTiendas();
            return View();
        }

        // ============================================================
        //  JSON — ABRIR CAJA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("CajaVenta", "Index")]
        public JsonResult Abrir(decimal montoApertura, int idTienda = 0)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // SuperAdmin elige tienda en el formulario; usuarios normales usan su tienda activa
            if (!EsSuperAdmin)
                idTienda = TiendaActiva;

            if (idTienda == 0)
                return Json(new { resultado = false, mensaje = "Seleccioná una tienda para abrir la caja." });

            var r = CD_CajaVenta.Instancia.AbrirCaja(
                idTienda, UsuarioActual.IdUsuario, montoApertura);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje, idCaja = r.idCaja });
        }

        // ============================================================
        //  REPORTE — operaciones de una caja
        // ============================================================

        [AuthorizeRol("CajaVenta", "Index")]
        public ActionResult Reporte(int idCaja = 0)
        {
            if (idCaja == 0)
            {
                // Si no se pasa idCaja, buscar la caja activa de la tienda
                int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
                if (idTienda > 0)
                {
                    var cajaActiva = CD_CajaVenta.Instancia.ObtenerCajaActiva(idTienda);
                    if (cajaActiva != null)
                        idCaja = cajaActiva.IdCaja;
                }
            }

            ViewBag.IdCaja = idCaja;
            return View();
        }

        // ============================================================
        //  JSON — OBTENER OPERACIONES DE UNA CAJA
        // ============================================================

        [HttpGet]
        [AuthorizeRol("CajaVenta", "Index")]
        public JsonResult ObtenerOperaciones(int idCaja)
        {
            var (operaciones, resumen) = CD_CajaVenta.Instancia.ObtenerOperaciones(idCaja);
            return Json(new { operaciones, resumen }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — CERRAR CAJA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("CajaVenta", "Index")]
        public JsonResult Cerrar(int idCaja, decimal montoContado, string observacion)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            var r = CD_CajaVenta.Instancia.CerrarCaja(
                idCaja, UsuarioActual.IdUsuario, montoContado, observacion);

            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        // ============================================================
        //  JSON — HISTORIAL DE CAJAS
        // ============================================================

        [HttpGet]
        [AuthorizeRol("CajaVenta", "Index")]
        public JsonResult Historial()
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;
            var lista = CD_CajaVenta.Instancia.ObtenerHistorial(idTienda);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
    }
}
