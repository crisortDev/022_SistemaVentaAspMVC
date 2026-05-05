using CapaModelo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace CapaDatos
{
    /// <summary>
    /// Capa de datos para Categoría de Orden de Compra.
    /// Mapea la tabla dbo.CATEGORIA_ORDEN_COMPRA.
    /// </summary>
    public class CD_CategoriaOC
    {
        private static CD_CategoriaOC _instancia = null;
        private CD_CategoriaOC() { }
        public static CD_CategoriaOC Instancia
        {
            get { if (_instancia == null) _instancia = new CD_CategoriaOC(); return _instancia; }
        }

        /// <summary>
        /// Retorna todas las categorías activas para llenar combos.
        /// </summary>
        public List<CategoriaOC> Obtener()
        {
            var lista = new List<CategoriaOC>();
            using (SqlConnection cn = new SqlConnection(Conexion.CN))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT IdCategoriaOC, Descripcion FROM dbo.CATEGORIA_ORDEN_COMPRA WHERE Activo = 1 ORDER BY Descripcion",
                    cn);
                cmd.CommandType = CommandType.Text;
                try
                {
                    cn.Open();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        while (dr.Read())
                        {
                            lista.Add(new CategoriaOC
                            {
                                IdCategoriaOC = Convert.ToInt32(dr["IdCategoriaOC"]),
                                Descripcion   = dr["Descripcion"].ToString(),
                                Activo        = true
                            });
                        }
                    }
                }
                catch (Exception) { lista = new List<CategoriaOC>(); }
            }
            return lista;
        }
    }
}
