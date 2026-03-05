using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Security.Cryptography;
using System.Text;

namespace CapaDatos
{
    public class CD_HistorialClaves
    {
        private static CD_HistorialClaves _instancia = null;
        private CD_HistorialClaves() { }
        public static CD_HistorialClaves Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_HistorialClaves();
                return _instancia;
            }
        }

        private const int MAXIMO_HISTORIAL = 3;

        /// <summary>
        /// Verifica si la nueva clave ya fue usada en las últimas 3 contraseñas del usuario.
        /// </summary>
        public bool ClaveYaUsada(int idUsuario, string nuevaClaveHash)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                string sql = @"
                    SELECT TOP (@Maximo) ClaveHash
                    FROM HistorialClaves
                    WHERE IdUsuario = @IdUsuario
                    ORDER BY FechaCambio DESC";

                SqlCommand cmd = new SqlCommand(sql, cn);
                cmd.Parameters.AddWithValue("@IdUsuario", idUsuario);
                cmd.Parameters.AddWithValue("@Maximo", MAXIMO_HISTORIAL);

                cn.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    if (dr["ClaveHash"].ToString() == nuevaClaveHash)
                        return true; // ya fue usada
                }
                dr.Close();
            }
            return false;
        }

        /// <summary>
        /// Guarda la clave actual en el historial antes de cambiarla.
        /// Mantiene solo las últimas N claves por usuario.
        /// </summary>
        public void GuardarEnHistorial(int idUsuario, string claveHashActual)
        {
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                cn.Open();

                // Insertar la clave actual en el historial
                string sqlInsert = @"
                    INSERT INTO HistorialClaves (IdUsuario, ClaveHash, FechaCambio)
                    VALUES (@IdUsuario, @ClaveHash, GETDATE())";

                SqlCommand cmdInsert = new SqlCommand(sqlInsert, cn);
                cmdInsert.Parameters.AddWithValue("@IdUsuario", idUsuario);
                cmdInsert.Parameters.AddWithValue("@ClaveHash", claveHashActual);
                cmdInsert.ExecuteNonQuery();

                // Limpiar registros viejos — dejar solo los últimos MAXIMO_HISTORIAL
                string sqlLimpiar = @"
                    DELETE FROM HistorialClaves
                    WHERE IdUsuario = @IdUsuario
                      AND IdHistorial NOT IN (
                          SELECT TOP (@Maximo) IdHistorial
                          FROM HistorialClaves
                          WHERE IdUsuario = @IdUsuario
                          ORDER BY FechaCambio DESC
                      )";

                SqlCommand cmdLimpiar = new SqlCommand(sqlLimpiar, cn);
                cmdLimpiar.Parameters.AddWithValue("@IdUsuario", idUsuario);
                cmdLimpiar.Parameters.AddWithValue("@Maximo", MAXIMO_HISTORIAL);
                cmdLimpiar.ExecuteNonQuery();
            }
        }
    }
}