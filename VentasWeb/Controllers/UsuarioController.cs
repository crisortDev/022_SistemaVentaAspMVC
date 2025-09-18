using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using VentasWeb.Filters;
using VentasWeb.Utilidades;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Usuario", "*")] // '*' significa todas las vistas/acciones del controlador
    public class UsuarioController : Controller
    {
        // GET: Usuario
        public ActionResult Crear()
        {
            return View();
        }

        public JsonResult Obtener()
        {
            List<Usuario> oListaUsuario = CD_Usuario.Instancia.ObtenerUsuarios();
            return Json(new { data = oListaUsuario }, JsonRequestBehavior.AllowGet);
        }

        [HttpPost]
        public JsonResult Guardar(Usuario objeto)
        {
            bool respuesta = false;
            ResultadoSP resultadoFinal;

            // 1. Verificar si existe el empleado por CI
            Empleado emp = CD_Empleado.Instancia.ObtenerEmpleadoPorCI(objeto.CI);

            if (emp == null)
            {
                // 2. Si no existe, registrar empleado
                emp = new Empleado()
                {
                    CI = objeto.CI,
                    Nombres = objeto.Nombres,
                    Apellidos = objeto.Apellidos,
                    IdTienda = objeto.IdTienda,
                    Activo = objeto.Activo
                };

                var registroEmpleado = CD_Empleado.Instancia.RegistrarEmpleado(emp, objeto.Correo);

                if (!registroEmpleado.resultado)
                {
                    return Json(new { resultado = false, mensaje = registroEmpleado.mensaje }, JsonRequestBehavior.AllowGet);
                }

                // ✅ Solo si se registró bien, asignamos el ID generado
                objeto.IdEmpleado = registroEmpleado.idEmpleado;
            }
            else
            {
                // ✅ Si ya existía, usamos el IdEmpleado recuperado
                objeto.IdEmpleado = emp.IdEmpleado;
            }

            // 3. Registrar o modificar usuario asociado al empleado
            if (objeto.IdUsuario == 0)
            {
                objeto.Clave = Encriptar.GetSHA256(objeto.Clave);
                resultadoFinal = CD_Usuario.Instancia.RegistrarUsuario(objeto);

                return Json(new
                {
                    resultado = resultadoFinal.Resultado,
                    codigo = resultadoFinal.Codigo,
                    mensaje = resultadoFinal.Mensaje
                }, JsonRequestBehavior.AllowGet);
            }
            else
            {
                respuesta = CD_Usuario.Instancia.ModificarUsuario(objeto);
            }

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }



        [HttpGet]
        public JsonResult Eliminar(int id = 0)
        {
            bool respuesta = CD_Usuario.Instancia.EliminarUsuario(id);

            return Json(new { resultado = respuesta }, JsonRequestBehavior.AllowGet);
        }
        [HttpPost]
        public JsonResult CambiarClave(int idUsuario, string nuevaClave)
        {
            bool resultado = CD_Usuario.Instancia.CambiarClave(idUsuario, nuevaClave);
            return Json(new { resultado = resultado }, JsonRequestBehavior.AllowGet);
        }
        // GET: Usuario/CambioContraseña
        public ActionResult CambioContraseña()
        {
            return View(); // Busca /Views/Usuario/CambioContraseña.cshtml
        }

        // POST: Usuario/CambioContraseña
        [HttpPost]
        public JsonResult CambioContraseña(string claveActual, string claveNueva)
        {
            bool resultado = false;
            string mensaje = "";

            // Obtener usuario de la sesión
            Usuario usuarioSesion = (Usuario)Session["Usuario"];
            if (usuarioSesion == null)
            {
                mensaje = "Sesión expirada. Por favor ingrese nuevamente.";
                return Json(new { resultado, mensaje });
            }

            Usuario usuario = CD_Usuario.Instancia.ObtenerDetalleUsuario(usuarioSesion.IdUsuario);
            if (usuario == null)
            {
                mensaje = "Usuario no encontrado.";
                return Json(new { resultado, mensaje });
            }

            // Validar clave actual
            string claveActualEncriptada = Encriptar.GetSHA256(claveActual);
            if (usuario.Clave != claveActualEncriptada)
            {
                mensaje = "La contraseña actual es incorrecta.";
                return Json(new { resultado, mensaje });
            }

            // Cambiar clave
            resultado = CD_Usuario.Instancia.CambiarClave(usuario.IdUsuario, claveNueva);

            mensaje = resultado ? "Contraseña actualizada correctamente." : "Error al actualizar la contraseña.";
            return Json(new { resultado, mensaje });
        }
    }
}