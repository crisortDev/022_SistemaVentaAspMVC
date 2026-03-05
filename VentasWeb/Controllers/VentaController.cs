using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class VentaController : Controller
    {
        private static Usuario SesionUsuario;
        // GET: Venta
        public ActionResult Crear()
        {
            SesionUsuario = (Usuario)Session["Usuario"];
            return View();
        }

        // GET: Venta
        public ActionResult Consultar()
        {
            return View();
        }

        public ActionResult Documento(int IdVenta = 0)
        {
            Venta oVenta = CD_Venta.Instancia.ObtenerDetalleVenta(IdVenta);

            if (oVenta == null)
                oVenta = new Venta();
            else
            {
                // Calcular el total con IVA
                oVenta.ImporteTotalIvaIncluido = oVenta.oListaDetalleVenta.Sum(x => x.ImporteTotalIvaIncluido);

                // El resto de la lógica para la venta
                oVenta.oListaDetalleVenta = (from dv in oVenta.oListaDetalleVenta
                                             select new DetalleVenta()
                                             {
                                                 Cantidad = dv.Cantidad,
                                                 NombreProducto = dv.NombreProducto,
                                                 PrecioUnidad = dv.PrecioUnidad,
                                                 ImporteTotal = dv.ImporteTotal,
                                                 ImporteTotalIvaIncluido = dv.ImporteTotalIvaIncluido
                                             }).ToList();

                oVenta.ImporteRecibido = oVenta.ImporteRecibido;
                oVenta.ImporteCambio = oVenta.ImporteCambio;
                oVenta.TotalCosto = oVenta.TotalCosto;
            }

            return View(oVenta);
        }



        public JsonResult Obtener(string codigo, string fechainicio, string fechafin, string numerodocumento, string nombres)
        {
            List<Venta> lista = CD_Venta.Instancia.ObtenerListaVenta(codigo, Convert.ToDateTime(fechainicio), Convert.ToDateTime(fechafin), numerodocumento, nombres);


            if (lista == null)
                lista = new List<Venta>();

            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }


        public JsonResult ObtenerUsuario()
        {
            Usuario rptUsuario = CD_Usuario.Instancia.ObtenerDetalleUsuario(SesionUsuario.IdUsuario);
            return Json(rptUsuario, JsonRequestBehavior.AllowGet);
        }

        public JsonResult ObtenerProductoPorTienda(int IdTienda)
        {

            List<ProductoTienda> oListaProductoTienda = CD_ProductoTienda.Instancia.ObtenerProductoTienda();
            oListaProductoTienda = oListaProductoTienda.Where(x => x.oTienda.IdTienda == IdTienda && x.Stock > 0).ToList();


            return Json(new { data = oListaProductoTienda }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult ControlarStock(int idproducto, int idtienda, int cantidad, bool restar)
        {
            // Llama al método de la capa de negocio que maneja la lógica del stock
            string respuesta = CD_ProductoTienda.Instancia.ControlarStock(idproducto, idtienda, cantidad, restar);

            // Retorna el mensaje como un JSON con la clave 'resultado'
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }


        [HttpPost]
        public JsonResult Guardar(string xml)
        {
            int numeroTimbrado = 123456;
            string fechaStr = "31/03/2026"; // La fecha en formato "dd/MM/yyyy"
            DateTime fechaVencimientoTimbrado = DateTime.ParseExact(fechaStr, "dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture);

            bool registroFactura = CD_Venta.Instancia.RegistrarSecuenciaFactura(numeroTimbrado, fechaVencimientoTimbrado);
            xml = xml.Replace("!idusuario¡", SesionUsuario.IdUsuario.ToString());
            int Respuesta = 0;
            Respuesta = CD_Venta.Instancia.RegistrarVenta(xml);
            if (Respuesta != 0)
                return Json(new { estado = true, valor = Respuesta.ToString() }, JsonRequestBehavior.AllowGet);
            else
                return Json(new { estado = false, valor = "" }, JsonRequestBehavior.AllowGet);
        }
    }
}