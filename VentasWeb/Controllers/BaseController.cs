using CapaDatos;
using CapaModelo;
using System.Web.Mvc;

namespace VentasWeb.Controllers
{
    /// <summary>
    /// Controlador base del que deben heredar todos los controllers del sistema.
    /// Centraliza la lógica de permisos por sucursal y rol SuperAdmin.
    /// </summary>
    public class BaseController : Controller
    {
        // ── Constante del IdRol SuperAdmin ────────────────────────
        protected const int ID_ROL_SUPERADMIN = 14;

        // ── Propiedades de sesión ─────────────────────────────────

        /// <summary>
        /// Retorna true si el usuario logueado es SuperAdmin (acceso global).
        /// Usa pattern matching seguro para evitar excepciones por tipo incorrecto en sesión.
        /// </summary>
        protected bool EsSuperAdmin =>
            Session["EsSuperAdmin"] is bool val && val;

        /// <summary>
        /// Retorna el IdTienda activo en sesión.
        /// 0 significa acceso global (SuperAdmin).
        /// </summary>
        protected int TiendaActiva =>
            Session["TiendaActiva"] is int tienda ? tienda : 0;

        /// <summary>
        /// Retorna el IdTienda operativo para registrar ventas y pre-ventas.
        /// Prioridad: tienda de la caja abierta > TiendaActiva > 1 (central).
        /// Garantiza que ventas y pre-ventas siempre queden en la misma sucursal que la caja.
        /// </summary>
        protected int TiendaOperativa
        {
            get
            {
                if (Session["CajaIdTienda"] is int cajaTienda && cajaTienda > 0)
                    return cajaTienda;
                if (TiendaActiva > 0)
                    return TiendaActiva;
                return 1;
            }
        }

        /// <summary>
        /// Retorna el IdCaja de la caja abierta para este usuario/tienda.
        /// Prioridad: lo guardado en sesión al abrir; si no, busca la caja abierta
        /// de la tienda en la BD (cubre sesiones web expiradas o re-ingresos).
        /// 0 si no hay ninguna caja abierta.
        /// </summary>
        protected int CajaId
        {
            get
            {
                if (Session["CajaId"] is int id && id > 0)
                    return id;

                // Respaldo: buscar la caja abierta de la tienda en la BD
                int idTienda = TiendaActiva;
                var usr = UsuarioActual;
                if (idTienda > 0 && usr != null)
                {
                    // Solo la caja abierta POR ESTE usuario (no la de otro cajero)
                    var caja = CapaDatos.CD_CajaVenta.Instancia.ObtenerCajaActiva(idTienda, usr.IdUsuario);
                    if (caja != null && caja.IdCaja > 0)
                    {
                        Session["CajaId"]       = caja.IdCaja;
                        Session["CajaIdTienda"] = idTienda;
                        return caja.IdCaja;
                    }
                }
                return 0;
            }
        }

        /// <summary>
        /// Retorna el usuario logueado desde sesión, o null si no hay sesión.
        /// </summary>
        protected Usuario UsuarioActual =>
            Session["Usuario"] as Usuario;

        // ── Métodos de permiso ────────────────────────────────────

        /// <summary>
        /// Verifica si el usuario tiene permiso para operar sobre un registro
        /// de una tienda específica.
        /// - SuperAdmin: siempre true (sin restricción de sucursal).
        /// - Otros roles: solo si la tienda del registro coincide con su TiendaActiva.
        /// </summary>
        /// <param name="idTiendaDelRegistro">IdTienda del registro a operar.</param>
        protected bool TienePermiso(int idTiendaDelRegistro)
        {
            if (EsSuperAdmin) return true;
            return TiendaActiva == idTiendaDelRegistro;
        }

        /// <summary>
        /// Verifica si hay un usuario logueado en sesión.
        /// </summary>
        protected bool HaySesion() => UsuarioActual != null;

        /// <summary>
        /// Retorna un Json estándar de acceso denegado por sucursal.
        /// </summary>
        protected JsonResult AccesoDenegado() =>
            Json(new
            {
                resultado = false,
                mensaje = "No tiene permisos para operar en esta sucursal."
            });

        // ── Auditoría ─────────────────────────────────────────────
        /// <summary>
        /// Registra un evento de auditoría usando la sesión activa.
        /// Llamar desde cualquier controller heredado.
        /// Ejemplo: RegistrarAuditoria(CD_Auditoria.CREAR, "Producto: Mouse Gamer");
        /// </summary>
        protected void RegistrarAuditoria(string accion, string detalle = null)
        {
            var usr = UsuarioActual;
            CD_Auditoria.Instancia.Registrar(
                idUsuario: usr?.IdUsuario,
                accion:    accion,
                detalle:   detalle,
                ip:        Request?.UserHostAddress
            );
        }
    }
}