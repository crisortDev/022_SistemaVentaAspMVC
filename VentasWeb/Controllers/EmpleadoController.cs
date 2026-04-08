using CapaDatos;
using CapaModelo;
using System;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Empleado", "*")]
    public class EmpleadoController : Controller
    {
        // GET: Empleado/Crear
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
                    exito = CD_Empleado.Instancia.ActualizarEmpleado(model);
                    mensaje = exito ? "Empleado actualizado correctamente." : "No se pudo actualizar el empleado.";
                    idGenerado = model.IdEmpleado;
                }
                else
                {
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

        // POST: Empleado/CambiarEstado — Borrado lógico
        // Activa o desactiva el empleado. Nunca elimina el registro.
        [HttpPost]
        public ActionResult CambiarEstado(int id, bool activo)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "Id de empleado inválido." });

                bool exito = CD_Empleado.Instancia.CambiarEstadoEmpleado(id, activo);
                string mensaje = activo ? "Empleado activado correctamente." : "Empleado desactivado correctamente.";

                return exito
                    ? Json(new { resultado = true, mensaje = mensaje })
                    : Json(new { resultado = false, mensaje = "No se pudo cambiar el estado del empleado." });
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

        // GET: Buscar persona por CI
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
                var persona = CD_Persona.Instancia.BuscarPorDocumento(documento);

                if (persona == null)
                    return Json(new { existe = false, mensaje = "La persona no está registrada." }, JsonRequestBehavior.AllowGet);

                bool esEmpleado = CD_Empleado.Instancia.EsEmpleado(persona.IdPersona);

                if (esEmpleado)
                {
                    var emp = CD_Empleado.Instancia.ObtenerIdEmpleadoPorPersona(persona.IdPersona);
                    var empleado = CD_Empleado.Instancia.ObtenerEmpleadoPorId(emp);
                    return Json(new { existe = true, esEmpleado = true, data = empleado }, JsonRequestBehavior.AllowGet);
                }
                else
                {
                    return Json(new { existe = true, esEmpleado = false, data = persona }, JsonRequestBehavior.AllowGet);
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
                var lista = CD_Tienda.Instancia.ObtenerTiendasActivas();
                return Json(lista, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ELIMINADO: La acción Eliminar física fue removida.
        // El borrado lógico se maneja completamente a través de CambiarEstado.
    }
}