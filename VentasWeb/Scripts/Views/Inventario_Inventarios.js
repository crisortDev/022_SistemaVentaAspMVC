// Inventario_Inventarios.js — listado y aprobación de inventarios
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

function badge(e) {
    if (e === 'Pendiente') return '<span class="badge badge-warning">Pendiente</span>';
    if (e === 'Aprobado')  return '<span class="badge badge-success">Aprobado</span>';
    if (e === 'Rechazado') return '<span class="badge badge-danger">Rechazado</span>';
    return '<span class="badge badge-secondary">' + e + '</span>';
}

function cargar() {
    $.get($.MisUrls.url._Inv_ObtenerInventarios, { estado: $('#ddlEstado').val() }, function (r) {
        var t = $('#tbodyInv').empty();
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) { t.append('<tr><td colspan="8" class="text-center text-muted">Sin registros.</td></tr>'); return; }
        lista.forEach(function (i) {
            var acc = '<button class="btn btn-xs btn-info btn-sm mr-1" onclick="verDetalle(' + i.IdInventario + ",'" + (i.Numero || '') + "'" + ')" title="Ver detalle"><i class="fas fa-eye"></i></button>';
            if (i.Estado === 'Pendiente') {
                acc += '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobar(' + i.IdInventario + ')" title="Aprobar"><i class="fas fa-check"></i></button>' +
                       '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazar(' + i.IdInventario + ')" title="Rechazar"><i class="fas fa-times"></i></button>';
            }
            t.append('<tr>' +
                '<td>' + (i.Numero || '') + '</td>' +
                '<td>' + fmtFecha(i.FechaRegistro) + '</td>' +
                '<td>' + (i.NombreTienda || '') + '</td>' +
                '<td>' + (i.UsuarioRegistro || '') + '</td>' +
                '<td class="text-center">' + i.CantItems + '</td>' +
                '<td class="text-center">' + (i.CantDiferencias > 0 ? '<span class="text-danger font-weight-bold">' + i.CantDiferencias + '</span>' : '0') + '</td>' +
                '<td class="text-center">' + badge(i.Estado) + '</td>' +
                '<td class="text-center">' + acc + '</td>' +
                '</tr>');
        });
    });
}

function verDetalle(id, numero) {
    $('#lblNumero').text(numero);
    $.get($.MisUrls.url._Inv_ObtenerDetalleInventario, { idInventario: id }, function (r) {
        var t = $('#tbodyDet').empty();
        (r.data || []).forEach(function (d) {
            var dif = d.Diferencia;
            var col = dif === 0 ? '' : (dif > 0 ? 'text-success' : 'text-danger');
            t.append('<tr>' +
                '<td>' + (d.CodigoProducto || '') + ' — ' + (d.NombreProducto || '') + '</td>' +
                '<td class="text-center">' + d.StockSistema + '</td>' +
                '<td class="text-center">' + d.StockContado + '</td>' +
                '<td class="text-center ' + col + '"><strong>' + (dif > 0 ? '+' : '') + dif + '</strong></td>' +
                '</tr>');
        });
        $('#modalDetalle').modal('show');
    });
}

function aprobar(id) {
    Swal.fire({ title: '¿Aprobar inventario?', text: 'Se ajustará el stock al conteo físico.', icon: 'question',
        showCancelButton: true, confirmButtonText: 'Sí, aprobar', confirmButtonColor: '#28a745' })
        .then(function (r) {
            if (!r.isConfirmed) return;
            $.post($.MisUrls.url._Inv_AprobarInventario, { idInventario: id }, function (res) {
                if (res.resultado) { toastr.success(res.mensaje); cargar(); } else toastr.error(res.mensaje);
            });
        });
}

function rechazar(id) {
    Swal.fire({ title: 'Rechazar inventario', input: 'text', inputLabel: 'Motivo', showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        inputValidator: function (v) { if (!v) return 'Indique un motivo.'; } })
        .then(function (r) {
            if (!r.isConfirmed) return;
            $.post($.MisUrls.url._Inv_RechazarInventario, { idInventario: id, motivoRechazo: r.value }, function (res) {
                if (res.resultado) { toastr.success(res.mensaje); cargar(); } else toastr.error(res.mensaje);
            });
        });
}
