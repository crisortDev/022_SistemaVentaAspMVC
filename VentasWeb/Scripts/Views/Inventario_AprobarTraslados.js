// Inventario_AprobarTraslados.js — aprobación de traslados entre sucursales
'use strict';

$(function () {
    activarMenu("Aprobar Traslados");
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
    if (estado === 'Aprobado')  return '<span class="badge badge-success">Aprobado</span>';
    if (estado === 'Rechazado') return '<span class="badge badge-danger">Rechazado</span>';
    return '<span class="badge badge-secondary">' + (estado || '') + '</span>';
}

function cargar() {
    var estado  = $('#ddlEstado').val();
    var url     = estado === 'Pendiente'
                    ? $.MisUrls.url._Inv_ObtenerTrasladosPendientes
                    : $.MisUrls.url._Inv_ObtenerHistorialTraslados;
    var params  = estado === 'Pendiente'
                    ? {}
                    : {
                        fechainicio: obtenerFechaHoy(-30),
                        fechafin:    obtenerFechaHoy(0),
                        estado:      estado
                      };

    $.get(url, params, function (r) {
        var t = $('#tbodyTraslados').empty();
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            t.append('<tr><td colspan="9" class="text-center text-muted">Sin registros.</td></tr>');
            return;
        }
        lista.forEach(function (tr) {
            var acciones = '';
            if (tr.EstadoAprobacion === 'Pendiente') {
                acciones =
                    '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobar(' + tr.IdTraslado + ')" title="Aprobar"><i class="fas fa-check"></i></button>' +
                    '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazar(' + tr.IdTraslado + ')" title="Rechazar"><i class="fas fa-times"></i></button>';
            } else {
                var aprobador = (tr.UsuarioAprueba || '') + (tr.FechaAprobacion ? '<br><small>' + fmtFecha(tr.FechaAprobacion) + '</small>' : '');
                acciones = '<small class="text-muted">' + aprobador + '</small>';
            }
            var extra = tr.EstadoAprobacion === 'Rechazado' && tr.MotivoRechazo
                ? '<br><small class="text-danger">' + tr.MotivoRechazo + '</small>' : '';
            t.append('<tr>' +
                '<td><span class="badge badge-light border">' + (tr.Numero || '') + '</span></td>' +
                '<td>' + fmtFecha(tr.FechaTraslado) + '</td>' +
                '<td>' + (tr.CodigoProducto || '') + ' — ' + (tr.NombreProducto || '') + '</td>' +
                '<td class="text-center">' + tr.Cantidad + '</td>' +
                '<td>' + (tr.TiendaOrigen || '') + '</td>' +
                '<td>' + (tr.TiendaDestino || '') + '</td>' +
                '<td>' + (tr.Usuario || '') + '</td>' +
                '<td class="text-center">' + badge(tr.EstadoAprobacion) + extra + '</td>' +
                '<td class="text-center">' + acciones + '</td>' +
                '</tr>');
        });
    });
}

function aprobar(id) {
    Swal.fire({
        title: '¿Aprobar traslado?',
        text: 'El stock se moverá de la sucursal origen a la sucursal destino.',
        icon: 'question', showCancelButton: true,
        confirmButtonText: 'Sí, aprobar', confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarTraslado, { idTraslado: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

function rechazar(id) {
    Swal.fire({
        title: 'Rechazar traslado', input: 'text', inputLabel: 'Motivo del rechazo',
        inputPlaceholder: 'Ingrese el motivo...', showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        cancelButtonText: 'Cancelar',
        inputValidator: function (v) { if (!v) return 'Debe indicar un motivo.'; }
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RechazarTraslado, { idTraslado: id, motivoRechazo: r.value }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

function obtenerFechaHoy(offsetDias) {
    var d = new Date();
    d.setDate(d.getDate() + (offsetDias || 0));
    var day   = ('0' + d.getDate()).slice(-2);
    var month = ('0' + (d.getMonth() + 1)).slice(-2);
    return day + '/' + month + '/' + d.getFullYear();
}
