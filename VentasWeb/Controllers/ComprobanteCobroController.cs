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
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

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

            // Pasar el MontoApertura de la caja activa para filtrar formas de pago
            // Apertura = 0  → no puede dar vuelto → solo formas sin efectivo
            // Apertura > 0  → puede dar vuelto → todas las formas habilitadas
            var caja = CD_CajaVenta.Instancia.ObtenerDetalleCaja(CajaId);
            ViewBag.MontoAperturaFondo = caja?.MontoApertura ?? 0m;

            return View();
        }

        [HttpGet]
        [AuthorizeRol("ComprobanteCobro", "Cuentas por Cobrar")]
        public JsonResult ObtenerPendientes(bool soloVencidas = false)
        {
            // Segregación: supervisor solo ve su tienda; superadmin ve todas
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

            var lista = CD_ComprobanteCobro.Instancia
                            .ObtenerCuentasPorCobrar(idTienda, soloVencidas);

            return Json(new { data = lista ?? new List<ComprobanteCobro>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ════════════════════════════════════════════════════════════════════
        //  REGISTRAR COBRO
        //  Cualquier usuario con permiso "Cuentas por Cobrar" puede cobrar:
        //  Cajero (4), Supervisor (11), Admin (1), SuperAdmin (14).
        //  Debe tener caja abierta para que el cobro quede vinculado al turno.
        // ════════════════════════════════════════════════════════════════════

        [HttpPost]
        [AuthorizeRol("ComprobanteCobro", "Cuentas por Cobrar")]
        public JsonResult Cobrar(int idCompCobro, int idFormaCobro,
                                  decimal montoRecibido, string observacion = "")
        {
            var usuario = UsuarioActual;
            if (usuario == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            int idCaja = CajaId;
            if (idCaja == 0)
                return Json(new { resultado = false,
                    mensaje = "Debe tener una caja ABIERTA para registrar cobros. Abra una caja e intente de nuevo." });

            // ── IDs negativos → cuota del nuevo sistema (CUOTA_COBRO_VENTA) ──
            if (idCompCobro < 0)
            {
                int idCuotaCobro = -idCompCobro;
                var rCuota = CD_Venta.Instancia.CobrarCuotaVenta(
                    idCuotaCobro, usuario.IdUsuario, idFormaCobro, montoRecibido, idCaja);
                return Json(new { resultado = rCuota.resultado, mensaje = rCuota.mensaje, idCompCobro = 0 });
            }

            // ── IDs positivos → comprobante del sistema antiguo (COMPROBANTE_COBRO) ──
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

            // ── Aislamiento por sucursal (SuperAdmin pasa) ──
            // TODO: requiere que el SP usp_ObtenerReciboCobro devuelva IdTienda
            // y que el modelo ComprobanteCobro exponga IdTienda. Ver checklist.
            if (!EsAdminGlobal && recibo.IdTienda != 0 && recibo.IdTienda != TiendaActiva)
                return new HttpStatusCodeResult(403, "No tiene permiso para ver un comprobante de otra sucursal.");

            return View(recibo);
        }
    }
}
