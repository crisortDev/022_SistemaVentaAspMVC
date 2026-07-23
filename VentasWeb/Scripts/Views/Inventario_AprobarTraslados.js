// Inventario_AprobarTraslados.js
// Flujo 5 pasos — pantalla de supervisores:
//   Paso 2: Supervisor DESTINO aprueba/rechaza solicitud        (Solicitado)
//   Paso 3: Supervisor ORIGEN  autoriza/rechaza despacho        (AprobadoSolicitud)
//   Paso 5: Supervisor DESTINO aprueba recepción final → stock  (EnRecepcion)
'use strict';

$(function () {
    activarMenu("Aprobar Traslados");
    cargar();
    $('#btnBuscar').on('click', cargar);
});

// ── Helpers ────────────────────────────────────────────────────────────────────
function fmtFecha(dt) {
    if (!dt) return '—';
    var ms = /\/Date\((\d+)/.exec(dt);
    var f  = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt.replace(' ', 'T'));
    if (isNaN(f.getTime())) return dt;
    var p = function (n) { return ('0' + n).slice(-2); };
    return p(f.getDate()) + '/' + p(f.getMonth() + 1) + '/' + f.getFullYear()
         + ' ' + p(f.getHours()) + ':' + p(f.getMinutes());
}

function badge(estado) {
    var map = {
        'Solicitado'        : ['warning', 'Solicitado'],
        'AprobadoSolicitud' : ['info',    'Aprobado por destino'],
        'Despachado'        : ['primary', 'Despachado'],
        'EnRecepcion'       : ['warning', 'En recepción'],
        'Completado'        : ['success', 'Completado'],
        'RechazadoDestino'  : ['danger',  'Rechazado (destino)'],
        'RechazadoOrigen'   : ['danger',  'Rechazado (origen)']
    };
    var v = map[estado] || ['secondary', estado || ''];
    return '<span class="badge badge-' + v[0] + '">' + v[1] + '</span>';
}

function auditLinea(icono, color, label, usuario, fecha) {
    if (!usuario) return '';
    return '<small class="text-' + color + ' d-block">'
        + '<i class="fas fa-' + icono + ' mr-1"></i><b>' + label + ':</b> ' + usuario
        + (fecha ? ' — ' + fmtFecha(fecha) : '') + '</small>';
}

// ── Carga principal ────────────────────────────────────────────────────────────
function cargar() {
    var estado   = $('#ddlEstado').val();
    var miTienda = AppSession.tiendaOperativa;
    var esSA     = AppSession.esSuperAdmin;

    $.get($.MisUrls.url._Inv_ObtenerTrasladosPorEstado, { estado: estado }, function (r) {
        var t    = $('#tbodyTraslados').empty();
        var lista = (r && r.data) ? r.data : [];

        if (lista.length === 0) {
            t.append('<tr><td colspan="9" class="text-center text-muted py-3">Sin registros para este estado.</td></tr>');
            return;
        }

        lista.forEach(function (tr) {
            var acciones = '';
            var auditoria = '';

            switch (tr.EstadoAprobacion) {

                case 'Solicitado':
                    // Paso 2 — Supervisor DESTINO
                    if (esSA || tr.IdTiendaDestino == miTienda) {
                        acciones =
                            '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobarSolicitud(' + tr.IdTraslado + ')">' +
                                '<i class="fas fa-check"></i> Aprobar solicitud</button>' +
                            '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazarSolicitud(' + tr.IdTraslado + ')">' +
                                '<i class="fas fa-times"></i> Rechazar</button>';
                    } else {
                        acciones = '<span class="text-muted small"><i class="fas fa-clock mr-1"></i>Esperando aprobación de destino</span>';
                    }
                    auditoria = auditLinea('user', 'muted', 'Solicitó', tr.Usuario, tr.FechaTraslado);
                    break;

                case 'AprobadoSolicitud':
                    // Paso 3 — Supervisor ORIGEN
                    if (esSA || tr.IdTiendaOrigen == miTienda) {
                        acciones =
                            '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="autorizarDespacho(' + tr.IdTraslado + ')">' +
                                '<i class="fas fa-truck"></i> Autorizar despacho</button>' +
                            '<button class="btn btn-xs btn-danger btn-sm" onclick="rechazarDespacho(' + tr.IdTraslado + ')">' +
                                '<i class="fas fa-times"></i> Rechazar</button>';
                    } else {
                        acciones = '<span class="text-muted small"><i class="fas fa-clock mr-1"></i>Esperando autorización de origen</span>';
                    }
                    auditoria = auditLinea('check-circle', 'info', 'Aprobó solicitud', tr.UsuarioAprobSolicitud, tr.FechaAprobSolicitud);
                    break;

                case 'Despachado':
                    acciones = '<span class="text-primary small"><i class="fas fa-truck mr-1"></i>En tránsito hacia ' + (tr.TiendaDestino || 'destino') + '</span>';
                    auditoria = auditLinea('check-circle', 'info',   'Aprobó solicitud', tr.UsuarioAprobSolicitud, tr.FechaAprobSolicitud)
                              + auditLinea('truck',        'primary', 'Autorizó despacho', tr.UsuarioAprueba, tr.FechaAprobacion);
                    break;

                case 'EnRecepcion':
                    // Paso 5 — Supervisor DESTINO
                    if (esSA || tr.IdTiendaDestino == miTienda) {
                        acciones =
                            '<button class="btn btn-sm btn-success" onclick="aprobarRecepcionFinal(' + tr.IdTraslado + ')">' +
                                '<i class="fas fa-check-double mr-1"></i>Aprobar recepción final</button>';
                    } else {
                        acciones = '<span class="text-muted small"><i class="fas fa-clock mr-1"></i>Esperando aprobación final</span>';
                    }
                    auditoria = auditLinea('check-circle', 'info',    'Aprobó solicitud', tr.UsuarioAprobSolicitud, tr.FechaAprobSolicitud)
                              + auditLinea('truck',        'primary',  'Autorizó despacho', tr.UsuarioAprueba, tr.FechaAprobacion)
                              + auditLinea('box-open',     'warning',  'Registró llegada', tr.UsuarioRecibe, tr.FechaRecepcion);
                    break;

                case 'Completado':
                    acciones = '<span class="text-success small"><i class="fas fa-check-double mr-1"></i>Stock actualizado</span>';
                    auditoria = auditLinea('user',         'muted',   'Solicitó', tr.Usuario, tr.FechaTraslado)
                              + auditLinea('check-circle', 'info',    'Aprobó solicitud', tr.UsuarioAprobSolicitud, tr.FechaAprobSolicitud)
                              + auditLinea('truck',        'primary',  'Autorizó despacho', tr.UsuarioAprueba, tr.FechaAprobacion)
                              + auditLinea('box-open',     'warning',  'Registró llegada', tr.UsuarioRecibe, tr.FechaRecepcion)
                              + auditLinea('check-double', 'success',  'Aprobó recepción', tr.UsuarioAprobFinal, tr.FechaAprobFinal);
                    break;

                case 'RechazadoDestino':
                    acciones = '<span class="text-danger small"><i class="fas fa-times-circle mr-1"></i>Rechazado por supervisor destino</span>';
                    auditoria = auditLinea('times-circle', 'danger', 'Rechazó', tr.UsuarioAprobSolicitud, tr.FechaAprobSolicitud)
                              + (tr.MotivoRechazo ? '<small class="text-danger d-block"><i class="fas fa-comment mr-1"></i>' + tr.MotivoRechazo + '</small>' : '');
                    break;

                case 'RechazadoOrigen':
                    acciones = '<span class="text-danger small"><i class="fas fa-times-circle mr-1"></i>Rechazado por sucursal origen</span>';
                    auditoria = auditLinea('times-circle', 'danger', 'Rechazó', tr.UsuarioAprueba, tr.FechaAprobacion)
                              + (tr.MotivoRechazo ? '<small class="text-danger d-block"><i class="fas fa-comment mr-1"></i>' + tr.MotivoRechazo + '</small>' : '');
                    break;

                default:
                    acciones = badge(tr.EstadoAprobacion);
            }

            t.append('<tr>' +
                '<td><span class="badge badge-light border">' + (tr.Numero || '') + '</span></td>' +
                '<td>' + fmtFecha(tr.FechaTraslado) + '</td>' +
                '<td>' + (tr.CodigoProducto || '') + ' — ' + (tr.NombreProducto || '') + '</td>' +
                '<td class="text-center font-weight-bold">' + tr.Cantidad + '</td>' +
                '<td>' + (tr.TiendaOrigen  || '') + '</td>' +
                '<td>' + (tr.TiendaDestino || '') + '</td>' +
                '<td>' + (tr.Usuario       || '') + '</td>' +
                '<td class="text-center">' + badge(tr.EstadoAprobacion) +
                    (auditoria ? '<div class="mt-1 text-left">' + auditoria + '</div>' : '') + '</td>' +
                '<td>' + acciones + '</td>' +
                '</tr>');
        });
    });
}

// ── Paso 2: Aprobar solicitud (Supervisor DESTINO) ────────────────────────────
function aprobarSolicitud(id) {
    Swal.fire({
        title: '¿Aprobar solicitud?',
        text: 'La solicitud se enviará a la sucursal origen para autorizar el despacho.',
        icon: 'question', showCancelButton: true,
        confirmButtonText: 'Sí, aprobar', confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarSolicitudTraslado, { idTraslado: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

// ── Paso 2: Rechazar solicitud (Supervisor DESTINO) ───────────────────────────
function rechazarSolicitud(id) {
    Swal.fire({
        title: 'Rechazar solicitud', input: 'text',
        inputLabel: 'Motivo del rechazo', inputPlaceholder: 'Indicá el motivo...',
        showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        cancelButtonText: 'Cancelar',
        inputValidator: function (v) { if (!v) return 'Debe indicar un motivo.'; }
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RechazarSolicitudTraslado, { idTraslado: id, motivoRechazo: r.value }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

// ── Paso 3: Autorizar despacho (Supervisor ORIGEN) ───────────────────────────
function autorizarDespacho(id) {
    Swal.fire({
        title: '¿Autorizar despacho?',
        text: 'Confirmá que los productos serán preparados y enviados a la sucursal destino.',
        icon: 'question', showCancelButton: true,
        confirmButtonText: '<i class="fas fa-truck mr-1"></i> Autorizar',
        confirmButtonColor: '#007bff', cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AutorizarDespachoTraslado, { idTraslado: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else Swal.fire({ icon: 'error', title: 'Error', text: res.mensaje });
        });
    });
}

// ── Paso 3: Rechazar despacho (Supervisor ORIGEN) ────────────────────────────
function rechazarDespacho(id) {
    Swal.fire({
        title: 'Rechazar despacho', input: 'text',
        inputLabel: 'Motivo del rechazo', inputPlaceholder: 'Indicá el motivo...',
        showCancelButton: true,
        confirmButtonText: 'Rechazar', confirmButtonColor: '#dc3545',
        cancelButtonText: 'Cancelar',
        inputValidator: function (v) { if (!v) return 'Debe indicar un motivo.'; }
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RechazarDespachoTraslado, { idTraslado: id, motivoRechazo: r.value }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

// ── Paso 5: Aprobar recepción final → stock (Supervisor DESTINO) ──────────────
function aprobarRecepcionFinal(id) {
    Swal.fire({
        title: '¿Aprobar recepción final?',
        html: 'Al confirmar, el <strong>stock se actualizará</strong> en la sucursal destino.',
        icon: 'question', showCancelButton: true,
        confirmButtonText: '<i class="fas fa-check-double mr-1"></i> Aprobar y actualizar stock',
        confirmButtonColor: '#28a745', cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AprobarRecepcionFinalTraslado, { idTraslado: id }, function (res) {
            if (res.resultado) {
                Swal.fire({ icon: 'success', title: 'Completado', text: res.mensaje });
                cargar();
            } else {
                Swal.fire({ icon: 'error', title: 'Error', text: res.mensaje });
            }
        });
    });
}
