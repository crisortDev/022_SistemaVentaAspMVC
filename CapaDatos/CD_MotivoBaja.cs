using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_MotivoBaja
    {
        private static CD_MotivoBaja _instancia = null;
        private CD_MotivoBaja() { }

        public static CD_MotivoBaja Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_MotivoBaja();
                return _instancia;
            }
        }

        // Usado por MotivoBajaController y ProductoController
        public List<MotivoBaja> ObtenerMotivosBaja()
        {
            var lista = new List<MotivoBaja>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT IdMotivoBaja, Descripcion, Activo, FechaRegistro FROM MotivoBaja WHERE Activo = 1 ORDER BY Descripcion",
                    oConexion);
                try
                {
                    oConexion.Open();
                    SqlDataReader dr = cmd.ExecuteReader();
                    while (dr.Read())
                    {
                        lista.Add(new MotivoBaja
                        {
                            IdMotivoBaja = Convert.ToInt32(dr["IdMotivoBaja"]),
                            Descripcion = dr["Descripcion"].ToString(),
                            Activo = Convert.ToBoolean(dr["Activo"]),
                            FechaRegistro = Convert.ToDateTime(dr["FechaRegistro"])
                        });
                    }
                    dr.Close();
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ObtenerMotivosBaja: " + ex.Message);
                }
            }
            return lista;
        }

        public bool RegistrarMotivoBaja(MotivoBaja oMotivo)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                // Verifica duplicado antes de insertar
                SqlCommand cmdCheck = new SqlCommand(
                    "SELECT COUNT(1) FROM MotivoBaja WHERE Descripcion = @Descripcion",
                    oConexion);
                cmdCheck.Parameters.AddWithValue("@Descripcion", oMotivo.Descripcion);

                try
                {
                    oConexion.Open();
                    int existe = Convert.ToInt32(cmdCheck.ExecuteScalar());
                    if (existe > 0) return false; // ya existe

                    SqlCommand cmd = new SqlCommand(
                        "INSERT INTO MotivoBaja (Descripcion, Activo, FechaRegistro) VALUES (@Descripcion, 1, GETDATE())",
                        oConexion);
                    cmd.Parameters.AddWithValue("@Descripcion", oMotivo.Descripcion);
                    respuesta = cmd.ExecuteNonQuery() > 0;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error RegistrarMotivoBaja: " + ex.Message);
                }
            }
            return respuesta;
        }

        public bool ModificarMotivoBaja(MotivoBaja oMotivo)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                // Verifica duplicado en otro registro
                SqlCommand cmdCheck = new SqlCommand(
                    "SELECT COUNT(1) FROM MotivoBaja WHERE Descripcion = @Descripcion AND IdMotivoBaja <> @IdMotivoBaja",
                    oConexion);
                cmdCheck.Parameters.AddWithValue("@Descripcion", oMotivo.Descripcion);
                cmdCheck.Parameters.AddWithValue("@IdMotivoBaja", oMotivo.IdMotivoBaja);

                try
                {
                    oConexion.Open();
                    int existe = Convert.ToInt32(cmdCheck.ExecuteScalar());
                    if (existe > 0) return false;

                    SqlCommand cmd = new SqlCommand(
                        "UPDATE MotivoBaja SET Descripcion = @Descripcion WHERE IdMotivoBaja = @IdMotivoBaja",
                        oConexion);
                    cmd.Parameters.AddWithValue("@Descripcion", oMotivo.Descripcion);
                    cmd.Parameters.AddWithValue("@IdMotivoBaja", oMotivo.IdMotivoBaja);
                    respuesta = cmd.ExecuteNonQuery() > 0;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error ModificarMotivoBaja: " + ex.Message);
                }
            }
            return respuesta;
        }

        public bool EliminarMotivoBaja(int idMotivoBaja)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                // Verificar si está en uso en HISTORIAL_MOVIMIENTO antes de eliminar
                SqlCommand cmdCheck = new SqlCommand(
                    "SELECT COUNT(1) FROM HISTORIAL_MOVIMIENTO WHERE IdMotivoBaja = @IdMotivoBaja",
                    oConexion);
                cmdCheck.Parameters.AddWithValue("@IdMotivoBaja", idMotivoBaja);

                try
                {
                    oConexion.Open();
                    int enUso = Convert.ToInt32(cmdCheck.ExecuteScalar());
                    if (enUso > 0) return false; // no eliminar si está en uso

                    SqlCommand cmd = new SqlCommand(
                        "UPDATE MotivoBaja SET Activo = 0 WHERE IdMotivoBaja = @IdMotivoBaja",
                        oConexion);
                    cmd.Parameters.AddWithValue("@IdMotivoBaja", idMotivoBaja);
                    respuesta = cmd.ExecuteNonQuery() > 0;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("Error EliminarMotivoBaja: " + ex.Message);
                }
            }
            return respuesta;
        }
    }
}