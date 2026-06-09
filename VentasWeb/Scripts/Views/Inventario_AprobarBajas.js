// Inventario_AprobarBajas.js — aprobación de bajas de stock
'use strict';

$(function () {
    activarMenu("Inventario");
    cargar();
    $('#btnBuscar').on('click', cargar);
});

function fmtFecha(dt) {
    if (!dt) return '—';
    var ms = /\/Date\((\d+)/.exec(dt);
    var f = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt.replace(' ', 'T'));
    if (isNaN(f.getTime())) return dt;
    var p = function (n) { return ('0' + n).slice(-2); };
    return p(f.getDate()) + '/' + p(f.getMonth() + 1) + '/' + f.getFullYear() + ' ' + p(f.getHours()) + ':' + p(f.getMinutes());
}

function badge(estado) {
    if (estado === 'Pendiente') return '<span class="badge badge-warning">Pendiente</span>';
    if (estado === 'Aprobada')  return '<span class="badge badge-success">Aprobada</span>';
    if (estado === 'Rechazada') return '<span class="badge badge-danger">Rechazada</span>';
    return '<span class="badge badge-secondary">' + estado + '</span>';
}

function cargar() {
    var estado = $('#ddlEstado').val();
    $.get($.MisUrls.url._Inv_ObtenerBajas, { estado: estado }, function (r) {
        var t = $('#tbodyBajas').empty();
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            t.append('<tr><td colspan="8" class="text-center text-muted">Sin registros.</td></tr>');
            return;
        }
        lista.forEach(function (b) {
            var acciones = '';
            if (b.EstadoAprobacion === 'Pendiente') {
                acciones =
                    '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobar(' + b.IdHistorial + ')" title="Aprobar"><i class="fas fa-check"></i></button>' +
                    '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazar(' + b.IdHistorial + ')" title="Rechazar"><i class="fas fa-times"></i></button>';
            } else {
                acciones = '<small class="text-muted">' + (b.UsuarioAprueba || '') + '</small>';
            }
            t.append('<tr>' +
                '<td>' + fmtFecha(b.FechaMovimiento) + '</td>' +
                '<td>' + (b.NombreTienda || '') + '</td>' +
                '<td>' + (b.CodigoProducto || '') + ' — ' + (b.NombreProducto || '') + '</td>' +
                '<td class="text-center">' + b.Cantidad + '</td>' +
                '<td>' + (b.MotivoBaja || '') + (b.Observaciones ? ' <small class="text-muted">(' + b.Observaciones + ')</small>' : '') + '</td>' +
                '<td>' + (b.UsuarioRegistro || '') + '</td>' +
                '<td class="text-center">' + badge(b.EstadoAprobacion) + '</td>' +
                '<td class="text-center">' + acciones + '</td>' +
                '</tr>');
        });
    });
}

function aprobar(id) {
    Swal.fire({
        title: '¿Aprobar baja?', text: 'Se descontará el stock del producto.',
        icon: 'question', showCancelButton: true, confirmButtonText: 'Sí, aprobar', confirmButtonColor: '#28a745'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarBaja, { idHistorial: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

function rechazar(id) {
    Swal.fire({
        title: 'Rechazar baja', input: 'text', inputLabel: 'Motivo del rechazo',
        inputPlaceholder: 'Ingrese el motivo...', showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        inputValidator: function (v) { if (!v) return 'Debe indicar un motivo.'; }
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RechazarBaja, { idHistorial: id, motivoRechazo: r.value }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}
