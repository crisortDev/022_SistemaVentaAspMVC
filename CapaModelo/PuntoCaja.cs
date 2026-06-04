using System;

namespace CapaModelo
{
    /// <summary>
    /// Representa un punto de caja físico dentro de una tienda (Caja 1, Caja 2, etc.)
    /// Es el MAESTRO del módulo de cajas; las sesiones (CAJA) son el DETALLE.
    /// </summary>
    public class PuntoCaja
    {
        public int      IdPuntoCaja    { get; set; }
        public int      IdTienda       { get; set; }
        public string   NombreTienda   { get; set; }
        public string   Nombre         { get; set; }
        public string   Descripcion    { get; set; }
        public bool     Activo         { get; set; }
        public DateTime FechaRegistro  { get; set; }

        // Datos DNIT (informativos en la grilla de gestión)
        public string   Codigo          { get; set; }   // nomenclatura caja, ej: CJ-001
        public string   PuntoExpedicion { get; set; }   // ej: 001
        public int      SecuenciaActual { get; set; }   // última factura emitida por esta caja
        public string   EstadoOperativo { get; set; }   // Activo / Inactivo

        // Calculados (para la vista maestro)
        public int      TotalSesiones  { get; set; }
        public int      SesionesAbiertas { get; set; }
        public DateTime? UltimaApertura { get; set; }
    }

    /// <summary>
    /// Sesión de caja asociada a un punto (para el DETALLE del maestro/detalle).
    /// </summary>
    public class SesionCajaPunto
    {
        public int      IdCaja          { get; set; }
        public string   Aperturista     { get; set; }
        public DateTime FechaApertura   { get; set; }
        public decimal  MontoApertura   { get; set; }
        public DateTime? FechaCierre    { get; set; }
        public string   UsuarioCierre   { get; set; }
        public decimal? MontoSistema    { get; set; }
        public decimal? MontoContado    { get; set; }
        public decimal? Diferencia      { get; set; }
        public string   Estado          { get; set; }
        public string   Observacion     { get; set; }
        public int      CantidadVentas  { get; set; }
        public decimal  TotalVentas     { get; set; }
    }
}
