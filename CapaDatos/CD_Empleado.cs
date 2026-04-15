using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_Empleado
    {
        private static CD_Empleado _instancia = null;

        private CD_Empleado() { }

        public static CD_Empleado Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Empleado();
                return _instancia;
            }
        }

        // Obtener empleado por CI
        public List<Empleado> BuscarEmpleadosPorCI(string ci)
        {
            List<Empleado> lista = new List<Empleado>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
            SELECT TOP 20 e.IdEmpleado, e.IdTienda, e.Activo, e.FechaRegistro,
                            p.Documento AS CI, p.Nombres, p.Apellidos
            FROM Empleado e
            INNER JOIN Persona p ON e.IdPersona = p.IdPersona
            WHERE e.Activo = 1 AND p.Documento LIKE @CI + '%'
            ORDER BY p.Documento", oConexion);

                cmd.Parameters.AddWithValue("@CI", ci ?? "");

                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    lista.Add(new Empleado()
                    {
                        IdEmpleado = Convert.ToInt32(dr["IdEmpleado"]),
                        Documento = dr["CI"].ToString(),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        IdTienda = Convert.ToInt32(dr["IdTienda"]),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"])
                    });
                }
                dr.Close();
            }
            return lista;
        }



        // Registrar empleado directamente desde la app (sin SP)
        public int RegistrarDesdeApp(Empleado emp)
        {
            if (emp == null)
                throw new ArgumentNullException(nameof(emp), "El objeto empleado no puede ser null.");

            if (emp.IdPersona <= 0)
                throw new ArgumentException("Debe proporcionar un IdPersona válido para registrar el empleado.");

            int nuevoId = 0;

            try
            {
                using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
                using (SqlCommand cmd = new SqlCommand(
                    @"INSERT INTO Empleado 
                (IdPersona, Nombres, Apellidos, IdTienda, Activo, FechaRegistro, FechaIngreso) 
              VALUES 
                (@IdPersona, @Nombres, @Apellidos, @IdTienda, @Activo, GETDATE(), @FechaIngreso);
              SELECT CAST(SCOPE_IDENTITY() AS INT);", oConexion))
                {
                    cmd.Parameters.AddWithValue("@IdPersona", emp.IdPersona);
                    cmd.Parameters.AddWithValue("@Nombres", emp.Nombres ?? string.Empty);
                    cmd.Parameters.AddWithValue("@Apellidos", emp.Apellidos ?? string.Empty);
                    cmd.Parameters.AddWithValue("@IdTienda", emp.IdTienda);
                    cmd.Parameters.AddWithValue("@Activo", emp.Activo);
                    cmd.Parameters.AddWithValue("@FechaIngreso", emp.FechaIngreso != default ? emp.FechaIngreso : DateTime.Now);

                    oConexion.Open();
                    object result = cmd.ExecuteScalar();

                    if (result != null && int.TryParse(result.ToString(), out int id))
                        nuevoId = id;
                }
            }
            catch (SqlException ex)
            {
                throw new Exception("Error al registrar empleado en la base de datos: " + ex.Message, ex);
            }

            return nuevoId;
        }



        // Modificar empleado desde la app
        public bool ModificarDesdeApp(Empleado emp)
        {
            try
            {
                bool resultado = false;
                using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
                {
                    SqlCommand cmd = new SqlCommand(
                        "UPDATE Empleado SET " +
                        "Nombres = @Nombres, " +
                        "Apellidos = @Apellidos, " +
                        "IdTienda = @IdTienda, " +
                        "Activo = @Activo, " +
                        "FechaIngreso = @FechaIngreso " +
                        "WHERE IdEmpleado = @IdEmpleado", oConexion);

                    cmd.Parameters.AddWithValue("@Nombres", emp.Nombres ?? string.Empty);
                    cmd.Parameters.AddWithValue("@Apellidos", emp.Apellidos ?? string.Empty);
                    cmd.Parameters.AddWithValue("@IdTienda", emp.IdTienda);
                    cmd.Parameters.AddWithValue("@Activo", emp.Activo);
                    // FechaIngreso es DateTime? — usar HasValue para tipos nullable
                    cmd.Parameters.AddWithValue("@FechaIngreso",
                        emp.FechaIngreso.HasValue
                            ? (object)emp.FechaIngreso.Value
                            : (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdEmpleado", emp.IdEmpleado);

                    oConexion.Open();
                    resultado = cmd.ExecuteNonQuery() > 0;
                }
                return resultado;
            }
            catch (Exception ex)
            {

                throw;
            }
           
        }



        // Validar si existe correo
        public bool ExisteCorreo(string correo)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("SELECT 1 FROM Usuario WHERE Correo = @Correo", oConexion);
                cmd.Parameters.AddWithValue("@Correo", correo);
                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }
        // Validar si una persona ya es empleado
        public bool EsEmpleado(int idPersona)
        {
            bool esEmpleado = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT 1 FROM Empleado WHERE IdPersona = @IdPersona", oConexion);

                cmd.Parameters.AddWithValue("@IdPersona", idPersona);

                oConexion.Open();
                esEmpleado = cmd.ExecuteScalar() != null;
            }
            return esEmpleado;
        }
        // Obtener un empleado por su IdEmpleado
        public Empleado ObtenerEmpleadoPorId(int idEmpleado)
        {
            Empleado empleado = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"
            SELECT e.IdEmpleado, e.IdPersona, e.IdTienda, e.Activo, e.FechaRegistro, e.FechaIngreso,
                   p.Documento AS CI,
                   e.Nombres, e.Apellidos,
                   p.Correo, p.Telefono
            FROM Empleado e
            INNER JOIN Persona p ON e.IdPersona = p.IdPersona
            WHERE e.IdEmpleado = @IdEmpleado";

                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@IdEmpleado", idEmpleado);

                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                if (dr.Read())
                {
                    empleado = new Empleado()
                    {
                        IdEmpleado = Convert.ToInt32(dr["IdEmpleado"]),
                        IdPersona = Convert.ToInt32(dr["IdPersona"]),
                        Documento = dr["CI"].ToString(),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        IdTienda = Convert.ToInt32(dr["IdTienda"]),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                        FechaIngreso = dr["FechaIngreso"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaIngreso"])
                    };
                }
                dr.Close();
            }
            return empleado;
        }


        // Este método devuelve el IdEmpleado vinculado a la persona
        public int ObtenerIdEmpleadoPorPersona(int idPersona)
        {
            int idEmpleado = 0;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT TOP 1 IdEmpleado FROM Empleado WHERE IdPersona = @IdPersona", oConexion);

                cmd.Parameters.AddWithValue("@IdPersona", idPersona);

                oConexion.Open();
                object result = cmd.ExecuteScalar();
                if (result != null && result != DBNull.Value)
                    idEmpleado = Convert.ToInt32(result);
            }

            return idEmpleado;
        }
        // ===============================
        // Obtener todos los empleados
        // ===============================
        public List<Empleado> ObtenerEmpleados()
        {
            List<Empleado> lista = new List<Empleado>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
            SELECT e.IdEmpleado, e.IdTienda, e.Activo, e.FechaRegistro, e.FechaIngreso,
                   p.IdPersona, p.Documento,
                   e.Nombres, e.Apellidos,
                   p.Correo, p.Telefono
            FROM Empleado e
            INNER JOIN Persona p ON e.IdPersona = p.IdPersona
            ORDER BY e.IdEmpleado DESC", oConexion);

                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    lista.Add(new Empleado()
                    {
                        IdEmpleado = Convert.ToInt32(dr["IdEmpleado"]),
                        IdTienda = Convert.ToInt32(dr["IdTienda"]),
                        Documento = dr["Documento"].ToString(),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                        FechaIngreso = dr["FechaIngreso"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaIngreso"])
                    });
                }
                dr.Close();
            }
            return lista;
        }


        // ===============================
        // Cambiar estado activo/inactivo
        // ===============================
        public bool CambiarEstadoEmpleado(int idEmpleado, bool activo)
        {
            bool resultado = false;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                oConexion.Open();

                SqlTransaction transaction = oConexion.BeginTransaction();

                try
                {
                    // 1️⃣ Actualiza el estado del empleado
                    SqlCommand cmdEmpleado = new SqlCommand(
                        "UPDATE Empleado SET Activo = @Activo WHERE IdEmpleado = @IdEmpleado",
                        oConexion, transaction
                    );
                    cmdEmpleado.Parameters.AddWithValue("@Activo", activo);
                    cmdEmpleado.Parameters.AddWithValue("@IdEmpleado", idEmpleado);
                    cmdEmpleado.ExecuteNonQuery();

                    // 2️⃣ Actualiza el estado del usuario vinculado a ese empleado
                    SqlCommand cmdUsuario = new SqlCommand(
                        "UPDATE Usuario SET Activo = @Activo, FechaBaja = CASE WHEN @Activo = 0 THEN GETDATE() ELSE NULL END WHERE IdEmpleado = @IdEmpleado",
                        oConexion, transaction
                    );
                    cmdUsuario.Parameters.AddWithValue("@Activo", activo);
                    cmdUsuario.Parameters.AddWithValue("@IdEmpleado", idEmpleado);
                    cmdUsuario.ExecuteNonQuery();

                    // 3️⃣ Confirma la transacción
                    transaction.Commit();
                    resultado = true;
                }
                catch (Exception)
                {
                    // Si algo falla, revierte los cambios
                    transaction.Rollback();
                    throw;
                }
            }

            return resultado;
        }


        // ===============================
        // Registrar o actualizar empleado (como un único método)
        // ===============================
        public (bool resultado, string mensaje, int idEmpleado) GuardarEmpleado(Empleado emp)
        {
            bool exito = false;
            string mensaje = "";
            int idEmpleado = 0;

            if (emp.IdEmpleado > 0)
            {
                exito = ModificarDesdeApp(emp);
                mensaje = exito ? "Empleado actualizado correctamente." : "No se pudo actualizar el empleado.";
                idEmpleado = emp.IdEmpleado;
            }
            else
            {
                idEmpleado = RegistrarDesdeApp(emp);
                exito = idEmpleado > 0;
                mensaje = exito ? "Empleado registrado correctamente." : "No se pudo registrar el empleado.";
            }

            return (exito, mensaje, idEmpleado);
        }
        // ---------------------------------------------------
        // Métodos que faltaban: RegistrarEmpleado y ActualizarEmpleado
        // ---------------------------------------------------
        public (bool resultado, string mensaje, int idEmpleado) RegistrarEmpleado(Empleado emp)
        {
            try
            {
                int id = RegistrarDesdeApp(emp); // usa tu método ya existente
                if (id > 0)
                    return (true, "Empleado registrado correctamente.", id);
                else
                    return (false, "No se pudo registrar el empleado.", 0);
            }
            catch (Exception ex)
            {
                return (false, "Ocurrió un error: " + ex.Message, 0);
            }
        }

        public bool ActualizarEmpleado(Empleado emp)
        {
            try
            {
                bool resultado = ModificarDesdeApp(emp);
                if (!resultado)
                {
                    throw new Exception("No se pudo actualizar el empleado. Verifica que el IdEmpleado existe.");
                }
                return resultado;
            }
            catch (Exception ex)
            {
                throw new Exception("Error al actualizar empleado: " + ex.Message, ex);
            }
        }
        // En CD_Empleado
        public bool ExisteEmpleadoPorCI(string ci)
        {
            bool existe = false;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
            SELECT COUNT(*) 
            FROM Empleado e
            INNER JOIN Persona p ON e.IdPersona = p.IdPersona
            WHERE p.Documento = @CI", oConexion);

                cmd.Parameters.AddWithValue("@CI", ci);

                oConexion.Open();
                int count = Convert.ToInt32(cmd.ExecuteScalar());
                existe = count > 0;
            }

            return existe;
        }

    }
}
