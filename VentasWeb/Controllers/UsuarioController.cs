using CapaDatos;
using CapaModelo;
using System;
using System.Configuration;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class UsuarioController : Controller
    {
        // ── Constantes leídas desde Web.config ───────────────────
        private static readonly string GmailCorreo = ConfigurationManager.AppSettings["GmailCorreo"];
        private static readonly string GmailPassword = ConfigurationManager.AppSettings["GmailPassword"];
        private static readonly string NombreSistema = ConfigurationManager.AppSettings["NombreSistema"] ?? "Sistema de Ventas";

        // GET: Usuario/Crear
        public ActionResult Crear() => View();

        // ── GET: DataTable ────────────────────────────────────────
        // Clave: _ObtenerUsuarios → Usuario/Obtener
        public ActionResult Obtener()
        {
            var lista = CD_Usuario.Instancia.ObtenerUsuarios();
            return Json(new { data = lista }, JsonRequestBehavior.AllowGet);
        }

        // ── GET: Buscar empleado por CI/RUC ───────────────────────
        // Clave: _BuscarEmpleadoPorCI → Usuario/BuscarEmpleadoPorCI
        [HttpGet]
        public ActionResult BuscarEmpleadoPorCI(string ci)
        {
            if (string.IsNullOrEmpty(ci))
                return Json(new { existe = false, mensaje = "Ingrese un CI." }, JsonRequestBehavior.AllowGet);

            try
            {
                var persona = CD_Persona.Instancia.ObtenerPersonas()
                    .Find(p => p.Documento == ci);

                if (persona == null)
                    return Json(new { existe = false, mensaje = "No se encontró la persona." }, JsonRequestBehavior.AllowGet);

                bool yaTieneUsuario = CD_Usuario.Instancia.TieneUsuarioPorEmpleado(persona.IdPersona);
                if (yaTieneUsuario)
                    return Json(new { existe = false, mensaje = "Este empleado ya tiene un usuario asignado." }, JsonRequestBehavior.AllowGet);

                bool esEmpleado = CD_Empleado.Instancia.EsEmpleado(persona.IdPersona);
                int idEmpleado = esEmpleado
                    ? CD_Empleado.Instancia.ObtenerIdEmpleadoPorPersona(persona.IdPersona)
                    : 0;

                int idTienda = 0;
                if (idEmpleado > 0)
                {
                    var emp = CD_Empleado.Instancia.ObtenerEmpleadoPorId(idEmpleado);
                    idTienda = emp != null ? emp.IdTienda : 0;
                }

                return Json(new
                {
                    existe = true,
                    esEmpleado = esEmpleado,
                    data = new
                    {
                        IdEmpleado = idEmpleado,
                        Nombres = persona.Nombres,
                        Apellidos = persona.Apellidos,
                        Documento = persona.Documento,
                        Correo = persona.Correo,
                        Telefono = persona.Telefono,
                        IdTienda = idTienda
                    }
                }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { existe = false, mensaje = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // ── POST: Crear usuario + enviar contraseña temporal ──────
        // Clave: _CrearUsuarioPendiente → Usuario/CrearUsuarioPendiente
        [HttpPost]
        public ActionResult CrearUsuarioPendiente(Usuario model)
        {
            if (model == null)
                return Json(new { resultado = false, mensaje = "Datos inválidos." });

            try
            {
                if (model.IdEmpleado <= 0)
                    return Json(new { resultado = false, mensaje = "Debe asociar un empleado." });
                if (string.IsNullOrEmpty(model.Correo))
                    return Json(new { resultado = false, mensaje = "El correo es obligatorio." });
                if (model.IdRol <= 0)
                    return Json(new { resultado = false, mensaje = "Debe seleccionar un rol." });
                if (model.IdTienda <= 0)
                    return Json(new { resultado = false, mensaje = "Debe seleccionar una tienda." });

                // Completar datos desde el empleado
                var empleado = CD_Empleado.Instancia.ObtenerEmpleadoPorId(model.IdEmpleado);
                if (empleado == null)
                    return Json(new { resultado = false, mensaje = "No se encontró el empleado." });

                model.Nombres = empleado.Nombres;
                model.Apellidos = empleado.Apellidos;

                // ── Generar contraseña temporal legible (8 chars) ─
                string claveTemp = GenerarClaveTemporal();
                string claveTempHash = GetSHA256(claveTemp);

                // La Clave que va al SP es el hash (lo que queda en BD como clave de login)
                model.Clave = claveTempHash;

                // Registrar en BD
                var res = CD_Usuario.Instancia.RegistrarUsuario(model);
                if (!res.Resultado)
                    return Json(new { resultado = false, mensaje = res.Mensaje });

                // Guardar hash temporal y expiración (24 hs) en Usuario
                var usuarioCreado = new Usuario
                {
                    IdUsuario = res.Codigo, // SP devuelve el IdUsuario en Codigo=1 cuando es OK
                    PasswordTemporalHash = claveTempHash,
                    PasswordTemporalExpira = DateTime.Now.AddHours(24),
                    RequiereCambioPassword = true,
                    IntentosFallidos = 0,
                    FechaUltimoLogin = DateTime.MinValue
                };
                CD_Usuario.Instancia.ActualizarUsuario(usuarioCreado);

                // ── Enviar correo con la contraseña temporal ──────
                string asunto = $"Bienvenido a {NombreSistema} — Tus credenciales de acceso";
                string html = ConstruirCorreoBienvenida(model.Nombres, model.Correo, claveTemp);
                EnviarCorreo(model.Correo, asunto, html);

                return Json(new { resultado = true, mensaje = "Usuario creado correctamente. Se envió la contraseña temporal al correo registrado." });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Ocurrió un error: " + ex.Message });
            }
        }

        // ── POST: Activar / Desactivar usuario ────────────────────
        // Clave: _CambiarEstadoUsuario → Usuario/CambiarEstadoUsuario
        [HttpPost]
        public ActionResult CambiarEstadoUsuario(int id, bool activo)
        {
            try
            {
                if (id <= 0)
                    return Json(new { resultado = false, mensaje = "Id de usuario inválido." });

                bool exito = CD_Usuario.Instancia.CambiarEstadoUsuario(id, activo);
                return Json(new
                {
                    resultado = exito,
                    mensaje = exito
                        ? (activo ? "Usuario activado correctamente." : "Usuario desactivado correctamente.")
                        : "No se pudo cambiar el estado del usuario."
                });
            }
            catch (Exception ex)
            {
                return Json(new { resultado = false, mensaje = "Ocurrió un error: " + ex.Message });
            }
        }

        // ══════════════════════════════════════════════════════════
        //  HELPERS PRIVADOS
        // ══════════════════════════════════════════════════════════

        /// <summary>
        /// Genera una contraseña temporal legible de 8 caracteres.
        /// Esta es la que el usuario recibe por correo y usa para su primer login.
        /// </summary>
        private string GenerarClaveTemporal(int length = 8)
        {
            const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
            using (var rng = new RNGCryptoServiceProvider())
            {
                var data = new byte[length];
                rng.GetBytes(data);
                var sb = new StringBuilder(length);
                foreach (byte b in data)
                    sb.Append(chars[b % chars.Length]);
                return sb.ToString();
            }
        }

        private string GetSHA256(string input)
        {
            using (SHA256 sha = SHA256.Create())
            {
                byte[] bytes = Encoding.UTF8.GetBytes(input);
                byte[] hash = sha.ComputeHash(bytes);
                var sb = new StringBuilder();
                foreach (byte b in hash)
                    sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }

        private void EnviarCorreo(string destinatario, string asunto, string htmlBody)
        {
            var fromAddress = new MailAddress(GmailCorreo, NombreSistema);
            var toAddress = new MailAddress(destinatario);

            var smtp = new SmtpClient
            {
                Host = "smtp.gmail.com",
                Port = 587,
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(GmailCorreo, GmailPassword)
            };

            using (var message = new MailMessage(fromAddress, toAddress)
            {
                Subject = asunto,
                Body = htmlBody,
                IsBodyHtml = true
            })
            {
                smtp.Send(message);
            }
        }

        private string ConstruirCorreoBienvenida(string nombres, string correo, string claveTemp)
        {
            return $@"
            <div style='font-family:Arial,sans-serif;max-width:500px;margin:auto;border:1px solid #dee2e6;border-radius:8px;overflow:hidden'>
                <div style='background:#17a2b8;padding:20px;text-align:center'>
                    <h2 style='color:#fff;margin:0'>{NombreSistema}</h2>
                </div>
                <div style='padding:30px'>
                    <p>Hola <strong>{nombres}</strong>,</p>
                    <p>Tu cuenta ha sido creada exitosamente. Estas son tus credenciales de acceso:</p>
                    <table style='width:100%;border-collapse:collapse;margin:20px 0'>
                        <tr>
                            <td style='padding:8px;background:#f8f9fa;font-weight:bold;width:40%'>Usuario (correo)</td>
                            <td style='padding:8px;border-bottom:1px solid #dee2e6'>{correo}</td>
                        </tr>
                        <tr>
                            <td style='padding:8px;background:#f8f9fa;font-weight:bold'>Contraseña temporal</td>
                            <td style='padding:8px;font-size:20px;font-weight:bold;letter-spacing:3px;color:#17a2b8'>{claveTemp}</td>
                        </tr>
                    </table>
                    <div style='background:#fff3cd;border:1px solid #ffc107;border-radius:4px;padding:12px;margin-top:10px'>
                        <strong>⚠ Importante:</strong> Esta contraseña expira en <strong>24 horas</strong>.
                        Al ingresar por primera vez se te pedirá que la cambies.
                    </div>
                </div>
                <div style='background:#f8f9fa;padding:15px;text-align:center;font-size:12px;color:#6c757d'>
                    Este es un correo automático, por favor no respondas.
                </div>
            </div>";
        }
    }
}