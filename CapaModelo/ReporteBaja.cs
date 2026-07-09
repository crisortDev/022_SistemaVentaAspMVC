using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CapaModelo
{
    namespace CapaModelo
    {
        public class ReporteBaja
        {
            public int    IdHistorial      { get; set; }
            public string Numero           { get; set; }
            public string FechaMovimiento  { get; set; }
            public string CodigoProducto   { get; set; }
            public string NombreProducto   { get; set; }
            public string NombreTienda     { get; set; }
            public string RucTienda        { get; set; }
            public string MotivoBaja       { get; set; }
            public string Observaciones    { get; set; }
            public int    Cantidad         { get; set; }
            public string EstadoAprobacion { get; set; }
            public string UsuarioRegistro  { get; set; }
            public string UsuarioAprueba   { get; set; }
            public string FechaAprobacion  { get; set; }
            public string  MotivoRechazo    { get; set; }
            public decimal CostoPromedio    { get; set; }
        }
    }
}
