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
        /// Retorna el IdCaja de la sesión de caja actualmente abierta por este usuario.
        /// 0 si no hay caja abierta (p.ej. venta sin caja, o rol sin caja).
        /// </summary>
        protected int CajaId =>
            Session["CajaId"] is int id && id > 0 ? id : 0;

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