using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    public class VentaController : BaseController
    {
        // NOTA: este controller ya NO tiene [AuthorizeRol] a nivel de clase.
        // Antes exigía "Venta|*" para TODAS las acciones, incluyendo lookups
        // de solo lectura (productos con stock, clientes, formas de cobro) que
        // también usa la pantalla de Pre-venta (módulo OrdenVenta). Eso bloqueaba
        // al Repositor —que no tiene permisos de "Venta", solo de "OrdenVenta"—
        // al intentar cargar una pre-venta ("Acceso denegado" en los combos de
        // producto/cliente). Cada acción sensible ya tiene su propio
        // [AuthorizeRol] específico; los lookups de solo lectura quedan
        // abiertos a cualquier usuario con sesión iniciada (VerificarSession
        // global ya exige login).
        // ============================================================
        //  VISTAS
        // ============================================================

        /// <summary>Pantalla de venta directa (Cajero hace todo en un paso).</summary>
        [AuthorizeRol("Venta", "Registrar Venta Directa")]
        public ActionResult Crear()
        {
            if (UsuarioActual == null) return RedirectToAction("Index", "Login");
            ViewBag.DatosTributarios = CD_Venta.Instancia.ObtenerDatosTributarios();
            return View();
        }

        /// <summary>Pantalla de cobro/facturación desde una pre-venta.</summary>
        [AuthorizeRol("OrdenVenta", "Consultar Pre-ventas")]
        public ActionResult Facturar(int idOrdenVenta = 0)
        {
            if (UsuarioActual == null) return RedirectToAction("Index", "Login");
            if (idOrdenVenta == 0) return RedirectToAction("Consultar", "OrdenVenta");

            // ── Repositor no puede facturar ───────────────────────────────────
            if (UsuarioActual.IdRol == 7)
            {
                TempData["Error"] = "Tu rol (Repositor) no tiene permiso para facturar pre-ventas. Solicitá a un Cajero o Administrador.";
                return RedirectToAction("Consultar", "OrdenVenta");
            }

            // ── Control: debe tener una caja ABIERTA para poder facturar ──
            if (CajaId == 0)
            {
                TempData["MensajeCaja"] = "Debe abrir una caja antes de facturar la pre-venta.";
                return RedirectToAction("Index", "CajaVenta");
            }

            var ov = CD_OrdenVenta.Instancia.ObtenerDetalleOrdenVenta(idOrdenVenta);
            if (ov == null || ov.Estado != "Pendiente")
                return RedirectToAction("Consultar", "OrdenVenta");

            // ── MontoApertura de la caja activa (para lógica de fondo) ────────
            var caja = CD_CajaVenta.Instancia.ObtenerDetalleCaja(CajaId);
            ViewBag.MontoAperturaFondo = caja?.MontoApertura ?? 0m;

            ViewBag.DatosTributarios = CD_Venta.Instancia.ObtenerDatosTributarios();
            return View(ov);
        }

        /// <summary>Lista de ventas (consulta general).</summary>
        [AuthorizeRol("Venta", "Consultar Ventas")]
        public ActionResult Consultar()
        {
            return View();
        }

        /// <summary>Documento KuDE (factura electrónica Paraguay).</summary>
        [AuthorizeRol("Venta", "*")]
        public ActionResult Documento(int idVenta = 0)
        {
            Venta oVenta = CD_Venta.Instancia.ObtenerDetalleVenta_v2(idVenta);
            if (oVenta == null)
                return HttpNotFound();

            // ── Aislamiento por sucursal (SuperAdmin pasa) ──
            if (!TienePermiso(oVenta.oTienda?.IdTienda ?? 0))
                return new HttpStatusCodeResult(403, "No tiene permiso para ver un comprobante de otra sucursal.");

            return View(oVenta);
        }

        // ============================================================
        //  JSON — DATOS TRIBUTARIOS
        // ============================================================

        [HttpGet]
        [AuthorizeRol("Venta", "*")]
        public JsonResult ObtenerDatosTributarios()
        {
            var dt = CD_Venta.Instancia.ObtenerDatosTributarios();
            if (dt == null)
                return Json(new { resultado = false, mensaje = "No hay timbrado vigente." },
                            JsonRequestBehavior.AllowGet);
            return Json(new { resultado = true, datos = dt }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — VENTA DIRECTA
        // ============================================================

        [HttpPost]
        [ValidateInput(false)]
        [AuthorizeRol("Venta", "Registrar Venta Directa")]
        public JsonResult GuardarVentaDirecta(
            int idCliente, int idFormaCobro,
            decimal importeRecibido, string detalleXml)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(detalleXml))
                return Json(new { resultado = false, mensaje = "Debe agregar al menos un producto." });

            // Usar la tienda operativa: caja activa > TiendaActiva > 1 (central)
            int idTiendaVenta = TiendaOperativa;

            var r = CD_Venta.Instancia.RegistrarVentaDirecta(
                idTiendaVenta,
                UsuarioActual.IdUsuario,
                idCliente > 0 ? (int?)idCliente : null,
                idFormaCobro,
                importeRecibido,
                detalleXml,
                CajaId);   // vincula la venta a la caja del cajero

            return Json(new
            {
                resultado      = r.resultado,
                mensaje        = r.mensaje,
                idVenta        = r.idVenta,
                numeroFactura  = r.numeroFactura,
                urlDocumento   = r.resultado
                    ? Url.Action("Documento", "Venta", new { idVenta = r.idVenta })
                    : ""
            });
        }

        // ============================================================
        //  JSON — FACTURAR DESDE PRE-VENTA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("OrdenVenta", "Consultar Pre-ventas")]
        public JsonResult FacturarDesdeOV(
            int idOrdenVenta, int idCliente,
            int idFormaCobro, decimal importeRecibido,
            string condicion = "Contado", int? plazoCredito = null)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            // ── Repositor no puede facturar ────────────────────────────────────
            if (UsuarioActual.IdRol == 7)
                return Json(new { resultado = false, mensaje = "Tu rol (Repositor) no tiene permiso para facturar. Solicitá a un Cajero o Administrador." });

            // Control: debe haber una caja abierta para este cajero antes de facturar
            int idCajaActual = CajaId;
            if (idCajaActual == 0)
                return Json(new { resultado = false, mensaje = "Debe abrir una caja antes de facturar." });

            var r = CD_Venta.Instancia.FacturarDesdeOrdenVenta(
                idOrdenVenta,
                UsuarioActual.IdUsuario,
                idCliente > 0 ? (int?)idCliente : null,
                idFormaCobro,
                importeRecibido,
                idCajaActual,       // vincula la venta a la caja del cajero
                condicion,
                plazoCredito,
                UsuarioActual.IdRol);  // para la segregación de funciones

            return Json(new
            {
                resultado     = r.resultado,
                mensaje       = r.mensaje,
                idVenta       = r.idVenta,
                numeroFactura = r.numeroFactura,
                urlDocumento  = r.resultado
                    ? Url.Action("Documento", "Venta", new { idVenta = r.idVenta })
                    : ""
            });
        }

        // ============================================================
        //  JSON — LISTAR VENTAS
        // ============================================================

        [HttpGet]
        [AuthorizeRol("Venta", "Consultar Ventas")]
        public JsonResult Obtener(
            string fechainicio = "", string fechafin = "",
            string numerofactura = "", string documentocliente = "",
            string nombrecliente = "", string tipoflujo = "", string estado = "")
        {
            int idTienda = EsAdminGlobal ? 0 : TiendaActiva;

            DateTime fi = ParseFecha(fechainicio, DateTime.Today.AddDays(-30));
            DateTime ff = ParseFecha(fechafin,   DateTime.Today);

            var lista = CD_Venta.Instancia.ObtenerListaVenta_v2(
                idTienda, fi, ff, numerofactura, documentocliente,
                nombrecliente, tipoflujo, estado);

            return Json(new { data = lista ?? new List<Venta>() },
                        JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — ANULAR VENTA
        // ============================================================

        [HttpPost]
        [AuthorizeRol("Venta", "Anular")]
        public JsonResult Anular(int idVenta, string motivo)
        {
            if (UsuarioActual == null)
                return Json(new { resultado = false, mensaje = "Sesión expirada." });

            if (string.IsNullOrWhiteSpace(motivo))
                return Json(new { resultado = false, mensaje = "Debe ingresar el motivo de anulación." });

            var r = CD_Venta.Instancia.AnularVenta(idVenta, UsuarioActual.IdUsuario, motivo);
            return Json(new { resultado = r.resultado, mensaje = r.mensaje });
        }

        // ============================================================
        //  JSON — PRODUCTOS CON STOCK EN LA TIENDA (para selector)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerProductoStockPorTienda(int idtienda = 0, bool soloConStock = true)
        {
            if (!EsAdminGlobal) idtienda = TiendaActiva;
            var todos = CD_ProductoTienda.Instancia.ObtenerProductoTienda()
                        ?? new System.Collections.Generic.List<CapaModelo.ProductoTienda>();
            var lista = todos.FindAll(p =>
                (idtienda == 0 || (p.oTienda != null && p.oTienda.IdTienda == idtienda))
                && (!soloConStock || p.Stock > 0));
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — CLIENTES (para autocompletar en el selector)
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerClientes()
        {
            var lista = CD_Cliente.Instancia.ObtenerClientes()
                        ?? new System.Collections.Generic.List<CapaModelo.Cliente>();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ============================================================
        //  JSON — FORMAS DE COBRO
        // ============================================================

        [HttpGet]
        public JsonResult ObtenerFormasCobro()
        {
            var lista = CD_Venta.Instancia.ObtenerFormasCobro();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ── Helper: parsea fechas dd/MM/yyyy enviadas por el datepicker ──
        private static DateTime ParseFecha(string valor, DateTime fallback)
        {
            if (string.IsNullOrWhiteSpace(valor)) return fallback;
            DateTime resultado;
            if (DateTime.TryParseExact(valor, "dd/MM/yyyy",
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out resultado))
                return resultado;
            return DateTime.TryParse(valor, out resultado) ? resultado : fallback;
        }
    }
}
