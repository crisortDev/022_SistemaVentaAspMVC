using System;
using System.Net;
using System.Net.Mail;

class Program
{
    static void Main()
    {
        try
        {
            // Configurá tu cuenta de Gmail
            string gmailUser = "tiantega@gmail.com";
            string gmailAppPassword = "bsem snjj wgck gqju"; // 16 dígitos

            MailMessage mail = new MailMessage();
            mail.From = new MailAddress(gmailUser, "Mi Sistema");
            mail.To.Add("clauorte2006@gmail.com");  // destinatario
            mail.Subject = "Correo de prueba desde .NET 4.8";
            mail.Body = "¡Hola! Este es un correo de prueba usando Gmail SMTP.";

            SmtpClient smtp = new SmtpClient("smtp.gmail.com", 587);
            smtp.EnableSsl = true;
            smtp.Credentials = new NetworkCredential(gmailUser, gmailAppPassword);
            smtp.Send(mail);

            Console.WriteLine("Correo enviado correctamente!");
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error al enviar: " + ex.Message);
        }
    }
}
