using System;
using System.Collections.Generic;

namespace CapaModelo
{
    public class Usuario
    {
        // ── Identificación ────────────────────────────────────────
        public int IdUsuario { get; set; }
        public int IdEmpleado { get; set; }

        // ── Datos personales ──────────────────────────────────────
        public string Nombres { get; set; }
        public string Apellidos { get; set; }
        public string Correo { get; set; }
        public string NombreUsuario { get; set; }   // flujo OTP

        // ── Credenciales ──────────────────────────────────────────
        public string Clave { get; set; }

        // ── Contraseña temporal / OTP ─────────────────────────────
        public string PasswordTemporalHash { get; set; }
        public DateTime? PasswordTemporalExpira { get; set; }   // nullable → usa .HasValue
        public bool RequiereCambioPassword { get; set; }
        public string OTP { get; set; }
        public DateTime? FechaOTP { get; set; }

        // ── Asignación ────────────────────────────────────────────
        public int IdRol { get; set; }

        /// <summary>
        /// NULL indica que el usuario es SuperAdmin con acceso global a todas las sucursales.
        /// Cualquier valor distinto de NULL restringe al usuario a esa sucursal.
        /// </summary>
        public int? IdTienda { get; set; }

        // ── Estado y auditoría ────────────────────────────────────
        public bool Activo { get; set; }
        public byte EstadoUsuario { get; set; }     // tinyint — 0=Pendiente,1=Activo,2=Inactivo
        public int IntentosFallidos { get; set; }   // no existe Bloqueado en la BD
        public DateTime FechaRegistro { get; set; }
        public DateTime FechaActivacion { get; set; }
        public DateTime FechaBaja { get; set; }
        public DateTime FechaUltimoLogin { get; set; }
        public DateTime? FechaCambioPassword { get; set; }

        // ── Propiedades de navegación ─────────────────────────────
        public Rol oRol { get; set; }
        public Tienda oTienda { get; set; }
        public List<Menu> oListaMenu { get; set; }

        // ── Helpers de rol ────────────────────────────────────────
        /// <summary>
        /// True si el usuario es SuperAdmin (IdRol == 14 e IdTienda == null).
        /// </summary>
        public bool EsSuperAdmin => IdRol == 14 && !IdTienda.HasValue;
    }
}