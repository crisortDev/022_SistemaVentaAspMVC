// Inventario_Inventarios.js — Gestión de inventarios (vista del Supervisor)
'use strict';

var inventarioSeleccionado = 0;

$(function () {
    activarMenu("Inventario");
    cargar();
    $('#btnBuscar').on('click', cargar);

    // ── Nuevo inventario ──────────────────────────────────────────────────────
    $('#btnNuevoInventario').on('click', function () {
        $('#txtObsNuevo').val('');
        $('#cboOperadorNuevo').empty().append('<option value="">-- Cargando... --</option>');

        if (AppSession.esSuperAdmin) {
            // SUPERADMIN: carga tiendas y espera selección para cargar operadores
            $.get($.MisUrls.url._ObtenerTiendas, function (r) {
                var $cbo = $('#cboTiendaNuevo').empty().append('<option value="">-- Seleccione sucursal --</option>');
                ((r && r.data) ? r.data : []).filter(function (t) { return t.Activo; }).forEach(function (t) {
                    $cbo.append($('<option>').val(t.IdTienda).text(t.Nombre));
                });
                $('#cboOperadorNuevo').empty().append('<option value="">-- Seleccione sucursal primero --</option>');
            });
        } else {
            // SUPERVISOR / ADMIN: sucursal fija, carga operadores automáticamente
            var idTienda = AppSession.tiendaOperativa;
            $('#cboTiendaNuevo').val(idTienda);
            $.get($.MisUrls.url._ObtenerTiendas, function (r) {
                var t = ((r && r.data) ? r.data : []).find(function (x) { return x.IdTienda == idTienda; });
                $('#lblTiendaNuevo').text(t ? t.Nombre : 'Sucursal ' + idTienda);
            });
            cargarOperadoresPorTienda(idTienda, '#cboOperadorNuevo');
        }

        $('#modalNuevo').modal('show');
    });

    // Cuando SuperAdmin cambia la sucursal → recarga operadores
    $('#cboTiendaNuevo').on('change', function () {
        var idTienda = parseInt($(this).val()) || 0;
        if (idTienda === 0) {
            $('#cboOperadorNuevo').empty().append('<option value="">-- Seleccione sucursal primero --</option>');
            return;
        }
        cargarOperadoresPorTienda(idTienda, '#cboOperadorNuevo');
    });

    // Confirmar: crea inventario y asigna operador en un solo paso
    $('#btnConfirmarNuevo').on('click', function () {
        var idTienda    = parseInt($('#cboTiendaNuevo').val()) || 0;
        var idOperador  = parseInt($('#cboOperadorNuevo').val()) || 0;
        var observacion = $('#txtObsNuevo').val().trim();

        if (idTienda === 0)         { toastr.warning('Seleccioná una sucursal.');           return; }
        if (idOperador === 0)       { toastr.warning('Seleccioná el repositor a cargo.');   return; }
        if (observacion.length < 3) { toastr.warning('La observación es obligatoria.');     return; }

        var $btn = $(this).prop('disabled', true).html('<i class="fas fa-spinner fa-spin mr-1"></i> Creando...');

        $.post($.MisUrls.url._Inv_CrearInventario, {
            idTienda: idTienda, observacion: observacion
        }, function (r) {
            if (!r.resultado) {
                toastr.error(r.mensaje);
                $btn.prop('disabled', false).html('<i class="fas fa-save mr-1"></i> Crear y asignar');
                return;
            }
            // Inventario creado → asignar operador inmediatamente
            $.post($.MisUrls.url._Inv_AsignarOperador, {
                idInventario: r.idInventario, idOperador: idOperador
            }, function (ra) {
                $('#modalNuevo').modal('hide');
                cargar();
                if (ra.resultado) toastr.success('Inventario creado y operador asignado correctamente.');
                else toastr.warning('Inventario creado, pero no se pudo asignar el operador: ' + ra.mensaje);
            }).fail(function () {
                $('#modalNuevo').modal('hide');
                cargar();
                toastr.warning('Inventario creado, pero falló la asignación del operador.');
            }).always(function () {
                $btn.prop('disabled', false).html('<i class="fas fa-save mr-1"></i> Crear y asignar');
            });
        }).fail(function () {
            toastr.error('Error al crear el inventario.');
            $btn.prop('disabled', false).html('<i class="fas fa-save mr-1"></i> Crear y asignar');
        });
    });

    // ── Asignar operador adicional (inventarios ya existentes) ────────────────
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
                acc += '<button class="btn btn-xs btn-info btn-sm mr-1" onclick="verDetalle(' + i.IdInventario + ',\'' + escJs(i.Numero) + '\')" title="Reporte de diferencias"><i class="fas fa-chart-bar"></i></button>';
            if (i.Estado === 'Abierto' || i.Estado === 'Rechazado')
                acc += '<button class="btn btn-xs btn-secondary btn-sm mr-1" onclick="abrirAsignar(' + i.IdInventario + ',\'' + escJs(i.Numero) + '\',' + (i.IdTienda || 0) + ')" title="Asignar/cambiar repositor"><i class="fas fa-user-plus"></i></button>';
            if (i.Estado === 'Pendiente de Aprobación') {
                acc += '<button class="btn btn-xs btn-success btn-sm mr-1" onclick="aprobar(' + i.IdInventario + ')" title="Aprobar"><i class="fas fa-check"></i></button>';
                acc += '<button class="btn btn-xs btn-danger btn-sm mr-1" onclick="rechazar(' + i.IdInventario + ')" title="Rechazar"><i class="fas fa-times"></i></button>';
            }
            if (i.Estado !== 'Aprobado' && i.Estado !== 'Anulado')
                acc += '<button class="btn btn-xs btn-dark btn-sm mr-1" onclick="anular(' + i.IdInventario + ',\'' + escJs(i.Numero) + '\')" title="Anular inventario"><i class="fas fa-ban"></i></button>';
            // Botón imprimir: solo mientras el inventario no esté cerrado (Aprobado o Anulado)
            if (i.Estado !== 'Aprobado' && i.Estado !== 'Anulado')
                acc += '<a href="' + $.MisUrls.url._Inv_ImprimirInventario + '?idInventario=' + i.IdInventario + '" target="_blank" class="btn btn-xs btn-outline-primary btn-sm mr-1" title="Imprimir hoja de conteo"><i class="fas fa-print"></i></a>';
            var motivo = i.MotivoRechazo
                ? ' <i class="fas fa-info-circle text-danger" title="' + escHtml(i.MotivoRechazo) + '"></i>'
                : '';
            t.append('<tr>' +
                '<td><strong>' + escHtml(i.Numero) + '</strong></td>' +
                '<td>' + escHtml(i.NombreTienda) + '</td>' +
                '<td>' + (i.Supervisor ? escHtml(i.Supervisor) : '—') + '</td>' +
                '<td>' + (i.Operadores ? escHtml(i.Operadores) : '<span class="text-muted small">Sin asignar</span>') + '</td>' +
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
    var url = $.MisUrls.url._Usuario_ObtenerActivos + (idTienda ? '?idTienda=' + idTienda : '');
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
        $('#cboOperador').empty().append('<option value="">-- Sin repositores disponibles --</option>');
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
                '<td>' + (d.Categoria ? escHtml(d.Categoria) : '—') + '</td>' +
                '<td>' + escHtml(d.CodigoProducto) + ' — ' + escHtml(d.NombreProducto) + '</td>' +
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
// ── Anular inventario ─────────────────────────────────────────────────────────
function anular(id, numero) {
    Swal.fire({
        title: 'Anular inventario ' + numero,
        text: 'Esta acción no se puede deshacer. El inventario quedará inactivo.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, anular',
        confirmButtonColor: '#343a40',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_AnularInventario, { idInventario: id }, function (res) {
            if (res.resultado) { toastr.success(res.mensaje); cargar(); }
            else toastr.error(res.mensaje);
        });
    });
}

function badge(e) {
    var map = {
        'Abierto':                'secondary',
        'En Progreso':            'warning',
        'Pendiente de Aprobación':'info',
        'Rechazado':              'dark',
        'En Corrección':          'danger',
        'Aprobado':               'success',
        'Anulado':                'light'
    };
    var cls = map[e] || 'dark';
    var extra = e === 'Anulado' ? ' style="border:1px solid #ccc;color:#555"' : '';
    return '<span class="badge badge-' + cls + '"' + extra + '>' + e + '</span>';
}

// ── Cargar operadores por tienda en un <select> ───────────────────────────────
function cargarOperadoresPorTienda(idTienda, selector) {
    var $cbo = $(selector).empty().append('<option value="">-- Cargando... --</option>');
    var url = $.MisUrls.url._Usuario_ObtenerActivos + (idTienda ? '?idTienda=' + idTienda : '');
    $.get(url, function (r) {
        $cbo.empty().append('<option value="">-- Seleccione operador --</option>');
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            $cbo.append('<option value="" disabled>Sin operadores activos en esta sucursal</option>');
            toastr.warning('No hay operadores activos en esta sucursal.');
        } else {
            lista.forEach(function (u) {
                $cbo.append($('<option>').val(u.IdUsuario)
                    .text(u.NombreCompleto + ' (' + (u.DescripcionRol || '') + ')'));
            });
        }
    }).fail(function () {
        $cbo.empty().append('<option value="">-- Error al cargar --</option>');
        toastr.error('No se pudo cargar la lista de operadores.');
    });
}

// HTML-encoding real para insertar valores como contenido/atributo HTML (evita XSS almacenado).
function escHtml(s) {
    return (s == null ? '' : String(s))
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// Para insertar un valor dentro de onclick="fn('...')": escapa la comilla simple
// que delimita el string de JS y además neutraliza caracteres especiales de HTML,
// ya que el atributo onclick sigue siendo HTML.
function escJs(s) {
    return (s == null ? '' : String(s))
        .replace(/\\/g, '\\\\')
        .replace(/'/g, "\\'")
        .replace(/\r?\n/g, ' ')
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function fmtFecha(dt) {
    if (!dt) return '—';
    var ms = /\/Date\((\d+)/.exec(dt);
    var f = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt.replace(' ', 'T'));
    if (isNaN(f.getTime())) return dt;
    var p = function (n) { return ('0' + n).slice(-2); };
    return p(f.getDate()) + '/' + p(f.getMonth() + 1) + '/' + f.getFullYear() +
           ' ' + p(f.getHours()) + ':' + p(f.getMinutes());
}
