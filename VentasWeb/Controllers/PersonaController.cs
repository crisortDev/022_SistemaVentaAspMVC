using CapaDatos;
using CapaModelo;
using System;
using System.Linq;
using System.Web.Mvc;
using VentasWeb.Filters;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Persona", "*")] // '*' significa todas las vistas/acciones del controlador
    public class PersonaController : BaseController
    {
        // GET: Persona/Crear
        public ActionResult Crear()
        {
            return View();
        }

        [HttpPost]
        public ActionResult Guardar(Persona model)
        {
            if (model == null)
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            try
            {
                if (model.IdPersona > 0)
                {
                    // 🔁 Actualizar persona existente
                    var resultado = CD_Persona.Instancia.ActualizarPersona(model);
                    return Json(new { resultado = resultado.resultado, mensaje = resultado.mensaje, id = model.IdPersona });
                }
                else
                {
                    // 🆕 Registrar nueva persona
                    var resultado = CD_Persona.Instancia.RegistrarPersona(model);
                    return Json(new { resultado = resultado.resultado, mensaje = resultado.mensaje, id = resultado.idPersona });
                }
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Ocurrió un error: " + ex.Message });
            }
        }


        public ActionResult Obtener()
        {
            var lista = CD_Persona.Instancia.ObtenerPersonas();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }



        // POST: Persona/Eliminar
        [HttpPost]
        public ActionResult Eliminar(int id)
        {
            // Lógica para eliminar
            return Json(new { success = true });
        }
        [HttpPost]
        public ActionResult CambiarEstado(int id, bool activo, bool afectarHijos)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "Id de persona inválido." });

                bool exito = CD_Persona.Instancia.CambiarEstadoPersona(id, activo, afectarHijos);

                if (exito)
                {
                    string mensaje = activo ? "Persona activada correctamente." : "Persona desactivada correctamente.";
                    object advertencias = null;

                    // Si se desactivó, verificar registros pendientes en todos los módulos
                    if (!activo)
                    {
                        var alertas = CD_Persona.Instancia.ObtenerAlertasDesactivacion(id);
                        if (alertas.Count > 0)
                            advertencias = alertas; // lista de strings al JS
                    }

                    return Json(new { resultado = true, mensaje, advertencias });
                }
                else
                    return Json(new { resultado = false, mensaje = "No se pudo cambiar el estado. Verifique que la persona exista." });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Ocurrió un error: " + ex.Message });
            }
        }

        public ActionResult ObtenerPorId(int id)
        {
            var persona = CD_Persona.Instancia.ObtenerPersonaPorId(id);
            return Json(persona, JsonRequestBehavior.AllowGet);
        }
        // GET: Persona/BuscarPorCI?ci=123456
        [HttpGet]
        public ActionResult BuscarPorCI(string ci)
        {
            if (string.IsNullOrEmpty(ci))
                return Json(new { resultado = false, mensaje = "Debe ingresar un CI." }, JsonRequestBehavior.AllowGet);

            try
            {
                // 🔹 Primero verificamos si el CI ya está en Empleado
                bool existeEmpleado = CD_Empleado.Instancia.ExisteEmpleadoPorCI(ci);

                if (existeEmpleado)
                {
                    return Json(new
                    {
                        resultado = false,
                        mensaje = "La persona ya está registrada como empleado."
                    }, JsonRequestBehavior.AllowGet);
                }

                // 🔹 Si no está en Empleado, buscamos en Persona
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

                // 🔹 Verificar si tiene usuario
                bool tieneUsuario = CD_Usuario.Instancia.TieneUsuarioPorEmpleado(persona.IdPersona);
                if (tieneUsuario)
                    return Json(new { resultado = false, mensaje = "La persona ya tiene usuario." }, JsonRequestBehavior.AllowGet);

                // 🔹 Si pasa todo, retornar los datos
                return Json(new { resultado = true, data = persona }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }
    }
}