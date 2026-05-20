using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Cliente", "*")]
    public class ClienteController : BaseController
    {
        [AuthorizeRol("Cliente", "Crear")]
        public ActionResult Crear()
        {
            return View();
        }

        [AuthorizeRol("Cliente", "Crear")]
        public JsonResult Obtener()
        {
            List<Cliente> oListaCliente = CD_Cliente.Instancia.ObtenerClientes();
            return Json(new { data = oListaCliente }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        [AuthorizeRol("Cliente", "Crear")]
        public JsonResult Guardar(Cliente objeto)
        {
            if (objeto == null)
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            bool respuesta = objeto.IdCliente == 0
                ? CD_Cliente.Instancia.RegistrarCliente(objeto)
                : CD_Cliente.Instancia.ModificarCliente(objeto);

            return Json(new { resultado = respuesta, mensaje = respuesta ? "OK" : "No se pudo guardar." });
        }

        [HttpGet]
        [AuthorizeRol("Cliente", "Crear")]
        public JsonResult Eliminar(int id = 0)
        {
            bool respuesta = CD_Cliente.Instancia.EliminarCliente(id);
            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }
    }
}