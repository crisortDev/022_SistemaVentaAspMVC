using CapaDatos;
using CapaModelo;
using System;
using System.Configuration;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    public class LoginController : Controller
    {
        private static readonly string GmailCorreo = ConfigurationManager.AppSettings["GmailCorreo"];
        private static readonly string GmailPassword = ConfigurationManager.AppSettings["GmailPassword"];
        private static readonly string NombreSistema = ConfigurationManager.AppSettings["NombreSistema"] ?? "Sistema de Ventas";

        // ── GET: Index ────────────────────────────────────────
        public ActionResult Index() => View();

        // ── POST: Login ───────────────────────────────────────
        [HttpPost]
        public ActionResult Index(string correo, string clave)
        {
            if (string.IsNullOrEmpty(correo) || string.IsNullOrEmpty(clave))
                return Json(new { success = false, mensaje = "Ingrese correo y contraseña." });

            Usuario usuario = CD_Usuario.Instancia.ObtenerUsuarios()
                .FirstOrDefault(u => u.Correo == correo);

            if (usuario == null)
                return Json(new { success = false, mensaje = "Usuario o contraseña incorrecta." });

            if (!usuario.Activo)
                return Json(new { success = false, mensaje = "Tu cuenta está desactivada. Contactá al administrador." });

            string hashIngresado = GetSHA256(clave);

            // Contraseña temporal vigente
            if (usuario.PasswordTemporalHash != null &&
                usuario.PasswordTemporalExpira.HasValue &&
                usuario.PasswordTemporalExpira > DateTime.Now &&
                usuario.PasswordTemporalHash == hashIngresado)
            {
                usuario.RequiereCambioPassword = true;
                Session["UsuarioCambio"] = usuario;
                return Json(new { success = true, requiereCambio = true });
            }

            // Contraseña temporal expirada
            if (usuario.PasswordTemporalHash != null &&
                usuario.PasswordTemporalExpira.HasValue &&
                usuario.PasswordTemporalExpira <= DateTime.Now &&
                usuario.PasswordTemporalHash == hashIngresado)
            {
                return Json(new { success = false, mensaje = "La contraseña temporal expiró. Contactá al administrador para obtener una nueva." });
            }

            // Contraseña definitiva
            if (usuario.Clave == hashIngresado)
            {
                usuario.FechaUltimoLogin = DateTime.Now;
                CD_Usuario.Instancia.ActualizarUsuario(usuario);
                Session["Usuario"] = CD_Usuario.Instancia.ObtenerDetalleUsuario(usuario.IdUsuario);
                return Json(new { success = true, requiereCambio = false });
            }

            return Json(new { success = false, mensaje = "Usuario o contraseña incorrecta." });
        }

        // ── GET: CambiarPassword ──────────────────────────────
        public ActionResult CambiarPassword() => View();

        // ── POST: CambiarPassword (primer login o tras recuperación) ──
        [HttpPost]
        public ActionResult CambiarPassword(string nuevaClave)
        {
            Usuario usuarioSession = (Usuario)Session["UsuarioCambio"];
            if (usuarioSession == null)
                return Json(new { success = false, mensaje = "Sesión expirada. Volvé a iniciar sesión." });

            if (string.IsNullOrEmpty(nuevaClave))
                return Json(new { success = false, mensaje = "Ingrese la nueva contraseña." });

            string nuevaClaveHash = GetSHA256(nuevaClave);

            // Buscar el usuario FRESCO desde BD para tener Clave actualizada
            Usuario usuarioBD = CD_Usuario.Instancia.ObtenerUsuarios()
                .FirstOrDefault(u => u.IdUsuario == usuarioSession.IdUsuario);

            if (usuarioBD == null)
                return Json(new { success = false, mensaje = "No se encontró el usuario." });

            // No puede ser igual a la temporal activa
            if (usuarioBD.PasswordTemporalHash == nuevaClaveHash)
                return Json(new { success = false, mensaje = "La nueva contraseña no puede ser igual a la contraseña temporal." });

            // No puede ser igual a la clave actual en BD
            if (!string.IsNullOrEmpty(usuarioBD.Clave) && usuarioBD.Clave == nuevaClaveHash)
                return Json(new { success = false, mensaje = "La nueva contraseña no puede ser igual a tu contraseña actual." });

            // No puede estar en las últimas 3 del historial
            if (CD_HistorialClaves.Instancia.ClaveYaUsada(usuarioBD.IdUsuario, nuevaClaveHash))
                return Json(new { success = false, mensaje = "No podés reutilizar una de tus últimas 3 contraseñas. Elegí una diferente." });

            // Guardar clave ACTUAL de BD en historial antes de cambiarla
            if (!string.IsNullOrEmpty(usuarioBD.Clave))
                CD_HistorialClaves.Instancia.GuardarEnHistorial(usuarioBD.IdUsuario, usuarioBD.Clave);

            // Cambiar y limpiar temporal
            CD_Usuario.Instancia.CambiarClave(usuarioBD.IdUsuario, nuevaClave);
            usuarioBD.RequiereCambioPassword = false;
            usuarioBD.PasswordTemporalHash = null;
            usuarioBD.PasswordTemporalExpira = null;
            usuarioBD.FechaUltimoLogin = DateTime.Now;
            CD_Usuario.Instancia.ActualizarUsuario(usuarioBD);

            Session["Usuario"] = CD_Usuario.Instancia.ObtenerDetalleUsuario(usuarioBD.IdUsuario);
            Session.Remove("UsuarioCambio");

            return Json(new { success = true });
        }

        // ── POST: RecuperarPassword (olvidé mi contraseña) ────
        [HttpPost]
        public ActionResult RecuperarPassword(string correo)
        {
            if (string.IsNullOrEmpty(correo))
                return Json(new { success = false, mensaje = "Ingresá tu correo." });

            try
            {
                Usuario usuario = CD_Usuario.Instancia.ObtenerUsuarios()
                    .FirstOrDefault(u => u.Correo == correo && u.Activo);

                // Respuesta genérica por seguridad
                if (usuario == null)
                    return Json(new { success = true, mensaje = "Si el correo está registrado, recibirás una contraseña temporal en breve." });

                // ── Guardar clave actual en historial ANTES de generar la temporal ──
                // Esto garantiza que al cambiar la nueva clave, la anterior quede bloqueada
                if (!string.IsNullOrEmpty(usuario.Clave))
                    CD_HistorialClaves.Instancia.GuardarEnHistorial(usuario.IdUsuario, usuario.Clave);

                // Generar contraseña temporal
                string claveTemp = GenerarClaveTemporal();
                string claveTempHash = GetSHA256(claveTemp);

                // Actualizar usuario con la temporal
                usuario.PasswordTemporalHash = claveTempHash;
                usuario.PasswordTemporalExpira = DateTime.Now.AddHours(24);
                usuario.RequiereCambioPassword = true;
                usuario.FechaUltimoLogin = DateTime.MinValue;
                CD_Usuario.Instancia.ActualizarUsuario(usuario);

                // Enviar correo
                string asunto = $"Recuperación de acceso — {NombreSistema}";
                string html = ConstruirCorreoRecuperacion(usuario.Nombres, correo, claveTemp);
                EnviarCorreo(correo, asunto, html);

                return Json(new { success = true, mensaje = "Te enviamos una contraseña temporal a tu correo. Revisá también la carpeta de spam." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = "Ocurrió un error al procesar la solicitud." });
            }
        }

        // ── Helpers privados ──────────────────────────────────
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
            var smtp = new SmtpClient
            {
                Host = "smtp.gmail.com",
                Port = 587,
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(GmailCorreo, GmailPassword)
            };

            using (var message = new MailMessage(
                new MailAddress(GmailCorreo, NombreSistema),
                new MailAddress(destinatario))
            {
                Subject = asunto,
                Body = htmlBody,
                IsBodyHtml = true
            })
            {
                smtp.Send(message);
            }
        }

        private string ConstruirCorreoRecuperacion(string nombres, string correo, string claveTemp)
        {
            return $@"
            <div style='font-family:Arial,sans-serif;max-width:500px;margin:auto;border:1px solid #dee2e6;border-radius:8px;overflow:hidden'>
                <div style='background:#0d0d0d;padding:20px;text-align:center'>
                    <h2 style='color:#fff;margin:0'>{NombreSistema}</h2>
                </div>
                <div style='padding:30px'>
                    <p>Hola <strong>{nombres}</strong>,</p>
                    <p>Recibimos una solicitud de recuperación de acceso para tu cuenta.</p>
                    <table style='width:100%;border-collapse:collapse;margin:20px 0'>
                        <tr>
                            <td style='padding:8px;background:#f8f9fa;font-weight:bold;width:40%'>Usuario (correo)</td>
                            <td style='padding:8px;border-bottom:1px solid #dee2e6'>{correo}</td>
                        </tr>
                        <tr>
                            <td style='padding:8px;background:#f8f9fa;font-weight:bold'>Contraseña temporal</td>
                            <td style='padding:8px;font-size:22px;font-weight:bold;letter-spacing:4px;color:#c8522a'>{claveTemp}</td>
                        </tr>
                    </table>
                    <div style='background:#fff3cd;border:1px solid #ffc107;border-radius:4px;padding:12px;margin-top:10px'>
                        <strong>⚠ Importante:</strong> Esta contraseña expira en <strong>24 horas</strong>.
                        Al ingresar se te pedirá que la cambies por una nueva.
                    </div>
                    <p style='margin-top:16px;font-size:13px;color:#6c757d'>
                        Si no solicitaste esto, ignorá este correo. Tu contraseña anterior sigue siendo válida.
                    </p>
                </div>
                <div style='background:#f8f9fa;padding:15px;text-align:center;font-size:12px;color:#6c757d'>
                    Este es un correo automático, por favor no respondas.
                </div>
            </div>";
        }
    }
}