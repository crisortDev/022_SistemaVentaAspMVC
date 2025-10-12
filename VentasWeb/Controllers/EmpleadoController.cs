using CapaDatos;
using CapaModelo;
using System;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Empleado", "*")] // '*' significa todas las vistas/acciones del controlador
    public class EmpleadoController : Controller
    {
        // GET: Persona/Crear
        public ActionResult Crear()
        {
            return View();
        }

        // POST: Empleado/Guardar
        [HttpPost]
        public ActionResult Guardar(Empleado model)
        {
            if (model == null)
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            bool exito = false;
            string mensaje = "";
            int idGenerado = 0;

            try
            {
                if (model.IdEmpleado > 0)
                {
                    // Actualizar empleado existente
                    exito = CD_Empleado.Instancia.ActualizarEmpleado(model);
                    mensaje = exito ? "Empleado actualizado correctamente." : "No se pudo actualizar el empleado.";
                    idGenerado = model.IdEmpleado;
                }
                else
                {
                    // Registrar nuevo empleado
                    var resultado = CD_Empleado.Instancia.RegistrarEmpleado(model);
                    exito = resultado.resultado;
                    mensaje = resultado.mensaje;
                    idGenerado = resultado.idEmpleado;
                }
            }
            catch (Exception ex)
            {
                exito = false;
                mensaje = "Ocurrió un error: " + ex.Message;
            }

            return Json(new { resultado = exito, mensaje = mensaje, id = idGenerado });
        }

        // GET: Empleado/Obtener
        public ActionResult Obtener()
        {
            var lista = CD_Empleado.Instancia.ObtenerEmpleados();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // POST: Empleado/CambiarEstado
        [HttpPost]
        public ActionResult CambiarEstado(int id, bool activo)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "Id de empleado inválido." });

                bool exito = CD_Empleado.Instancia.CambiarEstadoEmpleado(id, activo);

                if (exito)
                    return Json(new { resultado = true, mensaje = activo ? "Empleado activado correctamente." : "Empleado desactivado correctamente." });
                else
                    return Json(new { resultado = false, mensaje = "No se pudo cambiar el estado. Verifique que el empleado exista y no tenga registros asociados." });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Ocurrió un error: " + ex.Message });
            }
        }

        // GET: Empleado/ObtenerPorId?id=1
        public ActionResult ObtenerPorId(int id)
        {
            var empleado = CD_Empleado.Instancia.ObtenerEmpleadoPorId(id);
            return Json(empleado, JsonRequestBehavior.AllowGet);
        }



        // POST: Persona/Eliminar
        [HttpPost]
        public ActionResult Eliminar(int id)
        {
            // Lógica para eliminar
            return Json(new { success = true });
        }
        // GET: Buscar persona por CI (solo físicas)
        [HttpGet]
        public ActionResult BuscarPorCI(string ci)
        {
            if (string.IsNullOrEmpty(ci))
                return Json(new { resultado = false, mensaje = "Debe ingresar un CI." }, JsonRequestBehavior.AllowGet);

            try
            {
                var persona = CD_Persona.Instancia.ObtenerPersonas()
                    .Where(p => p.Documento == ci && p.TipoDocumento == "CI")
                    .Select(p => new
                    {
                        p.IdPersona,
                        p.Documento,
                        p.Nombres,
                        p.Apellidos,
                        p.Correo,
                        p.Telefono
                    })
                    .FirstOrDefault();

                if (persona == null)
                    return Json(new { resultado = false, mensaje = "No se encontró la persona." }, JsonRequestBehavior.AllowGet);

                // Verificar si es empleado
                bool esEmpleado = CD_Empleado.Instancia.EsEmpleado(persona.IdPersona);
                //if (!esEmpleado)
                //    return Json(new { resultado = false, mensaje = "Solo empleados pueden tener usuario." }, JsonRequestBehavior.AllowGet);

                // Verificar si ya tiene usuario
                bool yaTieneUsuario = CD_Usuario.Instancia.TieneUsuarioPorEmpleado(persona.IdPersona);
                if (yaTieneUsuario)
                    return Json(new { resultado = false, mensaje = "La persona ya tiene usuario." }, JsonRequestBehavior.AllowGet);

                return Json(new { resultado = true, data = persona }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        [HttpGet]
        public JsonResult BuscarPersonaPorDocumento(string documento)
        {
            try
            {
                // Buscar persona por documento usando ADO
                var persona = CD_Persona.Instancia.BuscarPorDocumento(documento);

                if (persona == null)
                {
                    return Json(new
                    {
                        existe = false,
                        mensaje = "La persona no está registrada. Por favor, vaya a Persona/Crear."
                    }, JsonRequestBehavior.AllowGet);
                }

                // Verificar si ya es empleado
                bool esEmpleado = CD_Empleado.Instancia.EsEmpleado(persona.IdPersona);

                if (esEmpleado)
                {
                    // Obtener datos del empleado
                    var emp = CD_Empleado.Instancia.ObtenerIdEmpleadoPorPersona(persona.IdPersona);
                    var empleado = CD_Empleado.Instancia.ObtenerEmpleadoPorId(emp);

                    return Json(new
                    {
                        existe = true,
                        esEmpleado = true,
                        data = empleado
                    }, JsonRequestBehavior.AllowGet);
                }
                else
                {
                    return Json(new
                    {
                        existe = true,
                        esEmpleado = false,
                        data = persona
                    }, JsonRequestBehavior.AllowGet);
                }
            }
            catch (Exception ex)
            {
                return Json(new { existe = false, mensaje = "Error: " + ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }
        [HttpGet]
        public JsonResult ObtenerTiendasActivas()
        {
            try
            {
                var lista = CD_Tienda.Instancia.ObtenerTiendasActivas(); // Tu capa de datos de Tienda
                return Json(lista, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

    }
}