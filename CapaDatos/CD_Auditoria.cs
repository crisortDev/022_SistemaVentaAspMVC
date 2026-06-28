using System;
using System.Data.SqlClient;

namespace CapaDatos
{
    /// <summary>
    /// Registra eventos críticos del sistema en la tabla RegistroAuditoria.
    /// Uso: CD_Auditoria.Instancia.Registrar(idUsuario, "LOGIN_OK", "admin@gmail.com", ip);
    /// </summary>
    public class CD_Auditoria
    {
        // ── Acciones estándar ─────────────────────────────────────
        public const string LOGIN_OK         = "LOGIN_OK";
        public const string LOGIN_FAIL       = "LOGIN_FAIL";
        public const string CUENTA_BLOQUEADA = "CUENTA_BLOQUEADA";
        public const string LOGOUT           = "LOGOUT";
        public const string CAMBIO_CLAVE     = "CAMBIO_CLAVE";
        public const string CREAR            = "CREAR";
        public const string EDITAR           = "EDITAR";
        public const string ELIMINAR         = "ELIMINAR";
        public const string CAMBIO_ESTADO    = "CAMBIO_ESTADO";

        // ── Singleton ─────────────────────────────────────────────
        private static CD_Auditoria _instancia;
        private CD_Auditoria() { }
        public static CD_Auditoria Instancia
        {
            get
            {
                if (_instancia == null) _instancia = new CD_Auditoria();
                return _instancia;
            }
        }

        // ── Registrar evento ──────────────────────────────────────
        /// <summary>
        /// Inserta un registro en RegistroAuditoria.
        /// Los errores se silencian para no interrumpir el flujo principal.
        /// </summary>
        /// <param name="idUsuario">ID del usuario. Null si no aplica (ej: login fallido de correo desconocido).</param>
        /// <param name="accion">Constante de acción (usar las de esta clase).</param>
        /// <param name="detalle">Información adicional (correo, entidad afectada, etc.).</param>
        /// <param name="ip">Dirección IP del cliente.</param>
        public void Registrar(int? idUsuario, string accion, string detalle = null, string ip = null)
        {
            try
            {
                const string sql = @"
                    INSERT INTO RegistroAuditoria (IdUsuario, Accion, Detalle, DireccionIP, Fecha)
                    VALUES (@IdUsuario, @Accion, @Detalle, @DireccionIP, GETDATE())";

                using (var cn = new SqlConnection(Conexion.CN))
                using (var cmd = new SqlCommand(sql, cn))
                {
                    cmd.Parameters.AddWithValue("@IdUsuario",   (object)idUsuario ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Accion",      accion ?? "");
                    cmd.Parameters.AddWithValue("@Detalle",     (object)detalle ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DireccionIP", (object)ip ?? DBNull.Value);
                    cn.Open();
                    cmd.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                // La auditoría nunca debe tirar abajo el flujo principal
                System.Diagnostics.Trace.TraceWarning("[AUDITORIA] Error al registrar evento '{0}': {1}", accion, ex.Message);
            }
        }
    }
}
