using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_Persona
    {
        private static CD_Persona _instancia = null;
        private CD_Persona() { }

        public static CD_Persona Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Persona();
                return _instancia;
            }
        }

        // Obtener todas las personas
        public List<Persona> ObtenerPersonas()
        {
            List<Persona> lista = new List<Persona>();

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = "SELECT * FROM Persona";
                using (SqlCommand cmd = new SqlCommand(query, oConexion))
                {
                    oConexion.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new Persona
                            {
                                IdPersona = Convert.ToInt32(dr["IdPersona"]),
                                Nombres = dr["Nombres"].ToString(),
                                Apellidos = dr["Apellidos"].ToString(),
                                RazonSocial = dr["RazonSocial"].ToString(),
                                TipoDocumento = dr["TipoDocumento"].ToString(),
                                Documento = dr["Documento"].ToString(),
                                Correo = dr["Correo"].ToString(),
                                Telefono = dr["Telefono"].ToString(),
                                Calle1 = dr["Calle1"].ToString(),
                                Calle2 = dr["Calle2"].ToString(), // corregido
                                Ciudad = dr["Ciudad"].ToString(),
                                Barrio = dr["Barrio"].ToString(),
                                FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                                Activo = Convert.ToBoolean(dr["Activo"]),
                                FechaBaja = dr["FechaBaja"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaBaja"])
                            });
                        }
                    }
                }
            }

            return lista;
        }


        // Obtener persona por Documento
        public Persona ObtenerPersonaPorDocumento(string documento)
        {
            Persona persona = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = "SELECT * FROM Persona WHERE Documento = @Documento";
                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@Documento", documento);
                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                if (dr.Read())
                {
                    persona = new Persona
                    {
                        IdPersona = Convert.ToInt32(dr["IdPersona"]),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        RazonSocial = dr["RazonSocial"].ToString(),
                        TipoDocumento = dr["TipoDocumento"].ToString(),
                        Documento = dr["Documento"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        Calle1 = dr["Calle1"].ToString(),
                        Calle2 = dr["Calle2"].ToString(),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaBaja = dr["FechaBaja"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaBaja"])
                    };
                }
                dr.Close();
            }
            return persona;
        }

        // Registrar nueva persona
        public (bool resultado, string mensaje, int idPersona) RegistrarPersona(Persona p)
        {
            // Validación: documento duplicado
            if (ExisteDocumento(p.Documento))
                return (false, "El documento ya está registrado.", 0);

            try
            {
                using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
                {
                    string query = @"
                INSERT INTO Persona 
                (Nombres, Apellidos, RazonSocial, TipoDocumento, Documento, Correo, Telefono, Calle1, Calle2, Ciudad, Barrio, Activo, FechaRegistro)
                VALUES
                (@Nombres, @Apellidos, @RazonSocial, @TipoDocumento, @Documento, @Correo, @Telefono, @Calle1, @Calle2, @Ciudad, @Barrio, @Activo, GETDATE());
                SELECT SCOPE_IDENTITY();";

                    using (SqlCommand cmd = new SqlCommand(query, oConexion))
                    {
                        cmd.Parameters.AddWithValue("@Nombres", (object)p.Nombres ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Apellidos", (object)p.Apellidos ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@RazonSocial", (object)p.RazonSocial ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@TipoDocumento", (object)p.TipoDocumento ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Documento", (object)p.Documento ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Correo", (object)p.Correo ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Telefono", (object)p.Telefono ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Calle1", (object)p.Calle1 ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Calle2", (object)p.Calle2 ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Ciudad", (object)p.Ciudad ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Barrio", (object)p.Barrio ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@Activo", p.Activo);

                        oConexion.Open();
                        object result = cmd.ExecuteScalar();
                        int nuevoId = result != null ? Convert.ToInt32(result) : 0;

                        return (nuevoId > 0, "Persona registrada correctamente.", nuevoId);
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error al registrar persona: " + ex.Message, 0);
            }
        }



        // Eliminar persona (borrado lógico)
        public bool EliminarPersona(int idPersona)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = "UPDATE Persona SET Activo=0, FechaBaja=GETDATE() WHERE IdPersona=@IdPersona";
                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@IdPersona", idPersona);
                oConexion.Open();
                int filas = cmd.ExecuteNonQuery();
                return filas > 0;
            }
        }

        // Validar si ya existe el documento
        public bool ExisteDocumento(string documento)
        {
            bool existe = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = "SELECT 1 FROM Persona WHERE Documento=@Documento";
                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@Documento", documento);
                oConexion.Open();
                existe = cmd.ExecuteScalar() != null;
            }
            return existe;
        }
        public bool CambiarEstadoPersona(int idPersona, bool activo, bool afectarHijos)
        {
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                oConexion.Open();
                using (SqlTransaction tran = oConexion.BeginTransaction())
                {
                    try
                    {
                        // Verificar que la persona exista
                        string queryExist = "SELECT COUNT(1) FROM Persona WHERE IdPersona=@IdPersona";
                        SqlCommand cmdExist = new SqlCommand(queryExist, oConexion, tran);
                        cmdExist.Parameters.AddWithValue("@IdPersona", idPersona);
                        int existe = Convert.ToInt32(cmdExist.ExecuteScalar());
                        if (existe == 0)
                            throw new Exception("La persona no existe.");

                        // Actualizar Persona
                        string queryPersona = @"UPDATE Persona
                                        SET Activo=@Activo,
                                            FechaBaja = CASE WHEN @Activo=1 THEN NULL ELSE GETDATE() END
                                        WHERE IdPersona=@IdPersona";
                        SqlCommand cmdPersona = new SqlCommand(queryPersona, oConexion, tran);
                        cmdPersona.Parameters.AddWithValue("@IdPersona", idPersona);
                        cmdPersona.Parameters.AddWithValue("@Activo", activo);
                        cmdPersona.ExecuteNonQuery();

                        // Si se está desactivando, actualizar hijos
                        if (afectarHijos)
                        {
                            // Empleado
                            string queryEmpleado = @"UPDATE Empleado
                                             SET Activo=@Activo,
                                                 FechaBaja = CASE WHEN @Activo=1 THEN NULL ELSE GETDATE() END
                                             WHERE IdPersona=@IdPersona";
                            SqlCommand cmdEmpleado = new SqlCommand(queryEmpleado, oConexion, tran);
                            cmdEmpleado.Parameters.AddWithValue("@IdPersona", idPersona);
                            cmdEmpleado.Parameters.AddWithValue("@Activo", activo);
                            cmdEmpleado.ExecuteNonQuery();

                            // Usuario
                            string queryUsuario = @"UPDATE U
                                            SET U.Activo=@Activo,
                                                FechaBaja = CASE WHEN @Activo=1 THEN NULL ELSE GETDATE() END
                                            FROM Usuario U
                                            INNER JOIN Empleado E ON U.IdEmpleado = E.IdEmpleado
                                            WHERE E.IdPersona=@IdPersona";
                            SqlCommand cmdUsuario = new SqlCommand(queryUsuario, oConexion, tran);
                            cmdUsuario.Parameters.AddWithValue("@IdPersona", idPersona);
                            cmdUsuario.Parameters.AddWithValue("@Activo", activo);
                            cmdUsuario.ExecuteNonQuery();

                            // Cliente
                            string queryCliente = @"UPDATE C
                                            SET C.Activo=@Activo,
                                                FechaBaja = CASE WHEN @Activo=1 THEN NULL ELSE GETDATE() END
                                            FROM Cliente C
                                            INNER JOIN Persona P ON C.IdPersona = P.IdPersona
                                            WHERE P.IdPersona=@IdPersona";
                            SqlCommand cmdCliente = new SqlCommand(queryCliente, oConexion, tran);
                            cmdCliente.Parameters.AddWithValue("@IdPersona", idPersona);
                            cmdCliente.Parameters.AddWithValue("@Activo", activo);
                            cmdCliente.ExecuteNonQuery();
                        }

                        tran.Commit();
                        return true;
                    }
                    catch (Exception ex)
                    {
                        tran.Rollback();
                        throw new Exception("Error al cambiar estado: " + ex.Message);
                    }
                }
            }
        }

        public Persona ObtenerPersonaPorId(int idPersona)
        {
            Persona persona = null;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = "SELECT * FROM Persona WHERE IdPersona=@IdPersona";
                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@IdPersona", idPersona);
                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                if (dr.Read())
                {
                    persona = new Persona
                    {
                        IdPersona = Convert.ToInt32(dr["IdPersona"]),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        RazonSocial = dr["RazonSocial"].ToString(),
                        TipoDocumento = dr["TipoDocumento"].ToString(),
                        Documento = dr["Documento"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        Calle1 = dr["Calle1"].ToString(),
                        Calle2 = dr["Calle2"].ToString(),
                        Ciudad = dr["Ciudad"].ToString(),
                        Barrio = dr["Barrio"].ToString(),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                        FechaBaja = dr["FechaBaja"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaBaja"])
                    };
                }
                dr.Close();
            }
            return persona;
        }

        public (bool resultado, string mensaje) ActualizarPersona(Persona p)
        {
            try
            {
                using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
                {
                    oConexion.Open();
                    using (SqlTransaction tran = oConexion.BeginTransaction())
                    {
                        try
                        {
                            // ── 1. Actualizar Persona ─────────────────────────────
                            string queryPersona = @"
                UPDATE Persona SET
                    Nombres        = @Nombres,
                    Apellidos      = @Apellidos,
                    RazonSocial    = @RazonSocial,
                    TipoDocumento  = @TipoDocumento,
                    Documento      = @Documento,
                    Correo         = @Correo,
                    Telefono       = @Telefono,
                    Calle1         = @Calle1,
                    Calle2         = @Calle2,
                    Activo         = @Activo
                WHERE IdPersona = @IdPersona";

                            using (SqlCommand cmd = new SqlCommand(queryPersona, oConexion, tran))
                            {
                                cmd.Parameters.AddWithValue("@IdPersona",     p.IdPersona);
                                cmd.Parameters.AddWithValue("@Nombres",       (object)p.Nombres      ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Apellidos",     (object)p.Apellidos    ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@RazonSocial",   (object)p.RazonSocial  ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@TipoDocumento", (object)p.TipoDocumento ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Documento",     (object)p.Documento    ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Correo",        (object)p.Correo       ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Telefono",      (object)p.Telefono     ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Calle1",        (object)p.Calle1       ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Calle2",        (object)p.Calle2       ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@Activo",        p.Activo);

                                int filas = cmd.ExecuteNonQuery();
                                if (filas == 0)
                                {
                                    tran.Rollback();
                                    return (false, "No se pudo actualizar la persona.");
                                }
                            }

                            // ── 2. Propagar Nombres/Apellidos en cascada: Persona → Empleado → Usuario ──
                            // Regla: cambiar en Persona impacta hacia abajo en toda la jerarquía.
                            //        Cambiar en Empleado o Usuario NO impacta hacia arriba.
                            if (!string.IsNullOrEmpty(p.Nombres) || !string.IsNullOrEmpty(p.Apellidos))
                            {
                                // 2a. Propagar a Empleado
                                string queryEmpleado = @"
                UPDATE Empleado SET
                    Nombres   = @Nombres,
                    Apellidos = @Apellidos
                WHERE IdPersona = @IdPersona";

                                using (SqlCommand cmdEmp = new SqlCommand(queryEmpleado, oConexion, tran))
                                {
                                    cmdEmp.Parameters.AddWithValue("@IdPersona", p.IdPersona);
                                    cmdEmp.Parameters.AddWithValue("@Nombres",   (object)p.Nombres   ?? DBNull.Value);
                                    cmdEmp.Parameters.AddWithValue("@Apellidos", (object)p.Apellidos ?? DBNull.Value);
                                    cmdEmp.ExecuteNonQuery(); // No falla si no existe empleado vinculado
                                }

                                // 2b. Propagar a Usuario (a través de Empleado)
                                string queryUsuario = @"
                UPDATE U SET
                    U.Nombres   = @Nombres,
                    U.Apellidos = @Apellidos
                FROM Usuario U
                INNER JOIN Empleado E ON U.IdEmpleado = E.IdEmpleado
                WHERE E.IdPersona = @IdPersona";

                                using (SqlCommand cmdUsr = new SqlCommand(queryUsuario, oConexion, tran))
                                {
                                    cmdUsr.Parameters.AddWithValue("@IdPersona", p.IdPersona);
                                    cmdUsr.Parameters.AddWithValue("@Nombres",   (object)p.Nombres   ?? DBNull.Value);
                                    cmdUsr.Parameters.AddWithValue("@Apellidos", (object)p.Apellidos ?? DBNull.Value);
                                    cmdUsr.ExecuteNonQuery(); // No falla si no existe usuario vinculado
                                }
                            }

                            tran.Commit();
                            return (true, "Persona actualizada correctamente.");
                        }
                        catch (Exception ex)
                        {
                            tran.Rollback();
                            return (false, "Error al actualizar persona: " + ex.Message);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                return (false, "Error de conexión: " + ex.Message);
            }
        }


        public List<Persona> BuscarPersonasPorCI(string ci)
        {
            List<Persona> lista = new List<Persona>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                string query = @"SELECT * FROM Persona 
                         WHERE Activo = 1 AND Documento LIKE @CI + '%'";
                SqlCommand cmd = new SqlCommand(query, oConexion);
                cmd.Parameters.AddWithValue("@CI", ci);
                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    lista.Add(new Persona
                    {
                        IdPersona = Convert.ToInt32(dr["IdPersona"]),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        Documento = dr["Documento"].ToString(),
                        Ciudad = dr["Ciudad"].ToString(),
                        Barrio = dr["Barrio"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        Calle1 = dr["Calle1"].ToString(),
                        Calle2 = dr["Calle2"].ToString(),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"]),
                        FechaBaja = dr["FechaBaja"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(dr["FechaBaja"])
                    });
                }
                dr.Close();
            }
            return lista;
        }
        // Buscar persona por documento
        public Persona BuscarPorDocumento(string documento)
        {
            Persona persona = null;

            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(@"
                SELECT TOP 1 IdPersona, Documento, Nombres, Apellidos, Correo, Telefono, Activo
                FROM Persona
                WHERE Documento = @Documento", oConexion);

                cmd.Parameters.AddWithValue("@Documento", documento);

                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();

                if (dr.Read())
                {
                    persona = new Persona()
                    {
                        IdPersona = Convert.ToInt32(dr["IdPersona"]),
                        Documento = dr["Documento"].ToString(),
                        Nombres = dr["Nombres"].ToString(),
                        Apellidos = dr["Apellidos"].ToString(),
                        Correo = dr["Correo"].ToString(),
                        Telefono = dr["Telefono"].ToString(),
                        Activo = Convert.ToBoolean(dr["Activo"])
                    };
                }
                dr.Close();
            }

            return persona;
        }
    }
}
