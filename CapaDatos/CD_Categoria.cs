using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    public class CD_Categoria
    {
        public static CD_Categoria _instancia = null;
        private CD_Categoria() { }

        public static CD_Categoria Instancia
        {
            get
            {
                if (_instancia == null)
                    _instancia = new CD_Categoria();
                return _instancia;
            }
        }

        // ── Obtener todas las categorías ──────────────────────────
        // Retorna lista vacía (nunca null) para evitar NullReferenceException en DataTables.
        // Lanza excepción hacia arriba para que el controller pueda loguearla y reportarla.
        public List<Categoria> ObtenerCategoria()
        {
            List<Categoria> lista = new List<Categoria>();
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand("usp_ObtenerCategorias", oConexion)
                { CommandType = CommandType.StoredProcedure };

                oConexion.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    lista.Add(new Categoria
                    {
                        IdCategoria = Convert.ToInt32(dr["IdCategoria"]),
                        Descripcion = dr["Descripcion"].ToString(),
                        Activo = Convert.ToBoolean(dr["Activo"]),
                        PorcentajeGanancia = dr["PorcentajeGanancia"] != DBNull.Value
                                                   ? Convert.ToDecimal(dr["PorcentajeGanancia"])
                                                   : 0,
                        UnidadMedida = dr["UnidadMedida"] != DBNull.Value
                                                   ? dr["UnidadMedida"].ToString()
                                                   : "Unidad",
                        DescuentoMaxPermitido = dr["DescuentoMaxPermitido"] != DBNull.Value
                                                   ? Convert.ToDecimal(dr["DescuentoMaxPermitido"])
                                                   : 0,
                        FechaModificacion = dr["FechaModificacion"] != DBNull.Value
                                                   ? (DateTime?)Convert.ToDateTime(dr["FechaModificacion"])
                                                   : null,
                        UsuarioModificacion = dr["UsuarioModificacion"] != DBNull.Value
                                                   ? dr["UsuarioModificacion"].ToString()
                                                   : null
                    });
                }
                dr.Close();
            }
            return lista;
        }

        // ── Registrar nueva categoría ─────────────────────────────
        public bool RegistrarCategoria(Categoria oCategoria)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_RegistrarCategoria", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("@Descripcion", oCategoria.Descripcion);
                    cmd.Parameters.AddWithValue("@PorcentajeGanancia", oCategoria.PorcentajeGanancia);
                    cmd.Parameters.AddWithValue("@UnidadMedida", oCategoria.UnidadMedida ?? "Unidad");
                    cmd.Parameters.AddWithValue("@DescuentoMaxPermitido", oCategoria.DescuentoMaxPermitido);
                    cmd.Parameters.AddWithValue("@UsuarioModificacion", oCategoria.UsuarioModificacion ?? (object)DBNull.Value);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        // ── Modificar categoría existente ─────────────────────────
        public bool ModificarCategoria(Categoria oCategoria)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    SqlCommand cmd = new SqlCommand("usp_ModificarCategoria", oConexion)
                    { CommandType = CommandType.StoredProcedure };

                    cmd.Parameters.AddWithValue("@IdCategoria", oCategoria.IdCategoria);
                    cmd.Parameters.AddWithValue("@Descripcion", oCategoria.Descripcion);
                    cmd.Parameters.AddWithValue("@Activo", oCategoria.Activo);
                    cmd.Parameters.AddWithValue("@PorcentajeGanancia", oCategoria.PorcentajeGanancia);
                    cmd.Parameters.AddWithValue("@UnidadMedida", oCategoria.UnidadMedida ?? "Unidad");
                    cmd.Parameters.AddWithValue("@DescuentoMaxPermitido", oCategoria.DescuentoMaxPermitido);
                    cmd.Parameters.AddWithValue("@UsuarioModificacion", oCategoria.UsuarioModificacion ?? (object)DBNull.Value);
                    cmd.Parameters.Add("@Resultado", SqlDbType.Bit).Direction = ParameterDirection.Output;

                    oConexion.Open();
                    cmd.ExecuteNonQuery();
                    respuesta = Convert.ToBoolean(cmd.Parameters["@Resultado"].Value);
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }

        // ── Borrado lógico (activa / desactiva) ───────────────────
        public bool CambiarEstadoCategoria(int idCategoria, bool activo, string usuarioModificacion = null)
        {
            bool respuesta = false;
            using (SqlConnection oConexion = new SqlConnection(Conexion.CN))
            {
                try
                {
                    string query = @"UPDATE CATEGORIA
                                     SET    Activo              = @Activo,
                                            FechaModificacion   = GETDATE(),
                                            UsuarioModificacion = @UsuarioModificacion
                                     WHERE  IdCategoria = @IdCategoria";

                    using (SqlCommand cmd = new SqlCommand(query, oConexion))
                    {
                        cmd.Parameters.AddWithValue("@Activo", activo);
                        cmd.Parameters.AddWithValue("@IdCategoria", idCategoria);
                        cmd.Parameters.AddWithValue("@UsuarioModificacion", usuarioModificacion ?? (object)DBNull.Value);
                        oConexion.Open();
                        respuesta = cmd.ExecuteNonQuery() > 0;
                    }
                }
                catch { respuesta = false; }
            }
            return respuesta;
        }
    }
}