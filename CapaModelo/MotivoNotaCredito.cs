using System;

namespace CapaModelo
{
    /// <summary>
    /// Motivo tipificado para emitir una Nota de Crédito sobre una Compra.
    /// Mapea la tabla dbo.MOTIVO_NOTA_CREDITO.
    /// </summary>
    public class MotivoNotaCredito
    {
        public int    IdMotivoNotaCredito { get; set; }
        public string Descripcion         { get; set; }
        public bool   Activo              { get; set; }
        public DateTime FechaRegistro     { get; set; }
    }
}
