using CapaDatos;
using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Xml.Linq;
using System.Xml.Serialization;

namespace VentasWeb.Controllers
{
    public class CompraController : Controller
    {
        private static Usuario SesionUsuario;
        // GET: Compra
        public ActionResult Crear()
        {
            SesionUsuario = (Usuario)Session["Usuario"];
            return View();
        }
        // GET: Compra
        public ActionResult Consultar()
        {
            return View();
        }
        [HttpGet]
        public JsonResult ObtenerProveedores()
        {
            List<Proveedor> lista = CD_Proveedor.Instancia.ObtenerProveedor();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
        public ActionResult Documento(int idcompra = 0) {
            
            Compra oCompra = CD_Compra.Instancia.ObtenerDetalleCompra(idcompra);

            if (oCompra == null) {
                oCompra = new Compra();
            }


            return View(oCompra);
        }


        public JsonResult Obtener(string fechainicio, string fechafin, int idproveedor, int idtienda)
        {
            List<Compra> lista = CD_Compra.Instancia.ObtenerListaCompra(Convert.ToDateTime(fechainicio), Convert.ToDateTime(fechafin), idproveedor, idtienda);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
        [HttpPost]
        public JsonResult Guardar(string xml)
        {
            try
            {
                xml = xml.Replace("!idusuario¡", SesionUsuario.IdUsuario.ToString());

                var serializer = new XmlSerializer(typeof(ValidaStockMaximo.DetalleRoot));
                ValidaStockMaximo.DetalleRoot detalleRoot;

                using (var reader = new StringReader(xml))
                {
                    detalleRoot = (ValidaStockMaximo.DetalleRoot)serializer.Deserialize(reader);
                }

                string validacionStock = CD_Compra.Instancia.ValidaStockMaximo(
                    detalleRoot.DetalleCompra.Detalle.IdProducto,
                    detalleRoot.DetalleCompra.Detalle.Cantidad,
                    detalleRoot.Compra.IdTienda
                );

                // Dividir solo en la primera coma
                var partes = validacionStock.Split(new[] { ',' }, 2);

                if (partes.Length < 2)
                {
                    return Json(new { resultado = false, error = "Formato inválido: falta la coma" });
                }

                if (!int.TryParse(partes[0], out int codigoResultado))
                {
                    return Json(new { resultado = false, error = "Código no es un número" });
                }

                string mensaje = partes[1].Trim(); // Elimina espacios al inicio/final

                switch (codigoResultado)
                {
                    case 1:
                        bool registroExitoso = CD_Compra.Instancia.RegistrarCompra(xml);
                        return Json(new { resultado = registroExitoso });

                    case 0:
                    case 3:
                        return Json(new { resultado = false, error = mensaje });

                    case -1:
                        return Json(new { resultado = false, error = mensaje });

                    default:
                        return Json(new { resultado = false, error = $"Error desconocido ({codigoResultado}): {mensaje}" });
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error: {ex.Message}");
                return Json(new { resultado = false, error = ex.Message });
            }
        }

        [HttpGet]
        public JsonResult ObtenerHistorialPrecio(int idproducto)
        {
            try
            {
                List<HistorialPrecioCompra> lista = CD_Compra.Instancia.ObtenerHistorialPrecioCompra(idproducto);

                return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { data = new List<HistorialPrecioCompra>(), error = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

    }
}