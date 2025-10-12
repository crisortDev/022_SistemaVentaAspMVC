using CapaDatos;
using CapaModelo;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.Services.Description;
using VentasWeb.Filters;
using VentasWeb.Utilidades;

namespace VentasWeb.Controllers
{
    [AuthorizeRol("Usuario", "*")]
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
            Empleado emp = CD_Empleado.Instancia.BuscarEmpleadosPorCI(objeto.CI).FirstOrDefault();

            if (emp == null)
            {
                // 2. Si no existe, registrar empleado
                emp = new Empleado()
                {
                    Documento = objeto.CI,
                    Nombres = objeto.Nombres,
                    Apellidos = objeto.Apellidos,
                    IdTienda = objeto.IdTienda,
                    Activo = objeto.Activo
                };

                int idGenerado = CD_Empleado.Instancia.RegistrarDesdeApp(emp);

                if (idGenerado <= 0)
                {
                    return Json(new { resultado = false, mensaje = "Error al registrar el empleado" }, JsonRequestBehavior.AllowGet);
                }

                objeto.IdEmpleado = idGenerado; // asignamos ID generado
            }
            else
            {
                objeto.IdEmpleado = emp.IdEmpleado; // usar el que ya existe
            }

            // 3. Registrar o modificar usuario asociado
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

        public ActionResult CambioContraseña()
        {
            return View();
        }

        [HttpPost]
        public JsonResult CambioContraseña(string claveActual, string claveNueva)
        {
            bool resultado = false;
            string mensaje = "";

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

            string claveActualEncriptada = Encriptar.GetSHA256(claveActual);
            if (usuario.Clave != claveActualEncriptada)
            {
                mensaje = "La contraseña actual es incorrecta.";
                return Json(new { resultado, mensaje });
            }

            resultado = CD_Usuario.Instancia.CambiarClave(usuario.IdUsuario, claveNueva);
            mensaje = resultado ? "Contraseña actualizada correctamente." : "Error al actualizar la contraseña.";

            return Json(new { resultado, mensaje });
        }

        // 🚀 NUEVO: endpoint directo para registrar empleados desde la app
        [HttpPost]
        public JsonResult GuardarEmpleado(Empleado emp)
        {
            bool resultado = false;
            string mensaje = "";

            try
            {
                if (emp.IdEmpleado == 0)
                {
                    int idGenerado = CD_Empleado.Instancia.RegistrarDesdeApp(emp);
                    resultado = idGenerado > 0;
                    mensaje = resultado ? "Empleado registrado correctamente." : "Error al registrar empleado.";
                }
                else
                {
                    resultado = CD_Empleado.Instancia.ModificarDesdeApp(emp);
                    mensaje = resultado ? "Empleado actualizado correctamente." : "Error al actualizar empleado.";
                }
            }
            catch (Exception ex)
            {
                mensaje = "Excepción: " + ex.Message;
            }

            return Json(new { resultado, mensaje }, JsonRequestBehavior.AllowGet);
        }
        [HttpGet]
        public JsonResult BuscarEmpleadoPorCI(string ci)
        {
            var lista = CD_Empleado.Instancia.BuscarEmpleadosPorCI(ci)
                         .Select(e => new { e.IdEmpleado, e.Documento, e.Nombres, e.Apellidos })
                         .ToList();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);

        }
        [HttpPost]
        public JsonResult GuardarUsuario(string documento, string correo, int idRol, int idTienda, string clave)
        {
            var resultado = CD_Usuario.Instancia.RegistrarUsuario(documento, correo, idRol, idTienda, clave);

            return Json(new
            {
                tipo = resultado.TipoMensaje,
                mensaje = resultado.Mensaje,
                idUsuario = resultado.IdUsuario,
                otp = resultado.OTP,
                expira = resultado.Expira
            }, JsonRequestBehavior.AllowGet);
        }
        [HttpGet]
        public JsonResult ObtenerUsuarios()
        {
            try
            {
                // Simulación de obtención de usuarios desde base de datos
                var lista = new List<object>
            {
                new { IdUsuario = 1, Nombres = "Juan", Apellidos = "Pérez", CI = "123456", Correo = "juan@mail.com", IdRol = 1, IdTienda = 1, Activo = true, oRol = new { Descripcion = "Admin" } },
                new { IdUsuario = 2, Nombres = "Ana", Apellidos = "Gómez", CI = "789012", Correo = "ana@mail.com", IdRol = 2, IdTienda = 1, Activo = false, oRol = new { Descripcion = "Usuario" } }
            };

                return Json(new { resultado = true, data = lista }, JsonRequestBehavior.AllowGet);
            }
            catch
            {
                return Json(new { resultado = false, data = new List<object>() }, JsonRequestBehavior.AllowGet);
            }
        }
        [HttpPost]
        public JsonResult CrearUsuario(int idEmpleado, string correo, int idRol, int idTienda)
        {
            try
            {
                // 1. Verificar que el empleado exista
                var empleado = CD_Empleado.Instancia.ObtenerEmpleadoPorId(idEmpleado);
                if (empleado == null)
                    return Json(new { resultado = false, mensaje = "Empleado no encontrado." }, JsonRequestBehavior.AllowGet);

                // 2. Verificar si ya tiene usuario
                bool yaTieneUsuario = CD_Usuario.Instancia.TieneUsuario(idEmpleado);
                if (yaTieneUsuario)
                    return Json(new { resultado = false, mensaje = "El empleado ya tiene un usuario registrado." }, JsonRequestBehavior.AllowGet);

                // 3. Generar clave temporal y OTP
                string claveTemporal = GenerarClaveTemporal(); // Ej: función que genera 6-8 caracteres
                string otp = GenerarOTP(); // Ej: función que genera código de 6 dígitos
                DateTime expira = DateTime.Now.AddMinutes(10); // OTP válido por 10 minutos

                // 4. Registrar usuario temporal
                var usuario = new Usuario()
                {
                    IdEmpleado = idEmpleado,
                    Correo = correo,
                    IdRol = idRol,
                    IdTienda = idTienda,
                    Clave = Encriptar.GetSHA256(claveTemporal),
                    Activo = false, // Se activa cuando confirma OTP
                    OTP = otp,
                    ExpiraOTP = expira
                };

                int idUsuario = CD_Usuario.Instancia.RegistrarUsuarioTemporal(usuario, out otp);

                // 5. Enviar OTP por correo
                string mensaje;
                bool enviado = EmailHelper.EnviarOTP(usuario.Correo, otp);

                return Json(new
                {
                    resultado = true,
                    mensaje = "Usuario registrado correctamente. Se envió OTP al correo.",
                    idUsuario = idUsuario,
                    otp = otp,
                    claveTemporal = claveTemporal,
                    expira = expira
                }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // Funciones de utilidad (puedes implementarlas en algún Helper)
        private string GenerarClaveTemporal()
        {
            // Ejemplo: 8 caracteres alfanuméricos
            var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
            var random = new Random();
            return new string(Enumerable.Repeat(chars, 8)
              .Select(s => s[random.Next(s.Length)]).ToArray());
        }

        private string GenerarOTP()
        {
            var random = new Random();
            return random.Next(100000, 999999).ToString(); // 6 dígitos
        }
        [HttpPost]
        public JsonResult CrearUsuarioPendiente(string ciEmpleado, int idRol, int idTienda)
        {
            // 1. Buscar persona
            var persona = CD_Persona.Instancia.ObtenerPersonas()
                             .FirstOrDefault(p => p.Documento == ciEmpleado && p.TipoDocumento == "CI");

            if (persona == null)
                return Json(new { resultado = false, mensaje = "No existe persona física con ese CI." });

            int idEmpleado;

            // 2. Validar si ya es empleado
            bool esEmpleado = CD_Empleado.Instancia.EsEmpleado(persona.IdPersona);
            if (!esEmpleado)
            {
                // Registrar empleado
                Empleado emp = new Empleado
                {
                    Documento = persona.Documento,
                    Nombres = persona.Nombres,
                    Apellidos = persona.Apellidos,
                    IdTienda = idTienda,
                    Activo = true
                };
                emp.IdEmpleado = CD_Empleado.Instancia.RegistrarDesdeApp(emp);
                idEmpleado = emp.IdEmpleado;
            }
            else
            {
                // Obtener el empleado existente
                idEmpleado = CD_Empleado.Instancia.ObtenerIdEmpleadoPorPersona(persona.IdPersona);
            }

            // 3. Validar si ya tiene usuario
            bool yaTieneUsuario = CD_Usuario.Instancia.TieneUsuario(idEmpleado);
            if (yaTieneUsuario)
                return Json(new { resultado = false, mensaje = "El empleado ya tiene usuario." });

            // 4. Crear usuario pendiente
            Usuario usuario = new Usuario
            {
                IdEmpleado = idEmpleado,
                Correo = persona.Correo,
                NombreUsuario = persona.Documento,
                IdRol = idRol,
                IdTienda = idTienda
            };

            string otp;
            int idUsuario = CD_Usuario.Instancia.RegistrarUsuarioPendiente(usuario, out otp);

            // 5. Enviar OTP por correo
            EmailHelper.EnviarOTP(usuario.Correo, otp);

            return Json(new { resultado = true, mensaje = "Usuario pendiente creado. OTP enviado al correo." });
        }

    }
}
