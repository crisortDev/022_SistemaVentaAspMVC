using CapaDatos;
using CapaModelo;
using SendGrid;
using SendGrid.Helpers.Mail;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Rol", "*")] // '*' significa todas las vistas/acciones del controlador
    public class RolController : Controller
    {
        // GET: Rol
        public ActionResult Crear()
        {
            return View();
        }

        [HttpGet]
        public async Task<JsonResult> Obtener()
        {
            List<Rol> olista = CD_Rol.Instancia.ObtenerRol();

            //var resultadoCorreo = await ProbarEnvioCorreo();

            return Json(new
            {
                data = olista,
                email = ""
            }, JsonRequestBehavior.AllowGet);
        }



        [HttpPost]
        public JsonResult Guardar(Rol objeto)
        {
            bool respuesta = objeto.IdRol == 0
                ? CD_Rol.Instancia.RegistrarRol(objeto)
                : CD_Rol.Instancia.ModificarRol(objeto);

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }


        [HttpGet]
        public JsonResult ListarPermisosPorRol(int idRol)
        {
            List<Permisos> lista = CD_Permisos.Instancia.ListarPermisosPorRol(idRol);
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }


        [HttpPost]
        public JsonResult Desactivar(int id)
        {
            var resultado = CD_Rol.Instancia.DesactivarRol(id); // retorna (bool resultado, string mensaje)
            return Json(new { resultado = resultado.resultado, mensaje = resultado.mensaje });
        }

        [HttpGet]
        public JsonResult ListPermisosPorRol(int idRol)
        {
            var lista = CD_Permisos.Instancia.ListPermisosPorRol(idRol);

            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
        [HttpPost]
        public JsonResult GuardarRolConPermisos(RolPermiso modelo)
        {
            bool resultado = CD_Rol.Instancia.RegistrarRolConPermisos(modelo);
            return Json(new { resultado }, JsonRequestBehavior.AllowGet);
        }
        [HttpGet]
        public JsonResult ListPermisosDisponibles()
        {
            var lista = CD_Permisos.Instancia.ListarTodosLosPermisos(); // método que devuelve IdSubMenu, NombreMenu, NombreSubMenu
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }
        public async Task<JsonResult> ProbarEnvioCorreo()
        {
            try
            {
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

                var apiKey = "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";
                var client = new SendGridClient(apiKey);

                var from = new EmailAddress("cristian.a.ortega@hotmail.com", "Sistema");
                var to = new EmailAddress("cristian.a.ortega@hotmail.com");

                var msg = MailHelper.CreateSingleEmail(
                    from,
                    to,
                    "Prueba SendGrid",
                    "Correo de prueba",
                    "<strong>Correo de prueba</strong>"
                );

                var response = await client.SendEmailAsync(msg);

                return Json(new
                {
                    ok = true,
                    status = response.StatusCode.ToString()
                }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new
                {
                    ok = false,
                    error = ex.ToString()
                }, JsonRequestBehavior.AllowGet);
            }
        }

    }
}