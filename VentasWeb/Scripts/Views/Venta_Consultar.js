// Venta_Consultar.js
var dtVentas = null;

$(function () {
    var hoy = new Date();
    var hace30 = new Date(); hace30.setDate(hoy.getDate() - 30);
    $('#txtFechaInicio').val(formatFecha(hace30));
    $('#txtFechaFin').val(formatFecha(hoy));
    iniciarTabla();
    buscarVentas();
});

function iniciarTabla() {
    dtVentas = $('#tbVentas').DataTable({
        data: [],
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var btns = '<a href="' + $.MisUrls.url._Venta_Documento + '?idVenta=' + d.IdVenta +
                        '" target="_blank" class="btn btn-success btn-sm mr-1" title="Ver factura"><i class="fas fa-file-invoice"></i></a>';
                    if (d.Estado === 'Activa') {
                        btns += '<button class="btn btn-danger btn-sm" title="Anular" onclick="abrirAnular(' + d.IdVenta + ',\'' + escapar(d.NumeroFactura) + '\')"><i class="fas fa-ban"></i></button>';
                    }
                    return btns;
                }
            },
            { data: 'NumeroFactura' },
            { data: 'TipoFlujo', render: function (v) { return v === 'PreVenta' ? '<span class="badge badge-info">Pre-venta</span>' : '<span class="badge badge-success">Directa</span>'; } },
            { data: 'NombreCliente' },
            { data: 'FormaCobro', defaultContent: '' },
            { data: 'TotalCosto', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'NombreUsuario' },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            {
                data: 'Estado', render: function (v) {
                    return v === 'Activa'
                        ? '<span class="badge badge-success">Activa</span>'
                        : '<span class="badge badge-danger">Anulada</span>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[8, 'desc']]
    });
}

function buscarVentas() {
    var params = {
        fechainicio: $('#txtFechaInicio').val(),
        fechafin: $('#txtFechaFin').val(),
        numerofactura: $('#txtNumeroFactura').val(),
        tipoflujo: $('#cboTipoFlujo').val(),
        estado: $('#cboEstado').val()
    };
    $.get($.MisUrls.url._Venta_Obtener, params, function (r) {
        dtVentas.clear().rows.add(r.data || []).draw();
    });
}

function abrirAnular(id, factura) {
    $('#hdnIdVentaAnular').val(id);
    $('#lblFacturaAnular').text(factura);
    $('#txtMotivoAnulacion').val('');
    $('#modalAnular').modal('show');
}

function confirmarAnular() {
    var motivo = $('#txtMotivoAnulacion').val().trim();
    if (!motivo) { toastr.warning('Ingrese el motivo de anulación.'); return; }
    $.post($.MisUrls.url._Venta_Anular, { idVenta: $('#hdnIdVentaAnular').val(), motivo: motivo }, function (r) {
        if (r.resultado) {
            toastr.success('Venta anulada correctamente.');
            $('#modalAnular').modal('hide');
            buscarVentas();
        } else {
            toastr.error(r.mensaje || 'Error al anular.');
        }
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFecha(d) { return ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear(); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
