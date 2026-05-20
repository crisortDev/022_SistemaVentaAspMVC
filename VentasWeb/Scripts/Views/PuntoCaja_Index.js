// PuntoCaja_Index.js  — Gestión de Puntos de Caja (maestro/detalle)
'use strict';

$(function () {
    recargarPuntos();
});

// ─── MAESTRO: listar puntos de caja ───────────────────────────────────────────
function recargarPuntos() {
    var idTienda = parseInt($('#ddlFiltroTienda').val()) || 0;
    $.get($.MisUrls.url._PuntoCaja_Obtener, { idTienda: idTienda }, function (r) {
        var tbody = $('#tbodyPuntos').empty();
        if (!r.data || r.data.length === 0) {
            tbody.append('<tr><td colspan="8" class="text-center text-muted">Sin cajas registradas.</td></tr>');
            return;
        }
        r.data.forEach(function (p) {
            var estadoBadge = p.Activo
                ? '<span class="badge badge-success">Activo</span>'
                : '<span class="badge badge-secondary">Inactivo</span>';
            var sesionBadge = p.SesionesAbiertas > 0
                ? '<span class="badge badge-warning">Abierta</span>'
                : '';
            var ultimaAp = p.UltimaApertura ? formatFechaHora(p.UltimaApertura) : '—';

            tbody.append(
                '<tr>' +
                '<td class="text-center">' +
                  '<button class="btn btn-xs btn-outline-info btn-sm" title="Ver sesiones" onclick="verSesiones(' + p.IdPuntoCaja + ',\'' + escapar(p.Nombre) + '\')">' +
                  '<i class="fas fa-list-alt"></i></button>' +
                '</td>' +
                '<td>' + p.NombreTienda + '</td>' +
                '<td><strong>' + p.Nombre + '</strong></td>' +
                '<td>' + (p.Descripcion || '—') + '</td>' +
                '<td class="text-center">' + p.TotalSesiones + ' ' + sesionBadge + '</td>' +
                '<td class="text-center">' + estadoBadge + '</td>' +
                '<td class="text-center">' + ultimaAp + '</td>' +
                '<td class="text-center">' +
                  '<button class="btn btn-xs btn-warning btn-sm mr-1" onclick="abrirModalEditar(' + p.IdPuntoCaja + ',\'' + escapar(p.Nombre) + '\',\'' + escapar(p.Descripcion || '') + '\',' + p.Activo + ',' + p.IdTienda + ')" title="Editar">' +
                  '<i class="fas fa-edit"></i></button>' +
                '</td>' +
                '</tr>'
            );
        });
    });
}

// ─── DETALLE: sesiones de un punto ────────────────────────────────────────────
function verSesiones(idPuntoCaja, nombre) {
    $('#lblPuntoSeleccionado').text(nombre);
    $('#panelDetalle').show();
    $('html, body').animate({ scrollTop: $('#panelDetalle').offset().top - 80 }, 400);

    $.get($.MisUrls.url._PuntoCaja_Sesiones, { idPuntoCaja: idPuntoCaja }, function (r) {
        var tbody = $('#tbodySesiones').empty();
        if (!r.data || r.data.length === 0) {
            tbody.append('<tr><td colspan="11" class="text-center text-muted">Sin sesiones registradas para esta caja.</td></tr>');
            return;
        }
        r.data.forEach(function (s, i) {
            var estadoBadge = s.Estado === 'Abierta'
                ? '<span class="badge badge-success">Abierta</span>'
                : '<span class="badge badge-secondary">Cerrada</span>';
            var diff = s.Diferencia != null
                ? (s.Diferencia >= 0
                    ? '<span class="text-success">+Gs. ' + formatGs(s.Diferencia) + '</span>'
                    : '<span class="text-danger">-Gs. ' + formatGs(Math.abs(s.Diferencia)) + '</span>')
                : '—';

            tbody.append(
                '<tr>' +
                '<td>' + (i + 1) + '</td>' +
                '<td>' + s.Aperturista + '</td>' +
                '<td>' + formatFechaHora(s.FechaApertura) + '</td>' +
                '<td class="text-right">Gs. ' + formatGs(s.MontoApertura) + '</td>' +
                '<td>' + (s.FechaCierre ? formatFechaHora(s.FechaCierre) : '—') + '</td>' +
                '<td class="text-right">' + (s.MontoSistema != null ? 'Gs. ' + formatGs(s.MontoSistema) : '—') + '</td>' +
                '<td class="text-right">' + (s.MontoContado != null ? 'Gs. ' + formatGs(s.MontoContado) : '—') + '</td>' +
                '<td class="text-right">' + diff + '</td>' +
                '<td class="text-center">' + s.CantidadVentas + '</td>' +
                '<td class="text-center">' + estadoBadge + '</td>' +
                '<td class="text-center">' +
                  '<a href="' + $.MisUrls.url._CajaVenta_Reporte + '?idCaja=' + s.IdCaja + '" class="btn btn-xs btn-outline-primary btn-sm" title="Ver informe">' +
                  '<i class="fas fa-file-alt"></i></a>' +
                '</td>' +
                '</tr>'
            );
        });
    });
}

function cerrarDetalle() {
    $('#panelDetalle').hide();
    $('#tbodySesiones').empty();
}

// ─── MODAL NUEVO ──────────────────────────────────────────────────────────────
function abrirModalNuevo() {
    $('#hdnIdPuntoCaja').val(0);
    $('#txtNombrePunto').val('');
    $('#txtDescripcionPunto').val('');
    $('#chkActivo').prop('checked', true);
    $('#rowActivo').hide();
    $('#modalTitulo').text('Nueva Caja');
    if ($('#ddlTiendaModal').is('select')) $('#ddlTiendaModal').val(0);
    $('#modalPunto').modal('show');
}

// ─── MODAL EDITAR ─────────────────────────────────────────────────────────────
function abrirModalEditar(id, nombre, descripcion, activo, idTienda) {
    $('#hdnIdPuntoCaja').val(id);
    $('#txtNombrePunto').val(nombre);
    $('#txtDescripcionPunto').val(descripcion);
    $('#chkActivo').prop('checked', activo);
    $('#rowActivo').show();
    $('#modalTitulo').text('Editar Caja');
    if ($('#ddlTiendaModal').is('select')) $('#ddlTiendaModal').val(idTienda);
    $('#modalPunto').modal('show');
}

// ─── GUARDAR ──────────────────────────────────────────────────────────────────
function guardarPunto() {
    var id      = parseInt($('#hdnIdPuntoCaja').val()) || 0;
    var nombre  = $('#txtNombrePunto').val().trim();
    var desc    = $('#txtDescripcionPunto').val().trim();
    var activo  = $('#chkActivo').is(':checked');
    var idTienda = parseInt($('#ddlTiendaModal').val()) || 0;

    if (!nombre) { toastr.warning('Ingresá el nombre de la caja.'); return; }
    if ($('#ddlTiendaModal').is('select') && idTienda === 0) {
        toastr.warning('Seleccioná una tienda.'); return;
    }

    $.ajax({
        url:    $.MisUrls.url._PuntoCaja_Guardar,
        method: 'POST',
        data:   { idPuntoCaja: id, idTienda: idTienda, nombre: nombre, descripcion: desc, activo: activo },
        success: function (r) {
            if (r.resultado) {
                toastr.success(r.mensaje);
                $('#modalPunto').modal('hide');
                recargarPuntos();
            } else {
                toastr.error(r.mensaje);
            }
        },
        error: function () { toastr.error('Error de conexión.'); }
    });
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
function formatFechaHora(dt) {
    if (!dt) return '—';
    var m = dt.match(/(\d+)/g);
    if (!m) return dt;
    return ('0' + m[2]).slice(-2) + '/' + ('0' + m[1]).slice(-2) + '/' + m[0] +
           ' ' + ('0' + m[3]).slice(-2) + ':' + ('0' + m[4]).slice(-2);
}
