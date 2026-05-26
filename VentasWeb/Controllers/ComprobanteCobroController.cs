using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("ComprobanteCobro", "*")]
    public class ComprobanteCobroController : BaseController
    {
        // ════════════════════════════════════════════════════════════════════
        //  HISTORIAL DE COMPROBANTES (contado cobrado + crédito cobrado)
        // ════════════════════════════════════════════════════════════════════

        [AuthorizeRol("ComprobanteCobro", "Comprobantes de Cobro")]
        public ActionResult Index()
        {
            return View();
        }

        [HttpGet]
        [AuthorizeRol("ComprobanteCobro", "Comprobantes de Cobro")]
        public JsonResult Obtener(string fechainicio = "", string fechafin = "")
        {
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;

            DateTime fi = string.IsNullOrWhiteSpace(fechainicio)
                ? DateTime.Today.AddDays(-30) : Convert.ToDateTime(fechainicio);
            DateTime ff = string.IsNullOrWhiteSpace(fechafin)
                ? DateTime.Today : Convert.ToDateTime(fechafin);

            var lista = CD_ComprobanteCobro.Instancia
                            .ObtenerListaComprobanteCobro(idTienda, fi, ff);

            return Json(new { data = lista ?? new List<ComprobanteCobro>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ════════════════════════════════════════════════════════════════════
        //  CUENTAS POR COBRAR — lista de créditos pendientes
        // ════════════════════════════════════════════════════════════════════

        [AuthorizeRol("ComprobanteCobro", "Cuentas por Cobrar")]
        public ActionResult CuentasPorCobrar()
        {
            // Cargar formas de cobro para el modal de cobrar
            ViewBag.FormasCobro = CD_Venta.Instancia.ObtenerFormasCobro();
            return View();
        }

        [HttpGet]
        [AuthorizeRol("ComprobanteCobro", "Cuentas por Cobrar")]
        public JsonResult ObtenerPendientes(bool soloVencidas = false)
        {
            // Segregación: supervisor solo ve su tienda; superadmin ve todas
            int idTienda = EsSuperAdmin ? 0 : TiendaActiva;

            var lista = CD_ComprobanteCobro.Instancia
                            .ObtenerCuentasPorCobrar(idTienda, soloVencidas);

            return Json(new { data = lista ?? new List<ComprobanteCobro>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ════════════════════════════════════════════════════════════════════
        //  REGISTRAR COBRO (Supervisor / Admin únicamente)
        //  Segregación de funciones: el CAJERO NO puede cobrar cuentas a crédito.
        //  Solo SUPERVISOR (IdRol 7) y SUPERADMIN (IdRol 14) tienen acceso.
        // ════════════════════════════════════════════════════════════════════

        [HttpPost]
        [AuthorizeRol("ComprobanteCobro", "Cuentas por Cobrar")]
        public JsonResult Cobrar(int idCompCobro, int idFormaCobro,
                                  decimal montoRecibido, string observacion = "")
        {
            // Verificar rol: solo supervisor o superadmin pueden cobrar
            var usuario = UsuarioActual;
            if (usuario == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // IdRol 4 = CAJERO → no puede cobrar cuentas a crédito
            if (usuario.IdRol == 4)
                return Json(new { resultado = false,
                    mensaje = "El cajero no puede registrar cobros de facturas a crédito. Contactá al supervisor." });

            // Obtener caja activa del turno (puede ser 0 si no hay caja abierta)
            int idCaja = CajaId;

            var (resultado, mensaje, idComp) = CD_ComprobanteCobro.Instancia.CobrarCuenta(
                idCompCobro,
                idCaja,
                usuario.IdUsuario,
                idFormaCobro,
                montoRecibido,
                observacion);

            return Json(new { resultado, mensaje, idCompCobro = idComp });
        }

        // ════════════════════════════════════════════════════════════════════
        //  RECIBO DE COBRO — vista imprimible (sin layout)
        // ════════════════════════════════════════════════════════════════════

        [HttpGet]
        [AuthorizeRol("ComprobanteCobro", "*")]
        public ActionResult Documento(int idCompCobro = 0)
        {
            if (idCompCobro <= 0)
                return HttpNotFound();

            var recibo = CD_ComprobanteCobro.Instancia.ObtenerReciboCobro(idCompCobro);
            if (recibo == null)
                return HttpNotFound();

            return View(recibo);
        }
    }
}
