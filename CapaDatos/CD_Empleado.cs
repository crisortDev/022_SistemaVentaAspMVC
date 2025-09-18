using CapaModelo;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
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
    
    public class CD_Empleado
    {
        public static CD_Empleado _instancia = null;

        private CD_Empleado()
        {

        }

        public static CD_Empleado Instancia
        {
            get
            {
                if(_instancia == null)
                {
                    _instancia = new CD_Empleado();
                }
                return _instancia;
            }
        }

        public Empleado ObtenerEmpleadoPorCI(string ci)
        {
            Empleado emp = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("SELECT * FROM Empleado WHERE CI = @CI", oConexion);
                cmd.Parameters.AddWithValue("@CI", ci);
                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                if (dr.Read())
                {
                    emp = new Empleado()
                    {
                        IdEmpleado = Convert.ToInt32(dr["IdEmpleado"]),
                        CI = dr["CI"].ToString(),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        IdTienda = Convert.ToInt32(dr["IdTienda"]),
                        Activo = Convert.ToBoolean(dr["Activo"])
                    };
                }
                dr.Close();
            }
            return emp;
        }

        public (bool resultado, string mensaje, int idEmpleado) RegistrarEmpleado(Empleado emp, string correo)
        {
            if (ExisteCorreo(correo))
            {
                return (false, "El correo ya está registrado en otro usuario.", 0);
            }

            bool resultado = false;
            int nuevoId = 0;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "INSERT INTO Empleado (CI, Nombres, Apellidos, IdTienda, Activo, FechaRegistro) " +
                    "VALUES (@CI,@Nombres,@Apellidos,@IdTienda,@Activo,GETDATE()); " +
                    "SELECT SCOPE_IDENTITY();", oConexion);

                cmd.Parameters.AddWithValue("@CI", emp.CI);
                cmd.Parameters.AddWithValue("@Nombres", emp.Nombres);
                cmd.Parameters.AddWithValue("@Apellidos", emp.Apellidos);
                cmd.Parameters.AddWithValue("@IdTienda", emp.IdTienda);
                cmd.Parameters.AddWithValue("@Activo", emp.Activo);

                oConexion.Open();
                object result = cmd.ExecuteScalar();
                if (result != null)
                {
                    nuevoId = Convert.ToInt32(result);
                    emp.IdEmpleado = nuevoId; 
                    resultado = true;
                }
            }

            return (resultado, resultado ? "Empleado registrado correctamente." : "Error al registrar empleado.", nuevoId);
        }



        public bool ExisteCorreo(string correo)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("SELECT 1 FROM USUARIO WHERE Correo = @Correo", oConexion);
                cmd.Parameters.AddWithValue("@Correo", correo);
                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }

    }
}
