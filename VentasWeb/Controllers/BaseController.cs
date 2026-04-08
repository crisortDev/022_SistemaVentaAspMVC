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
        /// </summary>
        protected bool EsSuperAdmin =>
            Session["EsSuperAdmin"] != null && (bool)Session["EsSuperAdmin"];

        /// <summary>
        /// Retorna el IdTienda activo en sesión.
        /// 0 significa acceso global (SuperAdmin).
        /// </summary>
        protected int TiendaActiva =>
            Session["TiendaActiva"] != null ? (int)Session["TiendaActiva"] : 0;

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
    }
}