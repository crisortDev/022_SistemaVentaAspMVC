using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    public static class EmailHelper
    {
        public static bool EnviarOTP(string correo, string otp)
        {
            try
            {
                SmtpClient client = new SmtpClient("smtp.tuservidor.com", 587)
                {
                    Credentials = new NetworkCredential("tuemail@dominio.com", "tuPassword"),
                    EnableSsl = true
                };

                MailMessage mail = new MailMessage();
                mail.From = new MailAddress("tuemail@dominio.com");
                mail.To.Add(correo);
                mail.Subject = "Código OTP";
                mail.Body = $"Tu código OTP es: {otp}";

                client.Send(mail);

                return true; // OTP enviado correctamente
            }
            catch (Exception)
            {
                return false; // Error al enviar OTP
            }
        }

    }

}
