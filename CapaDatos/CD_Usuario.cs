using CapaModelo;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace CapaDatos
{
    public class ResultadoRegistroUsuario
    {
        public int IdUsuario { get; set; }
        public string OTP { get; set; }
        public DateTime Expira { get; set; }
        public string TipoMensaje { get; set; }
        public string Mensaje { get; set; }
    }

    public class CD_Usuario
    {
        public static CD_Usuario _instancia = null;
        private CD_Usuario() { }
        public static CD_Usuario Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Usuario();
                return _instancia;
            }
        }

        // =================== MÉTODOS AUXILIARES ===================

        // Pepper: valor secreto almacenado en Web.config (no en la BD).
        // Protege contra ataques de rainbow table si la BD es comprometida.
        private static readonly string _pepper =
            ConfigurationManager.AppSettings["PasswordPepper"] ?? string.Empty;

        private string GetSHA256(string str)
        {
            using (SHA256 sha256 = SHA256.Create())
            {
                // Concatenar pepper antes de hashear
                byte[] bytes = Encoding.UTF8.GetBytes(str + _pepper);
                byte[] hash = sha256.ComputeHash(bytes);
                StringBuilder sb = new StringBuilder();
                foreach (byte b in hash)
                    sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }

        private string GenerarPasswordTemporal(int length = 8)
        {
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
            Random random = new Random();
            return new string(Enumerable.Repeat(chars, length)
                .Select(s => s[random.Next(s.Length)]).ToArray());
        }

        private string GenerarOTP()
        {
            Random rnd = new Random();
            return rnd.Next(100000, 999999).ToString();
        }

        // =================== LOGIN / OBTENER USUARIOS ===================
        public List<Usuario> ObtenerUsuarios()
        {
            List<Usuario> rptListaUsuario = new List<Usuario>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerUsuario", oConexion)
                { CommandType = CommandType.StoredProcedure };

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        Usuario u = new Usuario
                        {
                            IdUsuario = Convert.ToInt32(dr["IdUsuario"]),
                            Nombres = dr["Nombres"].ToString(),
                            Apellidos = dr["Apellidos"].ToString(),
                            Correo = dr["Correo"].ToString(),
                            Clave = dr["Clave"].ToString(),
                            IdTienda = dr["IdTienda"] != DBNull.Value ? Convert.ToInt32(dr["IdTienda"]) : (int?)null,
                            IdRol = Convert.ToInt32(dr["IdRol"]),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            // FechaRegistro: necesario para calcular expiración de contraseña
                            FechaRegistro = dr["FechaRegistro"] != DBNull.Value ? Convert.ToDateTime(dr["FechaRegistro"]) : DateTime.Now,
                            // IntentosFallidos: CRÍTICO — sin esto el contador siempre arranca en 0
                            IntentosFallidos = dr["IntentosFallidos"] != DBNull.Value ? Convert.ToInt32(dr["IntentosFallidos"]) : 0,
                            PasswordTemporalHash = dr["PasswordTemporalHash"] != DBNull.Value ? dr["PasswordTemporalHash"].ToString() : null,
                            RequiereCambioPassword = dr["RequiereCambioPassword"] != DBNull.Value && dr["RequiereCambioPassword"].ToString() == "1",
                            PasswordTemporalExpira = dr["PasswordTemporalExpira"] != DBNull.Value ? Convert.ToDateTime(dr["PasswordTemporalExpira"]) : (DateTime?)null,
                            FechaCambioPassword = dr["FechaCambioPassword"] != DBNull.Value ? Convert.ToDateTime(dr["FechaCambioPassword"]) : (DateTime?)null,
                            FechaUltimoLogin = dr["FechaUltimoLogin"] != DBNull.Value ? Convert.ToDateTime(dr["FechaUltimoLogin"]) : DateTime.MinValue,
                            oRol = new Rol()
                            {
                                Descripcion = dr["DescripcionRol"] != DBNull.Value ? dr["DescripcionRol"].ToString() : ""
                            }
                        };
                        rptListaUsuario.Add(u);
                    }
                    dr.Close();
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("ObtenerUsuarios ERROR: " + ex.Message);
                }
            }
            return rptListaUsuario;
        }

        // ── Helpers para parsear XML de FOR XML PATH ──────────────
        private static string XVal(XElement node, string name)
        {
            var el = node?.Element(name);
            return el != null ? el.Value : null;
        }
        private static int? XValInt(XElement node, string name)
        {
            var v = XVal(node, name);
            return !string.IsNullOrWhiteSpace(v) && int.TryParse(v, out int r) ? r : (int?)null;
        }
        private static DateTime? XValDate(XElement node, string name)
        {
            var v = XVal(node, name);
            return !string.IsNullOrWhiteSpace(v) && DateTime.TryParse(v, out DateTime d) ? d : (DateTime?)null;
        }

        public Usuario ObtenerDetalleUsuario(int IdUsuario)
        {
            Usuario rptUsuario = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleUsuario", oConexion)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@IdUsuario", IdUsuario);

                try
                {
                    oConexion.Open();
                    using (XmlReader dr = cmd.ExecuteXmlReader())
                    {
                        if (dr.Read())
                        {
                            XDocument doc = XDocument.Load(dr);
                            var usuarioNode = doc.Element("Usuario");
                            if (usuarioNode != null)
                            {
                                rptUsuario = new Usuario
                                {
                                    IdUsuario          = int.Parse(usuarioNode.Element("IdUsuario").Value),
                                    Nombres            = XVal(usuarioNode, "Nombres"),
                                    Apellidos          = XVal(usuarioNode, "Apellidos"),
                                    Correo             = XVal(usuarioNode, "Correo"),
                                    Clave              = XVal(usuarioNode, "Clave"),
                                    IdTienda           = XValInt(usuarioNode, "IdTienda"),
                                    IdRol              = int.Parse(usuarioNode.Element("IdRol").Value),
                                    Activo             = XVal(usuarioNode, "Activo") == "1",
                                    FechaRegistro      = XValDate(usuarioNode, "FechaRegistro") ?? DateTime.Now,
                                    PasswordTemporalHash   = XVal(usuarioNode, "PasswordTemporalHash"),
                                    PasswordTemporalExpira = XValDate(usuarioNode, "PasswordTemporalExpira"),
                                    RequiereCambioPassword = XVal(usuarioNode, "RequiereCambioPassword") == "1",
                                    IntentosFallidos   = XValInt(usuarioNode, "IntentosFallidos") ?? 0,
                                    FechaCambioPassword    = XValDate(usuarioNode, "FechaCambioPassword"),
                                    FechaUltimoLogin   = XValDate(usuarioNode, "FechaUltimoLogin") ?? DateTime.MinValue
                                };

                                // Tienda
                                var tiendaNode = usuarioNode.Element("DetalleTienda");
                                if (tiendaNode != null)
                                {
                                    rptUsuario.oTienda = new Tienda
                                    {
                                        IdTienda      = XValInt(tiendaNode, "IdTienda") ?? 0,
                                        Nombre        = XVal(tiendaNode, "Nombre"),
                                        RUC           = XVal(tiendaNode, "RUC"),
                                        Direccion     = XVal(tiendaNode, "Direccion"),
                                        Telefono      = XVal(tiendaNode, "Telefono"),
                                        Activo        = XVal(tiendaNode, "Activo") == "1",
                                        FechaRegistro = XValDate(tiendaNode, "FechaRegistro") ?? DateTime.Now
                                    };
                                }

                                // Rol
                                var rolNode = usuarioNode.Element("DetalleRol");
                                if (rolNode != null)
                                {
                                    rptUsuario.oRol = new Rol
                                    {
                                        IdRol         = XValInt(rolNode, "IdRol") ?? 0,
                                        Descripcion   = XVal(rolNode, "Descripcion"),
                                        Activo        = XVal(rolNode, "Activo") == "1",
                                        FechaRegistro = XValDate(rolNode, "FechaRegistro") ?? DateTime.Now
                                    };
                                }

                                // Menu y SubMenu
                                var detalleMenuNode = usuarioNode.Element("DetalleMenu");
                                if (detalleMenuNode != null)
                                {
                                    rptUsuario.oListaMenu = new System.Collections.Generic.List<Menu>();
                                    foreach (var menuNode in detalleMenuNode.Elements("Menu"))
                                    {
                                        Menu menu = new Menu
                                        {
                                            Nombre = menuNode.Element("NombreMenu") != null ? menuNode.Element("NombreMenu").Value : "",
                                            Icono = menuNode.Element("Icono") != null ? menuNode.Element("Icono").Value : ""
                                        };
                                        var detalleSubMenu = menuNode.Element("DetalleSubMenu");
                                        if (detalleSubMenu != null)
                                        {
                                            menu.oSubMenu = new System.Collections.Generic.List<SubMenu>();
                                            foreach (var subNode in detalleSubMenu.Elements("SubMenu"))
                                            {
                                                menu.oSubMenu.Add(new SubMenu
                                                {
                                                    Nombre = subNode.Element("NombreSubMenu") != null ? subNode.Element("NombreSubMenu").Value : "",
                                                    Controlador = subNode.Element("Controlador") != null ? subNode.Element("Controlador").Value : "",
                                                    Vista = subNode.Element("Vista") != null ? subNode.Element("Vista").Value : "",
                                                    Icono = subNode.Element("Icono") != null ? subNode.Element("Icono").Value : "",
                                                    Activo   = subNode.Element("Activo")  != null && subNode.Element("Activo").Value  == "1",
                                                    EsGrupo  = subNode.Element("EsGrupo") != null && subNode.Element("EsGrupo").Value == "1"
                                                });
                                            }
                                        }
                                        rptUsuario.oListaMenu.Add(menu);
                                    }
                                }
                            }
                        }
                        dr.Close();
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("ObtenerDetalleUsuario ERROR: " + ex.Message + " | " + ex.StackTrace);
                    rptUsuario = null;
                }
            }
            return rptUsuario;
        }

        // =================== REGISTRO ===================
        public ResultadoRegistroUsuario RegistrarUsuario(string documento, string correo, int idRol, int idTienda, string clave)
        {
            ResultadoRegistroUsuario resultado = new ResultadoRegistroUsuario();
            try
            {
                using (SqlConnection oconexion = new SqlConnection(Conexion.CN))
                {
                    using (SqlCommand cmd = new SqlCommand("SP_RegistrarUsuario", oconexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.AddWithValue("@Documento", documento);
                        cmd.Parameters.AddWithValue("@Correo", correo);
                        cmd.Parameters.AddWithValue("@IdRol", idRol);
                        cmd.Parameters.AddWithValue("@IdTienda", idTienda);
                        cmd.Parameters.AddWithValue("@Clave", string.IsNullOrEmpty(clave) ? DBNull.Value : (object)clave);

                        oconexion.Open();
                        using (SqlDataReader dr = cmd.ExecuteReader())
                        {
                            if (dr.Read())
                            {
                                resultado.TipoMensaje = dr["TipoMensaje"].ToString();
                                resultado.Mensaje = dr["Mensaje"].ToString();
                                if (resultado.TipoMensaje == "OK")
                                {
                                    resultado.IdUsuario = Convert.ToInt32(dr["IdUsuario"]);
                                    resultado.OTP = dr["OTP"].ToString();
                                    resultado.Expira = Convert.ToDateTime(dr["Expira"]);
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                resultado.TipoMensaje = "ERROR";
                resultado.Mensaje = "Excepción: " + ex.Message;
            }
            return resultado;
        }

        public int RegistrarUsuarioTemporal(Usuario usuario, out string passwordTemporal)
        {
            int idUsuario = 0;
            passwordTemporal = GenerarPasswordTemporal();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
                    INSERT INTO Usuario 
                    (Nombres, Apellidos, Correo, Clave, PasswordTemporalHash, PasswordTemporalExpira, RequiereCambioPassword, Activo, FechaRegistro)
                    VALUES 
                    (@Nombres, @Apellidos, @Correo, @Clave, @PasswordTemporalHash, @PasswordTemporalExpira, 1, 1, GETDATE());
                    SELECT SCOPE_IDENTITY();";

                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@Nombres", usuario.Nombres);
                    cmd.Parameters.AddWithValue("@Apellidos", usuario.Apellidos);
                    cmd.Parameters.AddWithValue("@Correo", usuario.Correo);
                    cmd.Parameters.AddWithValue("@Clave", GetSHA256(usuario.Clave));
                    cmd.Parameters.AddWithValue("@PasswordTemporalHash", GetSHA256(passwordTemporal));
                    cmd.Parameters.AddWithValue("@PasswordTemporalExpira", DateTime.Now.AddHours(24));

                    oConexion.Open();
                    object result = cmd.ExecuteScalar();
                    if (result != null)
                        idUsuario = Convert.ToInt32(result);
                }
            }
            return idUsuario;
        }

        public int RegistrarUsuarioPendiente(Usuario usuario, out string otp)
        {
            int idUsuario = 0;
            otp = GenerarOTP();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
                    INSERT INTO Usuario (IdEmpleado, Correo, NombreUsuario, Estado, OTP, FechaExpiracionOTP)
                    VALUES (@IdEmpleado, @Correo, @NombreUsuario, 'Pendiente', @OTP, DATEADD(MINUTE, 15, GETDATE()));
                    SELECT SCOPE_IDENTITY();";

                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@IdEmpleado", usuario.IdEmpleado);
                cmd.Parameters.AddWithValue("@Correo", usuario.Correo);
                cmd.Parameters.AddWithValue("@NombreUsuario", usuario.NombreUsuario);
                cmd.Parameters.AddWithValue("@OTP", otp);

                oConexion.Open();
                object result = cmd.ExecuteScalar();
                if (result != null)
                    idUsuario = Convert.ToInt32(result);
            }
            return idUsuario;
        }

        // =================== VALIDACIONES ===================
        public bool TieneUsuario(int idEmpleado)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("SELECT 1 FROM Usuario WHERE IdEmpleado = @IdEmpleado", oConexion);
                cmd.Parameters.AddWithValue("@IdEmpleado", idEmpleado);
                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }

        public bool TieneUsuarioPorEmpleado(int idPersona)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
                    SELECT 1
                    FROM Usuario u
                    INNER JOIN Empleado e ON u.IdEmpleado = e.IdEmpleado
                    WHERE e.IdPersona = @idPersona";

                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@idPersona", idPersona);
                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }

        public bool ValidarOTP(string correo, string otp)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
                    SELECT COUNT(1) 
                    FROM Usuario 
                    WHERE Correo=@Correo AND OTP=@OTP AND Estado='Pendiente' AND FechaExpiracionOTP > GETDATE()";

                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@Correo", correo);
                cmd.Parameters.AddWithValue("@OTP", otp);

                oConexion.Open();
                return Convert.ToInt32(cmd.ExecuteScalar()) > 0;
            }
        }

        public bool CrearContraseña(string correo, string otp, string nuevaClave)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
                    UPDATE Usuario
                    SET Clave=@Clave, Estado='Activo', OTP=NULL, FechaExpiracionOTP=NULL
                    WHERE Correo=@Correo AND OTP=@OTP AND Estado='Pendiente' AND FechaExpiracionOTP > GETDATE()";

                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@Clave", GetSHA256(nuevaClave));
                cmd.Parameters.AddWithValue("@Correo", correo);
                cmd.Parameters.AddWithValue("@OTP", otp);

                oConexion.Open();
                return cmd.ExecuteNonQuery() > 0;
            }
        }

        // =================== MODIFICACIÓN / ELIMINACIÓN ===================
        public bool ModificarUsuario(Usuario oUsuario)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarUsuario", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("IdUsuario", oUsuario.IdUsuario);
                    cmd.Parameters.AddWithValue("Nombres", oUsuario.Nombres);
                    cmd.Parameters.AddWithValue("Apellidos", oUsuario.Apellidos);
                    cmd.Parameters.AddWithValue("Correo", oUsuario.Correo);
                    cmd.Parameters.AddWithValue("Clave", oUsuario.Clave);
                    cmd.Parameters.AddWithValue("IdTienda", oUsuario.IdTienda.HasValue ? (object)oUsuario.IdTienda.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("IdRol", oUsuario.IdRol);
                    cmd.Parameters.AddWithValue("Activo", oUsuario.Activo);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        public bool EliminarUsuario(int IdUsuario)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_EliminarUsuario", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("IdUsuario", IdUsuario);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        public bool CambiarEstadoUsuario(int IdUsuario, bool nuevoEstado)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"UPDATE Usuario 
                 SET Activo = @Activo,
                     IntentosFallidos = CASE WHEN @Activo = 1 THEN 0 ELSE IntentosFallidos END
                 WHERE IdUsuario = @IdUsuario";
                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@Activo", nuevoEstado);
                    cmd.Parameters.AddWithValue("@IdUsuario", IdUsuario);

                    oConexion.Open();
                    respuesta = cmd.ExecuteNonQuery() > 0;
                }
            }
            return respuesta;
        }

        public bool CambiarClave(int idUsuario, string nuevaClave)
        {
            if (idUsuario <= 0 || string.IsNullOrEmpty(nuevaClave))
                return false;

            bool respuesta = false;
            string claveEncriptada = GetSHA256(nuevaClave);

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"UPDATE Usuario SET Clave = @Clave, FechaCambioPassword = GETDATE() WHERE IdUsuario = @IdUsuario";
                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@Clave", claveEncriptada);
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    oConexion.Open();
                    respuesta = cmd.ExecuteNonQuery() > 0;
                }
            }
            return respuesta;
        }
        // Reemplazar el método ActualizarUsuario en CD_Usuario.cs
        // Columnas reales de la tabla Usuario confirmadas por INFORMATION_SCHEMA

        public bool ActualizarUsuario(Usuario usuario)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
            UPDATE Usuario SET
                IntentosFallidos      = @IntentosFallidos,
                PasswordTemporalHash  = @PasswordTemporalHash,
                PasswordTemporalExpira= @PasswordTemporalExpira,
                RequiereCambioPassword= @RequiereCambioPassword,
                FechaUltimoLogin      = @FechaUltimoLogin,
                FechaCambioPassword   = @FechaCambioPassword
            WHERE IdUsuario = @IdUsuario";

                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@IntentosFallidos", usuario.IntentosFallidos);
                    cmd.Parameters.AddWithValue("@PasswordTemporalHash",
                        usuario.PasswordTemporalHash ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@PasswordTemporalExpira",
                        usuario.PasswordTemporalExpira.HasValue
                            ? (object)usuario.PasswordTemporalExpira.Value
                            : (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@RequiereCambioPassword", usuario.RequiereCambioPassword);
                    cmd.Parameters.AddWithValue("@FechaUltimoLogin",
                        usuario.FechaUltimoLogin != DateTime.MinValue
                            ? (object)usuario.FechaUltimoLogin
                            : (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@FechaCambioPassword",        // NUEVO
                        usuario.FechaCambioPassword.HasValue
                            ? (object)usuario.FechaCambioPassword.Value
                            : (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdUsuario", usuario.IdUsuario);

                    oConexion.Open();
                    return cmd.ExecuteNonQuery() > 0;
                }
            }
        }
        public ResultadoSP RegistrarUsuario(Usuario oUsuario)
        {
            ResultadoSP res = new ResultadoSP(); // <-- Tipo esperado

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarUsuario", oConexion);
                    cmd.CommandType = CommandType.StoredProcedure;

                    // usp_RegistrarUsuario acepta: Nombres, Apellidos, Correo, Clave, IdTienda, IdRol, @Resultado(out)
                    cmd.Parameters.AddWithValue("Nombres",   oUsuario.Nombres);
                    cmd.Parameters.AddWithValue("Apellidos", oUsuario.Apellidos);
                    cmd.Parameters.AddWithValue("Correo",    oUsuario.Correo);
                    cmd.Parameters.AddWithValue("Clave",     oUsuario.Clave);
                    cmd.Parameters.AddWithValue("IdTienda",  oUsuario.IdTienda.HasValue ? (object)oUsuario.IdTienda.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("IdRol",     oUsuario.IdRol);

                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    bool ok = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                    res.Resultado = ok;
                    res.Codigo    = ok ? 1 : 2;
                    res.Mensaje   = ok ? "Usuario registrado correctamente." : "El correo ya está registrado.";
                }
                catch (Exception ex)
                {
                    res.Resultado = false;
                    res.Codigo = 3;
                    res.Mensaje = ex.Message;
                }
            }

            return res;
        }
        public string AsignarPasswordTemporal(int idUsuario)
        {
            string passwordTemporal = GenerarPasswordTemporal(10);
            string hash = GetSHA256(passwordTemporal);

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"UPDATE Usuario SET
                PasswordTemporalHash   = @Hash,
                PasswordTemporalExpira = @Expira,
                RequiereCambioPassword = 1
            WHERE IdUsuario = @IdUsuario";

                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@Hash", hash);
                    cmd.Parameters.AddWithValue("@Expira", DateTime.Now.AddHours(2));
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                }
            }
            return passwordTemporal; // texto plano para enviar por correo
        }

        /// <summary>
        /// Desbloquea un usuario bloqueado por intentos fallidos:
        /// - Resetea IntentosFallidos a 0
        /// - Genera una contraseña temporal válida por 24 horas
        /// - Marca RequiereCambioPassword = true
        /// Retorna la contraseña temporal en texto plano para enviarla por correo.
        /// </summary>
        public string DesbloquearUsuario(int idUsuario)
        {
            string passwordTemporal = GenerarPasswordTemporal(10);
            string hash = GetSHA256(passwordTemporal);

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"UPDATE Usuario SET
                    IntentosFallidos       = 0,
                    PasswordTemporalHash   = @Hash,
                    PasswordTemporalExpira = @Expira,
                    RequiereCambioPassword = 1
                WHERE IdUsuario = @IdUsuario";

                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@Hash", hash);
                    cmd.Parameters.AddWithValue("@Expira", DateTime.Now.AddHours(24));
                    cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                }
            }
            return passwordTemporal; // texto plano para enviar por correo
        }

        public Usuario ObtenerUsuarioPorCorreo(string correo)
        {
            Usuario usuario = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerUsuarioPorCorreo", oConexion)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@Correo", correo);

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    if (dr.Read())
                    {
                        usuario = new Usuario
                        {
                            IdUsuario             = Convert.ToInt32(dr["IdUsuario"]),
                            Nombres               = dr["Nombres"].ToString(),
                            Apellidos             = dr["Apellidos"].ToString(),
                            Correo                = dr["Correo"].ToString(),
                            Clave                 = dr["Clave"].ToString(),
                            IdTienda              = dr["IdTienda"] != DBNull.Value ? Convert.ToInt32(dr["IdTienda"]) : (int?)null,
                            IdRol                 = Convert.ToInt32(dr["IdRol"]),
                            Activo                = Convert.ToBoolean(dr["Activo"]),
                            FechaRegistro         = dr["FechaRegistro"] != DBNull.Value ? Convert.ToDateTime(dr["FechaRegistro"]) : DateTime.Now,
                            IntentosFallidos      = dr["IntentosFallidos"] != DBNull.Value ? Convert.ToInt32(dr["IntentosFallidos"]) : 0,
                            PasswordTemporalHash  = dr["PasswordTemporalHash"] != DBNull.Value ? dr["PasswordTemporalHash"].ToString() : null,
                            RequiereCambioPassword= dr["RequiereCambioPassword"] != DBNull.Value && dr["RequiereCambioPassword"].ToString() == "1",
                            PasswordTemporalExpira= dr["PasswordTemporalExpira"] != DBNull.Value ? Convert.ToDateTime(dr["PasswordTemporalExpira"]) : (DateTime?)null,
                            FechaCambioPassword   = dr["FechaCambioPassword"] != DBNull.Value ? Convert.ToDateTime(dr["FechaCambioPassword"]) : (DateTime?)null,
                            FechaUltimoLogin      = dr["FechaUltimoLogin"] != DBNull.Value ? Convert.ToDateTime(dr["FechaUltimoLogin"]) : DateTime.MinValue,
                            oRol = new Rol
                            {
                                Descripcion = dr["DescripcionRol"] != DBNull.Value ? dr["DescripcionRol"].ToString() : ""
                            }
                        };
                    }
                    dr.Close();
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("ObtenerUsuarioPorCorreo ERROR: " + ex.Message);
                }
            }
            return usuario;
        }
    }
}