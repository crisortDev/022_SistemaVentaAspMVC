// ════════════════════════════════════════════════════════════════════════
//  NotaCredito_Index.js
//  Gestión de Notas de Crédito — formato SET Paraguay
// ════════════════════════════════════════════════════════════════════════
'use strict';

var dtNC;

$(document).ready(function () {
    initDataTable();
    initDatepickers();
    cargarTabla();
    activarMenu('Gestión de NC');
});

// ─────────────────────────────────────────────────────────────────────
//  DATATABLE
// ─────────────────────────────────────────────────────────────────────
function initDataTable() {
    dtNC = $('#tbNC').DataTable({
        language:  { url: $.MisUrls.url.Url_datatable_spanish },
        order:     [[6, 'asc'], [7, 'desc']],   // Estado asc, Días desc
        pageLength: 25,
        responsive: true,
        columns: [
            // 0 — Índice
            { data: null, render: function (d, t, r, m) { return m.row + 1; }, orderable: false, className: 'text-center' },
            // 1 — Nro. NC
            {
                data: 'NumeroNC',
                render: function (val) {
                    return val ? '<code>' + val + '</code>'
                               : '<span class="text-muted fst-italic">Sin nro.</span>';
                }
            },
            // 2 — Compra / Factura
            {
                data: null,
                render: function (d) {
                    var txt = '';
                    if (d.NumeroFactura) txt += '<strong>' + d.NumeroFactura + '</strong>';
                    if (d.FechaFactura)  txt += '<br><small class="text-muted">' + formatearFecha(d.FechaFactura) + '</small>';
                    return txt || '<span class="text-muted">—</span>';
                }
            },
            // 3 — Proveedor
            {
                data: null,
                render: function (d) {
                    var txt = d.Proveedor || '';
                    if (d.RucProveedor) txt += '<br><small class="text-muted">RUC: ' + d.RucProveedor + '</small>';
                    return txt;
                }
            },
            // 4 — Tienda
            { data: 'Tienda' },
            // 5 — Monto NC
            {
                data: 'MontoNC',
                className: 'text-right',
                render: function (val) {
                    return '<strong>' + formatearGS(val) + '</strong>';
                }
            },
            // 6 — Estado
            {
                data: null,
                render: function (d) {
                    return badgeEstado(d.Estado, d.EsMorosa);
                }
            },
            // 7 — Días
            {
                data: 'DiasTranscurridos',
                className: 'text-center',
                render: function (val, t, row) {
                    if (row.Estado !== 'Pendiente') return '<span class="text-muted">—</span>';
                    var cls = val > 30 ? 'danger' : (val > 20 ? 'warning' : 'secondary');
                    return '<span class="badge badge-' + cls + '">' + val + 'd</span>';
                }
            },
            // 8 — Motivo
            { data: 'MotivoNC' },
            // 9 — Acciones
            {
                data: null,
                orderable: false,
                className: 'text-center',
                render: function (d) {
                    var btns = '';
                    // Ver detalle — siempre visible
                    btns += '<button class="btn btn-info btn-sm mr-1" title="Ver detalle" '
                          + 'onclick=\'verNC(' + JSON.stringify(d) + ')\''
                          + '><i class="fas fa-eye"></i></button>';

                    // Acciones solo para Pendiente
                    if (d.Estado === 'Pendiente') {
                        btns += '<button class="btn btn-success btn-sm mr-1" title="Registrar NC del proveedor" '
                              + 'onclick=\'abrirConfirmar(' + JSON.stringify(d) + ')\''
                              + '><i class="fas fa-check"></i></button>';
                        btns += '<button class="btn btn-danger btn-sm" title="Rechazar NC" '
                              + 'onclick=\'abrirRechazar(' + JSON.stringify(d) + ')\''
                              + '><i class="fas fa-times"></i></button>';
                    }
                    return btns;
                }
            }
        ]
    });
}

// ─────────────────────────────────────────────────────────────────────
//  CARGAR TABLA
// ─────────────────────────────────────────────────────────────────────
function cargarTabla() {
    var idtienda = $('#cboFiltroTienda').val() || 0;
    var estado   = $('#cboFiltroEstado').val() || '';

    $.ajax({
        url:      $.MisUrls.url._NC_Obtener,
        type:     'GET',
        data:     { idtienda: idtienda, estado: estado },
        success: function (r) {
            dtNC.clear().rows.add(r.data).draw();
        },
        error: function () {
            Swal.fire('Error', 'No se pudieron cargar las Notas de Crédito.', 'error');
        }
    });
}

// ─────────────────────────────────────────────────────────────────────
//  BADGE ESTADO
// ─────────────────────────────────────────────────────────────────────
function badgeEstado(estado, esMorosa) {
    if (estado === 'Pendiente' && esMorosa)
        return '<span class="badge badge-danger">Morosa</span>';
    if (estado === 'Pendiente')
        return '<span class="badge badge-warning text-dark">Pendiente</span>';
    if (estado === 'Recibida')
        return '<span class="badge badge-success">Recibida</span>';
    if (estado === 'Rechazada')
        return '<span class="badge badge-secondary">Rechazada</span>';
    return '<span class="badge badge-light">' + (estado || '—') + '</span>';
}

// ─────────────────────────────────────────────────────────────────────
//  MODAL VER DETALLE
// ─────────────────────────────────────────────────────────────────────
function verNC(d) {
    $('#verNumeroNC').html(d.NumeroNC ? '<code>' + d.NumeroNC + '</code>' : '<em class="text-muted">Sin registrar</em>');
    $('#verTimbrado').text(d.NumeroTimbrado || '—');
    $('#verFechaVenc').text(d.FechaVencTimbrado ? formatearFecha(d.FechaVencTimbrado) : '—');
    $('#verFechaEmision').text(d.FechaEmision ? formatearFecha(d.FechaEmision) : '—');
    $('#verFactura').text(d.NumeroFactura || '—');
    $('#verProveedor').text((d.Proveedor || '—') + (d.RucProveedor ? ' (RUC: ' + d.RucProveedor + ')' : ''));
    $('#verTienda').text(d.Tienda || '—');
    $('#verMontoNC').text(formatearGS(d.MontoNC));
    $('#verEstado').html(badgeEstado(d.Estado, d.EsMorosa));
    $('#verMotivo').text(d.MotivoNC || '—');
    $('#verFechaRegistro').text(d.FechaRegistro ? formatearFecha(d.FechaRegistro) : '—');
    $('#verUsuario').text(d.UsuarioRegistro || '—');
    $('#verObservacion').text(d.Observacion || '—');

    $('#modalVerNC').modal('show');
}

// ─────────────────────────────────────────────────────────────────────
//  MODAL CONFIRMAR RECEPCIÓN
// ─────────────────────────────────────────────────────────────────────
function abrirConfirmar(d) {
    $('#hdnIdNC').val(d.IdNC);
    $('#infoNumFactura').text(d.NumeroFactura || '—');
    $('#infoProveedor').text(d.Proveedor || '—');
    $('#infoMontoNC').text(formatearGS(d.MontoNC) + ' Gs.');

    $('#txtNumeroNC').val('');
    $('#txtNumeroTimbrado').val('');
    $('#txtFechaVencTimbrado').val('');
    $('#txtFechaEmision').val('');
    $('#txtObservacionConfirmar').val('');

    $('#modalConfirmar').modal('show');
}

function confirmarRecepcion() {
    var idnc             = parseInt($('#hdnIdNC').val());
    var numeronc         = $.trim($('#txtNumeroNC').val());
    var numerotimbrado   = $.trim($('#txtNumeroTimbrado').val());
    var fechavencTimbrado= $.trim($('#txtFechaVencTimbrado').val());
    var fechaemision     = $.trim($('#txtFechaEmision').val());
    var observacion      = $.trim($('#txtObservacionConfirmar').val());

    if (!numeronc) {
        Swal.fire('Validación', 'Ingrese el Número de Nota de Crédito.', 'warning'); return;
    }
    if (!validarFormatoNC(numeronc)) {
        Swal.fire('Validación', 'El número debe tener el formato SET PY: xxx-xxx-xxxxxxx (ej: 001-001-0000001).', 'warning'); return;
    }
    if (!numerotimbrado) {
        Swal.fire('Validación', 'Ingrese el Número de Timbrado.', 'warning'); return;
    }
    if (!fechavencTimbrado) {
        Swal.fire('Validación', 'Ingrese la Fecha de Vencimiento del Timbrado.', 'warning'); return;
    }
    if (!fechaemision) {
        Swal.fire('Validación', 'Ingrese la Fecha de Emisión de la NC.', 'warning'); return;
    }

    $('#btnConfirmarNC').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Guardando...');

    $.ajax({
        url:  $.MisUrls.url._NC_ConfirmarRecepcion,
        type: 'POST',
        data: {
            idnc:             idnc,
            numeronc:         numeronc,
            numerotimbrado:   numerotimbrado,
            fechavencTimbrado: fechavencTimbrado,
            fechaemision:     fechaemision,
            observacion:      observacion
        },
        success: function (r) {
            $('#btnConfirmarNC').prop('disabled', false).html('<i class="fas fa-check"></i> Confirmar Recepción');
            if (r.resultado) {
                $('#modalConfirmar').modal('hide');
                Swal.fire({
                    icon: 'success',
                    title: '¡Confirmado!',
                    text: r.mensaje,
                    timer: 3000,
                    showConfirmButton: false
                });
                cargarTabla();
            } else {
                Swal.fire('Error', r.mensaje, 'error');
            }
        },
        error: function () {
            $('#btnConfirmarNC').prop('disabled', false).html('<i class="fas fa-check"></i> Confirmar Recepción');
            Swal.fire('Error', 'No se pudo conectar con el servidor.', 'error');
        }
    });
}

// ─────────────────────────────────────────────────────────────────────
//  MODAL RECHAZAR
// ─────────────────────────────────────────────────────────────────────
function abrirRechazar(d) {
    $('#hdnIdNCRechazar').val(d.IdNC);
    $('#infoNumFacturaRechazar').text(d.NumeroFactura || '—');
    $('#txtObservacionRechazar').val('');
    $('#modalRechazar').modal('show');
}

function rechazarNC() {
    var idnc       = parseInt($('#hdnIdNCRechazar').val());
    var observacion = $.trim($('#txtObservacionRechazar').val());

    if (!observacion) {
        Swal.fire('Validación', 'Debe ingresar el motivo del rechazo.', 'warning'); return;
    }

    Swal.fire({
        title: '¿Rechazar Nota de Crédito?',
        text:  'Esta acción cambia el estado a Rechazada. ¿Continuar?',
        icon:  'warning',
        showCancelButton:  true,
        confirmButtonColor: '#dc3545',
        confirmButtonText: 'Sí, rechazar',
        cancelButtonText:  'Cancelar'
    }).then(function (result) {
        if (!result.isConfirmed) return;

        $.ajax({
            url:  $.MisUrls.url._NC_Rechazar,
            type: 'POST',
            data: { idnc: idnc, observacion: observacion },
            success: function (r) {
                if (r.resultado) {
                    $('#modalRechazar').modal('hide');
                    Swal.fire({
                        icon:  'success',
                        title: 'NC Rechazada',
                        text:   r.mensaje,
                        timer: 2500,
                        showConfirmButton: false
                    });
                    cargarTabla();
                } else {
                    Swal.fire('Error', r.mensaje, 'error');
                }
            },
            error: function () {
                Swal.fire('Error', 'No se pudo conectar con el servidor.', 'error');
            }
        });
    });
}

// ─────────────────────────────────────────────────────────────────────
//  HELPERS — FORMATO
// ─────────────────────────────────────────────────────────────────────

/** Formatea número como moneda Guaraní (sin decimales). */
function formatearGS(valor) {
    if (valor === null || valor === undefined) return '0';
    var n = parseFloat(valor);
    if (isNaN(n)) return '0';
    return Math.round(n).toLocaleString('es-PY');
}

/** Convierte fecha ISO/datetime a dd/mm/aaaa para mostrar en la tabla. */
function formatearFecha(str) {
    if (!str) return '';
    // Acepta "2026-05-11T00:00:00" o "2026-05-11"
    var m = String(str).match(/(\d{4})-(\d{2})-(\d{2})/);
    if (m) return m[3] + '/' + m[2] + '/' + m[1];
    return str;
}

/** Auto-formatea el campo NumeroNC con guiones (xxx-xxx-xxxxxxx). */
function formatearNumeroNC(input) {
    var v = input.value.replace(/\D/g, '');
    var out = '';
    if (v.length > 0) out = v.substring(0, Math.min(3, v.length));
    if (v.length > 3) out += '-' + v.substring(3, Math.min(6, v.length));
    if (v.length > 6) out += '-' + v.substring(6, Math.min(13, v.length));
    input.value = out;
}

/** Valida formato xxx-xxx-xxxxxxx de 7 caracteres en el tercer bloque. */
function validarFormatoNC(str) {
    return /^\d{3}-\d{3}-\d{7}$/.test(str);
}

// ─────────────────────────────────────────────────────────────────────
//  DATEPICKERS
// ─────────────────────────────────────────────────────────────────────
function initDatepickers() {
    var optsComunes = {
        dateFormat:   'dd/mm/yy',
        changeMonth:  true,
        changeYear:   true,
        yearRange:    '2020:2035',
        autoSize:     true
    };
    // Vencimiento timbrado: futuro (no poner minDate para permitir timbrados activos con venc en pasado)
    $('.datepicker-nc').datepicker(optsComunes);
}
