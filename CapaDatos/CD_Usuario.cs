using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using System.Xml;
using System.Xml.Linq;

namespace CapaDatos
{

    public class CD_Usuario
    {
        public static CD_Usuario _instancia = null;

        private CD_Usuario()
        {

        }

        public static CD_Usuario Instancia
        {
            get
            {
                if (_instancia == null)
                {
                    _instancia = new CD_Usuario();
                }
                return _instancia;
            }
        }

        public int LoginUsuario(string Usuario, string Clave)
        {
            int respuesta = 0;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_LoginUsuario", oConexion);
                    cmd.Parameters.AddWithValue("Correo", Usuario);
                    cmd.Parameters.AddWithValue("Clave", Clave);
                    cmd.Parameters.Add("IdUsuario", SqlDbType.Int).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();

                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToInt32(cmd.Parameters["IdUsuario"].Value);

                }
                catch (Exception ex)
                {
                    respuesta = 0;
                }
            }
            return respuesta;
        }

        public Usuario ObtenerDetalleUsuario(int IdUsuario)
        {
            Usuario rptUsuario = new Usuario();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerDetalleUsuario", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@IdUsuario", IdUsuario);

                try
                {
                    oConexion.Open();
                    using (XmlReader dr = cmd.ExecuteXmlReader())
                    {
                        if (dr.Read())
                        {
                            XDocument doc = XDocument.Load(dr);

                            if (doc.Element("Usuario") != null)
                            {
                                var usuarioNode = doc.Element("Usuario");

                                rptUsuario = new Usuario()
                                {
                                    IdUsuario = int.Parse(usuarioNode.Element("IdUsuario").Value),
                                    Nombres = usuarioNode.Element("Nombres").Value,
                                    Apellidos = usuarioNode.Element("Apellidos").Value,
                                    Correo = usuarioNode.Element("Correo").Value,
                                    Clave = usuarioNode.Element("Clave").Value,
                                    IdTienda = int.Parse(usuarioNode.Element("IdTienda").Value),
                                    IdRol = int.Parse(usuarioNode.Element("IdRol").Value),
                                    Activo = usuarioNode.Element("Activo").Value == "1",
                                    FechaRegistro = DateTime.Parse(usuarioNode.Element("FechaRegistro").Value)
                                };

                                // ---------- Tienda ----------
                                var tiendaNode = usuarioNode.Element("DetalleTienda");
                                if (tiendaNode != null)
                                {
                                    rptUsuario.oTienda = new Tienda()
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

                                // ---------- Rol ----------
                                var rolNode = usuarioNode.Element("DetalleRol");
                                if (rolNode != null)
                                {
                                    rptUsuario.oRol = new Rol()
                                    {
                                        IdRol = int.Parse(rolNode.Element("IdRol").Value),
                                        Descripcion = rolNode.Element("Descripcion").Value,
                                        Activo = rolNode.Element("Activo").Value == "1",
                                        FechaRegistro = DateTime.Parse(rolNode.Element("FechaRegistro").Value)
                                    };
                                }

                                // ---------- Menú ----------
                                var detalleMenu = usuarioNode.Element("DetalleMenu");
                                if (detalleMenu != null && detalleMenu.HasElements)
                                {
                                    rptUsuario.oListaMenu = (
                                        from menu in detalleMenu.Elements("Menu")
                                        select new Menu()
                                        {
                                            Nombre = menu.Element("NombreMenu").Value,
                                            Icono = menu.Element("Icono").Value,
                                            oSubMenu = (
                                                from submenu in menu.Element("DetalleSubMenu").Elements("SubMenu")
                                                select new SubMenu()
                                                {
                                                    Nombre = submenu.Element("NombreSubMenu").Value,
                                                    Controlador = submenu.Element("Controlador").Value,
                                                    Vista = submenu.Element("Vista").Value,
                                                    Icono = submenu.Element("Icono").Value,
                                                    Activo = submenu.Element("Activo").Value == "1"
                                                }
                                            ).ToList()
                                        }
                                    ).ToList();
                                }
                                else
                                {
                                    rptUsuario.oListaMenu = new List<Menu>(); // lista vacía si no hay menús
                                }
                            }
                            else
                            {
                                rptUsuario = null;
                            }
                        }

                        dr.Close();
                    }
                    var ejemplo = rptUsuario;
                    JavaScriptSerializer serializer = new JavaScriptSerializer();
                    string usuarioComoString = serializer.Serialize(rptUsuario);
                    return rptUsuario;
                }
                catch (Exception ex)
                {
                    // Loguear el error si querés
                    rptUsuario = null;
                    return rptUsuario;
                }
            }
        }


        public List<Usuario> ObtenerUsuarios()
        {
            List<Usuario> rptListaUsuario = new List<Usuario>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerUsuario", oConexion);
                cmd.CommandType = CommandType.StoredProcedure;

                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        rptListaUsuario.Add(new Usuario()
                        {
                            IdUsuario = Convert.ToInt32(dr["IdUsuario"].ToString()),
                            CI = dr["Documento"].ToString(),        // <--- agregar esta línea
                            Nombres = dr["Nombres"].ToString(),
                            Apellidos = dr["Apellidos"].ToString(),
                            Correo = dr["Correo"].ToString(),
                            Clave = dr["Clave"].ToString(),
                            IdTienda = Convert.ToInt32(dr["IdTienda"].ToString()),
                            IdRol = Convert.ToInt32(dr["IdRol"].ToString()),
                            oRol = new Rol() { Descripcion = dr["DescripcionRol"].ToString() },
                            Activo = Convert.ToBoolean(dr["Activo"])
                        });
                    }
                    dr.Close();

                    return rptListaUsuario;

                }
                catch (Exception ex)
                {
                    rptListaUsuario = null;
                    return rptListaUsuario;
                }
            }
        }


        public ResultadoSP RegistrarUsuario(Usuario oUsuario)
        {
            ResultadoSP res = new ResultadoSP();

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



        public bool ModificarUsuario(Usuario oUsuario)
        {
            bool respuesta = true;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarUsuario", oConexion);
                    cmd.Parameters.AddWithValue("IdUsuario", oUsuario.IdUsuario);
                    cmd.Parameters.AddWithValue("Nombres", oUsuario.Nombres);
                    cmd.Parameters.AddWithValue("Apellidos", oUsuario.Apellidos);
                    cmd.Parameters.AddWithValue("Correo", oUsuario.Correo);
                    cmd.Parameters.AddWithValue("Clave", oUsuario.Clave);
                    cmd.Parameters.AddWithValue("IdTienda", oUsuario.IdTienda);
                    cmd.Parameters.AddWithValue("IdRol", oUsuario.IdRol);
                    cmd.Parameters.AddWithValue("Activo", oUsuario.Activo);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();

                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);

                }
                catch (Exception ex)
                {
                    respuesta = false;
                }
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
                    SqlCommand cmd = new SqlCommand("usp_EliminarUsuario", oConexion);
                    cmd.Parameters.AddWithValue("IdUsuario", IdUsuario);
                    cmd.Parameters.Add("Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;
                    cmd.CommandType = CommandType.StoredProcedure;

                    oConexion.Open();

                    cmd.ExecuteNonQuery();

                    respuesta = Convert.ToBoolean(cmd.Parameters["Resultado"].Value);

                }
                catch (Exception ex)
                {
                    respuesta = false;
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
                try
                {
                    string query = "UPDATE Usuario SET Clave = @Clave WHERE IdUsuario = @IdUsuario";
                    using (SqlCommand cmd = new SqlCommand(query, oConexion))
                    {
                        cmd.Parameters.AddWithValue("@Clave", claveEncriptada);
                        cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);

                        oConexion.Open();
                        respuesta = cmd.ExecuteNonQuery() > 0;
                    }
                }
                catch (Exception ex)
                {
                    // opcional: log del error
                    respuesta = false;
                }
            }

            return respuesta;
        }

        // Método auxiliar SHA256
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
        public ResultadoRegistroUsuario RegistrarUsuario(string documento, string correo, int idRol, int idTienda, string clave)
        {
            ResultadoRegistroUsuario resultado = new ResultadoRegistroUsuario();

            try
            {
                using (SqlConnection oconexion = new SqlConnection(ConfigurationManager.ConnectionStrings["cadena"].ToString()))
                {
                    using (SqlCommand cmd = new SqlCommand("SP_RegistrarUsuario", oconexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;

                        cmd.Parameters.AddWithValue("@Documento", documento);
                        cmd.Parameters.AddWithValue("@Correo", correo);
                        cmd.Parameters.AddWithValue("@IdRol", idRol);
                        cmd.Parameters.AddWithValue("@IdTienda", idTienda);

                        if (string.IsNullOrEmpty(clave))
                            cmd.Parameters.AddWithValue("@Clave", DBNull.Value);
                        else
                            cmd.Parameters.AddWithValue("@Clave", clave);

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
        // Verifica si un empleado ya tiene un usuario creado
        public bool TieneUsuario(int idEmpleado)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT 1 FROM Usuario WHERE IdEmpleado = @IdEmpleado", oConexion);
                cmd.Parameters.AddWithValue("@IdEmpleado", idEmpleado);

                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }
        // Registra un usuario temporal para confirmación con OTP
        public int RegistrarUsuarioTemporal(Usuario usuario, out string otp)
        {
            int idUsuarioGenerado = 0;
            otp = GenerarOTP(); // Método para generar código OTP, ej: 6 dígitos

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
            INSERT INTO Usuario (IdEmpleado, Nombres, Apellidos, CI, Correo, Clave, Activo, FechaRegistro, OTP)
            VALUES (@IdEmpleado, @Nombres, @Apellidos, @CI, @Correo, @Clave, 0, GETDATE(), @OTP);
            SELECT SCOPE_IDENTITY();", oConexion);

                cmd.Parameters.AddWithValue("@IdEmpleado", usuario.IdEmpleado);
                cmd.Parameters.AddWithValue("@Nombres", usuario.Nombres);
                cmd.Parameters.AddWithValue("@Apellidos", usuario.Apellidos);
                cmd.Parameters.AddWithValue("@CI", usuario.CI);
                cmd.Parameters.AddWithValue("@Correo", usuario.Correo);
                cmd.Parameters.AddWithValue("@Clave", GetSHA256(usuario.Clave)); // Encriptamos la clave
                cmd.Parameters.AddWithValue("@OTP", otp);

                oConexion.Open();
                object result = cmd.ExecuteScalar();
                if (result != null)
                    idUsuarioGenerado = Convert.ToInt32(result);
            }

            return idUsuarioGenerado;
        }

        // Método para generar OTP de 6 dígitos
        private string GenerarOTP()
        {
            Random rnd = new Random();
            return rnd.Next(100000, 999999).ToString();
        }
        public int RegistrarUsuarioPendiente(Usuario usuario, out string otp)
        {
            int idUsuario = 0;
            otp = new Random().Next(100000, 999999).ToString(); // OTP 6 dígitos

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
                int count = Convert.ToInt32(cmd.ExecuteScalar());
                return count > 0;
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
        // Validar si un empleado ya tiene usuario
        // Validar si un empleado ya tiene usuario
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

        // Método que valida si un empleado ya tiene usuario asignado

    }
}