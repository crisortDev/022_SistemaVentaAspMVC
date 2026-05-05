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
using System.Xml.XPath;
using System.Xml.Serialization;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Compra", "*")]
    public partial class CompraController : BaseController
    {
        public ActionResult Crear()
        {
            var usuario = (Usuario)Session["Usuario"];
            ViewBag.IdUsuario = usuario?.IdUsuario;
            return View();
        }

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

        public ActionResult Documento(int idcompra = 0)
        {
            Compra oCompra = CD_Compra.Instancia.ObtenerDetalleCompra(idcompra);
            if (oCompra == null)
                oCompra = new Compra();

            return View(oCompra);
        }

        public JsonResult Obtener(string fechainicio, string fechafin, int idproveedor, int idtienda)
        {
            // ── Si no es SuperAdmin, forzar su propia tienda ──────
            if (!EsSuperAdmin)
                idtienda = TiendaActiva;

            List<Compra> lista = CD_Compra.Instancia.ObtenerListaCompra(
                Convert.ToDateTime(fechainicio),
                Convert.ToDateTime(fechafin),
                idproveedor,
                idtienda
            );
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Guardar(string xml)
        {
            try
            {
                var SesionUsuario = (Usuario)Session["Usuario"];
                if (SesionUsuario == null)
                    return Json(new { resultado = false, error = "La sesión ha expirado. Por favor inicie sesión nuevamente." });

                xml = xml.Replace("!idusuario¡", SesionUsuario.IdUsuario.ToString());

                var serializer = new XmlSerializer(typeof(ValidaStockMaximo.DetalleRoot));
                ValidaStockMaximo.DetalleRoot detalleRoot;

                using (var reader = new StringReader(xml))
                {
                    detalleRoot = (ValidaStockMaximo.DetalleRoot)serializer.Deserialize(reader);
                }

                // ── Validar permiso por sucursal ──────────────────
                if (!TienePermiso(detalleRoot.Compra.IdTienda))
                    return Json(new { resultado = false, error = "No tiene permisos para registrar compras en esta sucursal." });

                string validacionStock = CD_Compra.Instancia.ValidaStockMaximo(
                    detalleRoot.DetalleCompra.Detalle.IdProducto,
                    detalleRoot.DetalleCompra.Detalle.Cantidad,
                    detalleRoot.Compra.IdTienda
                );

                var partes = validacionStock.Split(new[] { ',' }, 2);

                if (partes.Length < 2)
                    return Json(new { resultado = false, error = "Formato inválido: falta la coma" });

                if (!int.TryParse(partes[0], out int codigoResultado))
                    return Json(new { resultado = false, error = "Código no es un número" });

                string mensaje = partes[1].Trim();

                switch (codigoResultado)
                {
                    case 1:
                        // ── Registrar la compra y obtener su ID ──────────────────
                        int idCompra = CD_Compra.Instancia.RegistrarCompraRetornarId(xml);

                        if (idCompra > 0)
                        {
                            // ── Extraer IdOrdenCompra y detalles del XML ────────────────────
                            try
                            {
                                XDocument xDoc = XDocument.Parse(xml);
                                XElement compraElement = xDoc.Element("DETALLE")?.Element("COMPRA");

                                if (compraElement != null)
                                {
                                    int idOrdenCompra = 0;
                                    XElement idOCElement = compraElement.Element("IdOrdenCompra");

                                    if (idOCElement != null && int.TryParse(idOCElement.Value, out int oc))
                                    {
                                        idOrdenCompra = oc;
                                    }

                                    // ── Si existe Orden de Compra, procesar ──────────────
                                    if (idOrdenCompra > 0)
                                    {
                                        // 🆕 ACTUALIZAR CantidadFacturada en DetalleOrdenCompra
                                        var detalles = xDoc.XPathSelectElements("//DETALLE_COMPRA/DETALLE");
                                        foreach (var detalle in detalles)
                                        {
                                            int idDetalleOrdenCompra = 0;
                                            int cantidadFacturada = 0;

                                            // Extraer IdDetalleOrdenCompra y Cantidad
                                            if (int.TryParse(detalle.Element("IdDetalleOrdenCompra")?.Value, out int ocDetailId))
                                                idDetalleOrdenCompra = ocDetailId;

                                            if (int.TryParse(detalle.Element("Cantidad")?.Value, out int qty))
                                                cantidadFacturada = qty;

                                            // Actualizar en BD
                                            if (idDetalleOrdenCompra > 0 && cantidadFacturada > 0)
                                            {
                                                bool actualizado = CD_Compra.Instancia.ActualizarCantidadFacturada(
                                                    idDetalleOrdenCompra,
                                                    cantidadFacturada,
                                                    out string mensajeActualizacion
                                                );

                                                if (!actualizado)
                                                {
                                                    System.Diagnostics.Debug.WriteLine(
                                                        $"Advertencia: No se pudo actualizar CantidadFacturada para detalle {idDetalleOrdenCompra}: {mensajeActualizacion}"
                                                    );
                                                }
                                            }
                                        }

                                        // ── Vincular Compra con Orden de Compra ────────────────
                                        bool vinculoExitoso = CD_Compra.Instancia.VincularCompraConOrdenCompra(
                                            idCompra,
                                            idOrdenCompra,
                                            out string mensajeVinculo
                                        );

                                        if (!vinculoExitoso)
                                        {
                                            System.Diagnostics.Debug.WriteLine(
                                                $"Advertencia: No se pudo vincular Compra {idCompra} con OC {idOrdenCompra}: {mensajeVinculo}"
                                            );
                                        }
                                    }
                                }
                            }
                            catch (Exception exVinculo)
                            {
                                System.Diagnostics.Debug.WriteLine(
                                    $"Error al procesar vinculación: {exVinculo.Message}"
                                );
                            }

                            return Json(new { resultado = true, idCompra = idCompra });
                        }
                        else
                        {
                            return Json(new { resultado = false, error = "No se pudo obtener el ID de la compra registrada." });
                        }

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