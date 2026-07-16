// NotaCreditoVenta_Index.js
var dtNCV = null;

$(function () {
    var hoy = new Date();
    var hace30 = new Date(); hace30.setDate(hoy.getDate() - 30);
    $('#txtFechaInicio').val(formatFecha(hace30));
    $('#txtFechaFin').val(formatFecha(hoy));
    iniciarTabla();
    cargarMotivos();
    buscarNCV();
});

function iniciarTabla() {
    dtNCV = $('#tbNCV').DataTable({
        data: [],
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    if (d.Estado !== 'Pendiente') return '—';
                    return '<button class="btn btn-success btn-sm mr-1" title="Aprobar" onclick="abrirAprobacion(' + d.IdNCVenta + ',\'' + escapar(d.NumeroNCV) + '\',\'' + escapar(d.NumeroFactura) + '\',\'' + escapar(d.NombreCliente) + '\',' + d.Monto + ',' + d.SaldoActualCliente + ',\'Aprobar\')"><i class="fas fa-check"></i></button>' +
                           '<button class="btn btn-danger btn-sm" title="Rechazar" onclick="abrirAprobacion(' + d.IdNCVenta + ',\'' + escapar(d.NumeroNCV) + '\',\'' + escapar(d.NumeroFactura) + '\',\'' + escapar(d.NombreCliente) + '\',' + d.Monto + ',' + d.SaldoActualCliente + ',\'Rechazar\')"><i class="fas fa-times"></i></button>';
                }
            },
            { data: 'NumeroNCV' },
            { data: 'NumeroFactura' },
            {
                data: null, render: function (d) {
                    var saldo = d.SaldoActualCliente || 0;
                    var badge = saldo > 0
                        ? ' <span class="badge badge-info" title="Saldo a favor vigente"><i class="fas fa-wallet mr-1"></i>Gs. ' + formatGs(saldo) + '</span>'
                        : '';
                    return escaparHtml(d.NombreCliente) + badge;
                }
            },
            { data: 'MotivoNC' },
            { data: 'Monto', className: 'text-right', render: function (v) { return 'Gs. ' + formatGs(v); } },
            { data: 'NombreRegistro' },
            { data: 'NombreTienda' },
            { data: 'FechaRegistro' },
            {
                data: 'Estado', render: function (v) {
                    var c = { 'Pendiente': 'warning', 'Aprobada': 'success', 'Rechazada': 'danger' };
                    return '<span class="badge badge-' + (c[v] || 'secondary') + '">' + v + '</span>';
                }
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[8, 'desc']]
    });
}

function cargarMotivos() {
    $.get($.MisUrls.url._NCV_Motivos, function (r) {
        if (r && r.data) {
            r.data.forEach(function (m) {
                $('#cboMotivoNC').append($('<option>', { value: m.IdMotivoNotaCredito, text: m.Descripcion }));
            });
        }
    });
}

function buscarNCV() {
    var params = {
        fechainicio: $('#txtFechaInicio').val(),
        fechafin:    $('#txtFechaFin').val(),
        estado:      $('#cboEstado').val()
    };
    $.get($.MisUrls.url._NCV_Obtener, params, function (r) {
        dtNCV.clear().rows.add(r.data || []).draw();
    });
}

// ─── REGISTRAR NC ───────────────────────────────────────────
function abrirModalRegistrar() {
    $('#txtBuscarFactura').val('');
    $('#hdnIdVentaNC').val(0);
    $('#infoVentaNC').addClass('d-none');
    $('#txtMontoNC').val(0);
    $('#txtObservacionNC').val('');
    $('#cboMotivoNC').val(0);
    $('#modalRegistrar').modal('show');
}

function buscarVentaParaNC() {
    var nroFactura = $('#txtBuscarFactura').val().trim();
    if (!nroFactura) { toastr.warning('Ingrese el número de factura.'); return; }

    // Buscar la venta por número de factura usando el endpoint de consulta de ventas
    $.get($.MisUrls.url._Venta_Obtener, { numerofactura: nroFactura, estado: 'Activa' }, function (r) {
        if (r.data && r.data.length > 0) {
            var v = r.data[0];
            $('#hdnIdVentaNC').val(v.IdVenta);
            $('#lblClienteNC').text(v.NombreCliente || '—');
            $('#lblTotalNC').text('Gs. ' + formatGs(v.TotalCosto));
            $('#infoVentaNC').removeClass('d-none');
            // Sugerir monto máximo
            $('#txtMontoNC').val(Math.round(v.TotalCosto));
        } else {
            toastr.warning('No se encontró una venta activa con ese número de factura.');
            $('#infoVentaNC').addClass('d-none');
            $('#hdnIdVentaNC').val(0);
        }
    });
}

function registrarNC() {
    var idVenta = parseInt($('#hdnIdVentaNC').val()) || 0;
    if (!idVenta) { toastr.warning('Busque y seleccione una factura válida.'); return; }
    var motivo = parseInt($('#cboMotivoNC').val());
    if (!motivo) { toastr.warning('Seleccione el motivo.'); return; }
    var monto = parseFloat($('#txtMontoNC').val()) || 0;
    if (monto <= 0) { toastr.warning('El monto debe ser mayor a cero.'); return; }

    $.ajax({
        url: $.MisUrls.url._NCV_Registrar,
        method: 'POST',
        data: { idVenta: idVenta, idMotivoNC: motivo, monto: monto, observacion: $('#txtObservacionNC').val() },
        success: function (r) {
            if (r.resultado) {
                toastr.success('Nota de crédito registrada. Pendiente de aprobación.');
                $('#modalRegistrar').modal('hide');
                buscarNCV();
            } else {
                toastr.error(r.mensaje || 'Error al registrar.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

// ─── APROBAR / RECHAZAR ──────────────────────────────────────
function abrirAprobacion(id, numero, factura, cliente, monto, saldoActual, accion) {
    $('#hdnIdNCV').val(id);
    $('#hdnAccionNCV').val(accion);
    $('#lblNcvAprobacion').text(numero);
    $('#lblVentaAprobacion').text(factura);
    $('#lblMontoAprobacion').text('Gs. ' + formatGs(monto));
    $('#txtMotivoRechazo').val('');

    // Mostrar info de saldo a favor solo al aprobar
    if (accion === 'Aprobar') {
        var saldoNuevo = (saldoActual || 0) + monto;
        var infoSaldo = '<div class="alert alert-info mt-2 mb-0 py-2">' +
            '<i class="fas fa-wallet mr-1"></i> ' +
            '<strong>' + cliente + '</strong> recibirá <strong>Gs. ' + formatGs(monto) + '</strong> como saldo a favor.' +
            (saldoActual > 0
                ? ' Saldo actual: Gs. ' + formatGs(saldoActual) + ' → nuevo total: <strong>Gs. ' + formatGs(saldoNuevo) + '</strong>.'
                : '') +
            '<br><small class="text-muted">Se aplicará automáticamente en la próxima venta.</small>' +
            '</div>';
        $('#divInfoSaldoFavor').html(infoSaldo).removeClass('d-none');
        $('#divMotivoRechazo').addClass('d-none');
        $('#modalAprobacionHeader').removeClass('bg-danger').addClass('bg-success');
        $('#lblTituloAprobacion').html('<i class="fas fa-check mr-1"></i> Aprobar Nota de Crédito');
        $('#btnConfirmarAprobacion').removeClass('btn-danger').addClass('btn-success');
    } else {
        $('#divInfoSaldoFavor').addClass('d-none').html('');
        $('#divMotivoRechazo').removeClass('d-none');
        $('#modalAprobacionHeader').removeClass('bg-success').addClass('bg-danger');
        $('#lblTituloAprobacion').html('<i class="fas fa-times mr-1"></i> Rechazar Nota de Crédito');
        $('#btnConfirmarAprobacion').removeClass('btn-success').addClass('btn-danger');
    }
    $('#modalAprobacion').modal('show');
}

function confirmarAprobacion() {
    var accion = $('#hdnAccionNCV').val();
    var motivo = $('#txtMotivoRechazo').val().trim();
    if (accion === 'Rechazar' && !motivo) { toastr.warning('Ingrese el motivo del rechazo.'); return; }

    $.ajax({
        url: $.MisUrls.url._NCV_AprobarRechazar,
        method: 'POST',
        data: { idNCVenta: $('#hdnIdNCV').val(), accion: accion, motivoRechazo: motivo },
        success: function (r) {
            if (r.resultado) {
                toastr.success('Nota de crédito ' + accion.toLowerCase() + 'da correctamente.');
                $('#modalAprobacion').modal('hide');
                buscarNCV();
            } else {
                toastr.error(r.mensaje || 'Error al procesar.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function formatFecha(d) { return ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + '/' + d.getFullYear(); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
function escaparHtml(s) {
    return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
