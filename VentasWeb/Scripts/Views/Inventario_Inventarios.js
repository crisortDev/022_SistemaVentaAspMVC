// Inventario_Inventarios.js — Gestión de inventarios (vista del Supervisor)
'use strict';

var inventarioSeleccionado = 0;

$(function () {
    activarMenu("Inventario");
    cargar();
    $('#btnBuscar').on('click', cargar);

    // ── Nuevo inventario ──────────────────────────────────────────────────────
    $('#btnNuevoInventario').on('click', function () {
        if (AppSession.esSuperAdmin) {
            $.get($.MisUrls.url._ObtenerTiendas, function (r) {
                var $cbo = $('#cboTiendaNuevo').empty().append('<option value="">-- Seleccione --</option>');
                ((r && r.data) ? r.data : []).filter(function (t) { return t.Activo; }).forEach(function (t) {
                    $cbo.append($('<option>').val(t.IdTienda).text(t.Nombre));
                });
                if (AppSession.tiendaOperativa) $cbo.val(AppSession.tiendaOperativa);
            });
        } else {
            $('#cboTiendaNuevo').val(AppSession.tiendaOperativa);
            $.get($.MisUrls.url._ObtenerTiendas, function (r) {
                var t = ((r && r.data) ? r.data : []).find(function (x) { return x.IdTienda == AppSession.tiendaOperativa; });
                $('#lblTiendaNuevo').text(t ? t.Nombre : 'Sucursal ' + AppSession.tiendaOperativa);
            });
        }
        $('#txtObsNuevo').val('');
        $('#modalNuevo').modal('show');
    });

    $('#btnConfirmarNuevo').on('click', function () {
        var idTienda = parseInt($('#cboTiendaNuevo').val()) || 0;
        if (idTienda === 0) { toastr.warning('Seleccioná una sucursal.'); return; }
        $.post($.MisUrls.url._Inv_CrearInventario, {
            idTienda: idTienda, observacion: $('#txtObsNuevo').val()
        }, function (r) {
            if (r.resultado) {
                toastr.success(r.mensaje);
                $('#modalNuevo').modal('hide');
                cargar();
                setTimeout(function () { abrirAsignar(r.idInventario, 'Nuevo'); }, 600);
            } else toastr.error(r.mensaje);
        });
    });

    // ── Asignar operador ──────────────────────────────────────────────────────
    $('#btnConfirmarAsignar').on('click', function () {
        var idOperador = parseInt($('#cboOperador').val()) || 0;
        if (idOperador === 0) { toastr.warning('Seleccioná un operador.'); return; }
        $.post($.MisUrls.url._Inv_AsignarOperador, {
            idInventario: inventarioSeleccionado, idOperador: idOperador
        }, function (r) {
            if (r.resultado) { toastr.success(r.mensaje); cargar(); }
            else toastr.error(r.mensaje);
        });
    });
});

// ── Cargar lista ──────────────────────────────────────────────────────────────
function cargar() {
    $.get($.MisUrls.url._Inv_ObtenerInventarios, { estado: $('#ddlEstado').val() }, function (r) {
        var t = $('#tbodyInv').empty();
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            t.append('<tr><td colspan="8" class="text-center text-muted">Sin registros.</td></tr>');
            return;
        }
        lista.forEach(function (i) {
            var acc = '';
            if (i.CantItems > 0)
                acc += '<button class="btn btn-xs btn-info btn-sm mr-1" onclick="verDetalle(' + i.IdInventario + ',\'' + esc(i.Numero) + '\')" title="Reporte de diferencias"><i class="fas fa-chart-bar"></i></button>';
            if (i.Estado === 'Abierto' || i.Estado === 'Rechazado')
                acc += '<button class="btn btn-xs btn-secondary btn-sm mr-1" onclick="abrirAsignar(' + i.IdInventario + ',\'' + esc(i.Numero) + '\',' + (i.IdTienda || 0) + ')" title="Asignar operador"><i class="fas fa-user-plus"></i></button>';
            if (i.Estado === 'Pendiente de Aprobación') {
                acc += '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobar(' + i.IdInventario + ')" title="Aprobar"><i class="fas fa-check"></i></button>';
                acc += '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazar(' + i.IdInventario + ')" title="Rechazar"><i class="fas fa-times"></i></button>';
            }
            var motivo = i.MotivoRechazo
                ? ' <i class="fas fa-info-circle text-danger" title="' + esc(i.MotivoRechazo) + '"></i>'
                : '';
            t.append('<tr>' +
                '<td><strong>' + (i.Numero || '') + '</strong></td>' +
                '<td>' + (i.NombreTienda || '') + '</td>' +
                '<td>' + (i.Supervisor || '—') + '</td>' +
                '<td>' + (i.Operadores || '<span class="text-muted small">Sin asignar</span>') + '</td>' +
                '<td>' + fmtFecha(i.FechaRegistro) + '</td>' +
                '<td>' + fmtFecha(i.FechaFinalizacion) + '</td>' +
                '<td class="text-center">' + badge(i.Estado) + motivo + '</td>' +
                '<td class="text-center">' + (acc || '—') + '</td>' +
                '</tr>');
        });
    });
}

// ── Modal asignar operador ────────────────────────────────────────────────────
function abrirAsignar(idInventario, numero, idTienda) {
    inventarioSeleccionado = idInventario;
    $('#lblNumAsignar').text(numero);
    var url = '/Usuario/ObtenerUsuariosActivos' + (idTienda ? '?idTienda=' + idTienda : '');
    $.get(url, function (r) {
        var $cbo = $('#cboOperador').empty().append('<option value="">-- Seleccione repositor --</option>');
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            $cbo.append('<option value="" disabled>Sin repositores en esta sucursal</option>');
            toastr.warning('No hay repositores activos en esta sucursal.');
        } else {
            lista.forEach(function (u) {
                $cbo.append($('<option>').val(u.IdUsuario).text(u.NombreCompleto + ' (' + (u.DescripcionRol || '') + ')'));
            });
        }
    }).fail(function () {
        $('#cboOperador').empty().append('<option value="">-- Sin usuarios disponibles --</option>');
        toastr.warning('No se pudo cargar la lista de repositores.');
    });
    $('#modalAsignar').modal('show');
}

// ── Reporte de diferencias ────────────────────────────────────────────────────
function verDetalle(id, numero) {
    $('#lblNumDetalle').text(numero);
    $.get($.MisUrls.url._Inv_ObtenerDetalleInventario, { idInventario: id }, function (r) {
        var t = $('#tbodyDet').empty();
        var data = (r && r.data) ? r.data : [];
        var sobrante = 0, faltante = 0, sinDif = 0;
        data.forEach(function (d) {
            var dif = d.Diferencia;
            var col = dif === 0 ? '' : (dif > 0 ? 'text-success' : 'text-danger');
            if (dif > 0) sobrante++;
            else if (dif < 0) faltante++;
            else sinDif++;
            t.append('<tr>' +
                '<td>' + (d.Categoria || '—') + '</td>' +
                '<td>' + (d.CodigoProducto || '') + ' — ' + (d.NombreProducto || '') + '</td>' +
                '<td class="text-center">' + d.StockSistema + '</td>' +
                '<td class="text-center">' + d.StockContado + '</td>' +
                '<td class="text-center ' + col + '"><strong>' + (dif > 0 ? '+' : '') + dif + '</strong></td>' +
                '</tr>');
        });
        $('#resumenDiferencias').html(
            '<strong>Total ítems:</strong> ' + data.length +
            ' &nbsp;|&nbsp; <span class="text-success font-weight-bold">Sobrante: ' + sobrante + '</span>' +
            ' &nbsp;|&nbsp; <span class="text-danger font-weight-bold">Faltante: ' + faltante + '</span>' +
            ' &nbsp;|&nbsp; Sin diferencia: ' + sinDif
        );
        $('#modalDetalle').modal('show');
    });
}

// ── Aprobar ───────────────────────────────────────────────────────────────────
function aprobar(id) {
    Swal.fire({
        title: '¿Aprobar inventario?',
        text: 'El stock será ajustado al conteo físico registrado por el operador.',
        icon: 'question', showCancelButton: true,
        confirmButtonText: 'Sí, aprobar', confirmButtonColor: '#28a745'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarInventario, { idInventario: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

// ── Rechazar ──────────────────────────────────────────────────────────────────
function rechazar(id) {
    Swal.fire({
        title: 'Rechazar inventario',
        html: '<label class="d-block text-left mb-1">Motivo del rechazo:</label>' +
              '<textarea id="swalMotivo" class="swal2-textarea" placeholder="Describa el error encontrado..."></textarea>',
        showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        preConfirm: function () {
            var v = document.getElementById('swalMotivo').value.trim();
            if (!v) { Swal.showValidationMessage('Indique un motivo.'); return false; }
            return v;
        }
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RechazarInventario, { idInventario: id, motivoRechazo: r.value }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function badge(e) {
    var map = {
        'Abierto': 'secondary', 'En Progreso': 'warning',
        'Pendiente de Aprobación': 'info',
        'Rechazado': 'dark', 'En Corrección': 'danger', 'Aprobado': 'success'
    };
    return '<span class="badge badge-' + (map[e] || 'dark') + '">' + e + '</span>';
}

function esc(s) { return (s || '').replace(/'/g, "\\'").replace(/\n/g, ' '); }

function fmtFecha(dt) {
    if (!dt) return '—';
    var ms = /\/Date\((\d+)/.exec(dt);
    var f = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt.replace(' ', 'T'));
    if (isNaN(f.getTime())) return dt;
    var p = function (n) { return ('0' + n).slice(-2); };
    return p(f.getDate()) + '/' + p(f.getMonth() + 1) + '/' + f.getFullYear() +
           ' ' + p(f.getHours()) + ':' + p(f.getMinutes());
}
