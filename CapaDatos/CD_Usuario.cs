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
        private string GetSHA256(string str)
        {
            using (SHA256 sha256 = SHA256.Create())
            {
                byte[] bytes = Encoding.UTF8.GetBytes(str);
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
                            IdTienda = Convert.ToInt32(dr["IdTienda"]),
                            IdRol = Convert.ToInt32(dr["IdRol"]),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            PasswordTemporalHash = dr["PasswordTemporalHash"] != DBNull.Value ? dr["PasswordTemporalHash"].ToString() : null,
                            RequiereCambioPassword = dr["RequiereCambioPassword"] != DBNull.Value && dr["RequiereCambioPassword"].ToString() == "1",
                            PasswordTemporalExpira = dr["PasswordTemporalExpira"] != DBNull.Value ? Convert.ToDateTime(dr["PasswordTemporalExpira"]) : (DateTime?)null,
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
                    // Loguear ex.Message si quieres
                }
            }
            return rptListaUsuario; // siempre retorna una lista, nunca null
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
                                    IdUsuario = int.Parse(usuarioNode.Element("IdUsuario").Value),
                                    Nombres = usuarioNode.Element("Nombres").Value,
                                    Apellidos = usuarioNode.Element("Apellidos").Value,
                                    Correo = usuarioNode.Element("Correo").Value,
                                    Clave = usuarioNode.Element("Clave").Value,
                                    IdTienda = int.Parse(usuarioNode.Element("IdTienda").Value),
                                    IdRol = int.Parse(usuarioNode.Element("IdRol").Value),
                                    Activo = usuarioNode.Element("Activo").Value == "1",
                                    FechaRegistro = DateTime.Parse(usuarioNode.Element("FechaRegistro").Value),
                                    PasswordTemporalHash = usuarioNode.Element("PasswordTemporalHash") != null ? usuarioNode.Element("PasswordTemporalHash").Value : "",
                                    PasswordTemporalExpira = usuarioNode.Element("PasswordTemporalExpira") != null ? DateTime.Parse(usuarioNode.Element("PasswordTemporalExpira").Value) : DateTime.MinValue,
                                    RequiereCambioPassword = usuarioNode.Element("RequiereCambioPassword") != null && usuarioNode.Element("RequiereCambioPassword").Value == "1"
                                };

                                // Tienda
                                var tiendaNode = usuarioNode.Element("DetalleTienda");
                                if (tiendaNode != null)
                                {
                                    rptUsuario.oTienda = new Tienda
                                    {
                                        IdTienda = int.Parse(tiendaNode.Element("IdTienda").Value),
                                        Nombre = tiendaNode.Element("Nombre").Value,
                                        RUC = tiendaNode.Element("RUC").Value,
                                        Direccion = tiendaNode.Element("Direccion").Value,
                                        Telefono = tiendaNode.Element("Telefono").Value,
                                        Activo = tiendaNode.Element("Activo").Value == "1",
                                        FechaRegistro = DateTime.Parse(tiendaNode.Element("FechaRegistro").Value)
                                    };
                                }

                                // Rol
                                var rolNode = usuarioNode.Element("DetalleRol");
                                if (rolNode != null)
                                {
                                    rptUsuario.oRol = new Rol
                                    {
                                        IdRol = int.Parse(rolNode.Element("IdRol").Value),
                                        Descripcion = rolNode.Element("Descripcion").Value,
                                        Activo = rolNode.Element("Activo").Value == "1",
                                        FechaRegistro = DateTime.Parse(rolNode.Element("FechaRegistro").Value)
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
                                                    Activo = subNode.Element("Activo") != null && subNode.Element("Activo").Value == "1"
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
                catch { rptUsuario = null; }
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
                    cmd.Parameters.AddWithValue("IdTienda", oUsuario.IdTienda);
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
                string query = "UPDATE Usuario SET Activo=@Activo WHERE IdUsuario=@IdUsuario";
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
                string query = "UPDATE Usuario SET Clave=@Clave WHERE IdUsuario=@IdUsuario";
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
                PasswordTemporalHash   = @PasswordTemporalHash,
                PasswordTemporalExpira = @PasswordTemporalExpira,
                RequiereCambioPassword = @RequiereCambioPassword,
                IntentosFallidos       = @IntentosFallidos,
                FechaUltimoLogin       = @FechaUltimoLogin
            WHERE IdUsuario = @IdUsuario";

                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    cmd.Parameters.AddWithValue("@PasswordTemporalHash",
                        usuario.PasswordTemporalHash ?? (object)DBNull.Value);

                    cmd.Parameters.AddWithValue("@PasswordTemporalExpira",
                        usuario.PasswordTemporalExpira.HasValue
                            ? (object)usuario.PasswordTemporalExpira.Value
                            : (object)DBNull.Value);

                    cmd.Parameters.AddWithValue("@RequiereCambioPassword", usuario.RequiereCambioPassword);
                    cmd.Parameters.AddWithValue("@IntentosFallidos", usuario.IntentosFallidos);
                    cmd.Parameters.AddWithValue("@FechaUltimoLogin",
                        usuario.FechaUltimoLogin != DateTime.MinValue
                            ? (object)usuario.FechaUltimoLogin
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

                    cmd.Parameters.AddWithValue("Nombres", oUsuario.Nombres);
                    cmd.Parameters.AddWithValue("Apellidos", oUsuario.Apellidos);
                    cmd.Parameters.AddWithValue("Correo", oUsuario.Correo);
                    cmd.Parameters.AddWithValue("Clave", oUsuario.Clave);
                    cmd.Parameters.AddWithValue("IdTienda", oUsuario.IdTienda);
                    cmd.Parameters.AddWithValue("IdRol", oUsuario.IdRol);
                    cmd.Parameters.AddWithValue("IdEmpleado", oUsuario.IdEmpleado);

                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("Codigo", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.Parameters.Add("Mensaje", SqlDbType.VarChar, 200).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();

                    res.Resultado = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);
                    res.Codigo = Convert.ToInt32(cmd.Parameters["Codigo"].Value);
                    res.Mensaje = cmd.Parameters["Mensaje"].Value.ToString();
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

        public Usuario ObtenerUsuarioPorCorreo(string correo)
        {
            return ObtenerUsuarios().FirstOrDefault(u => u.Correo == correo);
        }
    }
}