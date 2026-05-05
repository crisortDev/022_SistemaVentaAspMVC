using System;

namespace CapaModelo
{
    /// <summary>
    /// Motivo tipificado para rechazar una OC.
    /// Mapea la tabla dbo.MOTIVO_RECHAZO_OC.
    /// </summary>
    public class MotivoRechazoOC
    {
        public int IdMotivoRechazo { get; set; }
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaRegistro { get; set; }
    }
}
