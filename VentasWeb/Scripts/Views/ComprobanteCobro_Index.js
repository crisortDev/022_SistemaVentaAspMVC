// ComprobanteCobro_Index.js
var dtCC = null;

$(function () {
    var hoy = new Date();
    var hace30 = new Date(); hace30.setDate(hoy.getDate() - 30);
    $('#txtFechaInicio').val(formatFecha(hace30));
    $('#txtFechaFin').val(formatFecha(hoy));
    dtCC = $('#tbCC').DataTable({
        data: [],
        columns: [
            { data: 'NumeroCobro' },
            { data: 'NumeroFactura' },
            { data: 'NombreCliente' },
            { data: 'NumeroDocumento' },
            { data: 'FormaCobro' },
            { data: 'MontoTotal', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'MontoRecibido', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'MontoCambio', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'NombreCajero' },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            { data: 'Estado' }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }, order: [[10, 'desc']]
    });
    buscarCC();
});

function buscarCC() {
    $.get($.MisUrls.url._CC_Obtener, { fechainicio: $('#txtFechaInicio').val(), fechafin: $('#txtFechaFin').val() }, function (r) {
        dtCC.clear().rows.add(r.data || []).draw();
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFecha(d) { return ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear(); }
