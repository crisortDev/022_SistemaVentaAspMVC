// Inventario_AprobarTraslados.js
// Flujo 4 pasos — Supervisor ORIGEN (Paso 2):
//   Aprueba o rechaza solicitudes de traslado entrantes a su sucursal.
//   También permite consultar cualquier estado del historial.

'use strict';

var _idTrasladoRechazo = null;

// ══════════════════════════════════════════════════════════════
// INIT
// ══════════════════════════════════════════════════════════════
$(document).ready(function () {
    cargarTraslados();
});

// ══════════════════════════════════════════════════════════════
// LISTA
// ══════════════════════════════════════════════════════════════

function cargarTraslados() {
    var estado = $('#ddlEstado').val();
    var $tbody = $('#tbodyTraslados');
    $tbody.html('<tr><td colspan="9" class="text-center py-2"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');
    $('#divVacio').hide();

    $.get($.MisUrls.url._Inv_ObtenerTraslados, { estado: estado, rol: 'origen' }, function (r) {
        var lista = (r && r.data) ? r.data : [];

        if (lista.length === 0) {
            $tbody.html('');
            $('#divVacio').show();
            return;
        }

        var html = '';
        $.each(lista, function (_, t) {
            html += '<tr>' +
                    '<td><strong>' + t.Numero + '</strong></td>' +
                    '<td>' + t.FechaTraslado + '</td>' +
                    '<td>' + t.TiendaOrigen + '</td>' +
                    '<td>' + t.TiendaDestino + '</td>' +
                    '<td>' + t.Usuario + '</td>' +
                    '<td class="text-center">' + t.CantidadItems + ' ítem(s) / ' + t.TotalUnidades + ' u.</td>' +
                    '<td>' + (t.Observaciones ? '<small>' + t.Observaciones + '</small>' : '-') + '</td>' +
                    '<td class="text-center">' + badgeEstado(t.EstadoAprobacion) + '</td>' +
                    '<td class="text-center">' + construirAcciones(t) + '</td>' +
                    '</tr>';

            if (t.EstadoAprobacion === 'Rechazado' && t.MotivoRechazo) {
                html += '<tr class="table-danger">' +
                        '<td colspan="9" class="small pl-4">' +
                        '<i class="fas fa-comment-alt mr-1"></i><strong>Motivo rechazo:</strong> ' + t.MotivoRechazo +
                        '</td></tr>';
            }
        });
        $tbody.html(html);
    }).fail(function () {
        $tbody.html('<tr><td colspan="9" class="text-center text-danger">Error al cargar traslados.</td></tr>');
    });
}

function construirAcciones(t) {
    var html = '<button class="btn btn-xs btn-outline-dark mr-1" ' +
               'onclick="verDetalle(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')" title="Ver ítems">' +
               '<i class="fas fa-eye"></i></button>';

    if (t.EstadoAprobacion === 'Solicitado') {
        html += '<button class="btn btn-xs btn-success mr-1" ' +
                'onclick="aprobar(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                '<i class="fas fa-check mr-1"></i>Aprobar</button>';
        html += '<button class="btn btn-xs btn-danger" ' +
                'onclick="abrirModalRechazo(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                '<i class="fas fa-times mr-1"></i>Rechazar</button>';
    }
    return html;
}

// ══════════════════════════════════════════════════════════════
// APROBAR
// ══════════════════════════════════════════════════════════════

function aprobar(idTraslado, numero) {
    Swal.fire({
        title: 'Aprobar T-' + numero,
        text: 'El operador de tu sucursal podrá despachar los productos solicitados.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, aprobar',
        confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (result) {
        if (!result.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarSolicitudTraslado, { idTraslado: idTraslado }, function (data) {
            if (data && data.resultado) {
                Swal.fire('¡Aprobado!', 'Traslado N° ' + numero + ' aprobado correctamente.', 'success');
                cargarTraslados();
            } else {
                Swal.fire('Error', (data && data.mensaje) || 'No se pudo aprobar.', 'error');
            }
        }).fail(function () {
            Swal.fire('Error', 'Error de comunicación con el servidor.', 'error');
        });
    });
}

// ══════════════════════════════════════════════════════════════
// RECHAZAR
// ══════════════════════════════════════════════════════════════

function abrirModalRechazo(idTraslado, numero) {
    _idTrasladoRechazo = idTraslado;
    $('#lblNumeroRechazo').text(numero);
    $('#txtMotivoRechazo').val('');
    $('#modalRechazo').modal('show');
}

function confirmarRechazo() {
    var motivo = $('#txtMotivoRechazo').val().trim();
    if (!motivo) {
        Swal.fire('Atención', 'El motivo del rechazo es obligatorio.', 'warning');
        return;
    }
    $.post($.MisUrls.url._Inv_RechazarSolicitudTraslado, {
        idTraslado: _idTrasladoRechazo,
        motivoRechazo: motivo
    }, function (data) {
        $('#modalRechazo').modal('hide');
        if (data && data.resultado) {
            Swal.fire('Rechazado', 'El traslado fue rechazado.', 'info');
            cargarTraslados();
        } else {
            Swal.fire('Error', (data && data.mensaje) || 'No se pudo rechazar.', 'error');
        }
    }).fail(function () {
        $('#modalRechazo').modal('hide');
        Swal.fire('Error', 'Error de comunicación con el servidor.', 'error');
    });
}

// ══════════════════════════════════════════════════════════════
// DETALLE
// ══════════════════════════════════════════════════════════════

function verDetalle(idTraslado, numero) {
    $('#lblNumeroDetalle').text(numero);
    $('#tbodyDetalle').html('<tr><td colspan="4" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');
    $('#modalDetalle').modal('show');

    $.get($.MisUrls.url._Inv_ObtenerDetalleTraslado, { idTraslado: idTraslado }, function (r) {
        var items = (r && r.data) ? r.data : [];
        if (items.length === 0) {
            $('#tbodyDetalle').html('<tr><td colspan="4" class="text-center text-muted">Sin ítems.</td></tr>');
            return;
        }
        var html = '';
        $.each(items, function (_, item) {
            // Advertir si el stock actual es menor a la cantidad solicitada
            var stockClass = (item.StockOrigen < item.Cantidad) ? 'class="text-danger font-weight-bold"' : '';
            html += '<tr>' +
                    '<td>' + item.CodigoProducto + '</td>' +
                    '<td>' + item.NombreProducto + '</td>' +
                    '<td class="text-center">' + item.Cantidad + '</td>' +
                    '<td class="text-center" ' + stockClass + '>' + item.StockOrigen + '</td>' +
                    '</tr>';
        });
        $('#tbodyDetalle').html(html);
    }).fail(function () {
        $('#tbodyDetalle').html('<tr><td colspan="4" class="text-center text-danger">Error al cargar detalle.</td></tr>');
    });
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════

function badgeEstado(estado) {
    var map = {
        'Solicitado': 'badge-warning',
        'Aprobado':   'badge-primary',
        'Despachado': 'badge-info',
        'Completado': 'badge-success',
        'Rechazado':  'badge-danger'
    };
    return '<span class="badge ' + (map[estado] || 'badge-secondary') + '">' + (estado || '') + '</span>';
}

function esc(s) {
    return String(s).replace(/'/g, "\\'");
}
