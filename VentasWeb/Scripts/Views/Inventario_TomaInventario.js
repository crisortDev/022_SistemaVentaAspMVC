// Inventario_TomaInventario.js — Toma de inventario (vista del Operador)
// El operador NO ve stock, diferencias ni costos.
'use strict';

var dtConteo = null;   // instancia DataTable
var LIMITE_CANTIDAD = 99999;   // tope máximo de cantidad contada por producto (debe coincidir con el SP)

$(function () {
    activarMenu("Inventario");
    cargarAsignados();

    $('#btnVolver').on('click', function () {
        if (dtConteo) { dtConteo.destroy(); dtConteo = null; }
        mostrarLista();
        cargarAsignados();
    });

    $('#btnFinalizar').on('click', finalizar);
});

// ── Cargar lista de inventarios asignados al operador ────────────────────────
function cargarAsignados() {
    $.get($.MisUrls.url._Inv_ObtenerInventariosOperador, function (r) {
        var t = $('#tbodyAsignados').empty();
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            t.append('<tr><td colspan="5" class="text-center text-muted">No tiene inventarios asignados pendientes.</td></tr>');
            return;
        }
        lista.forEach(function (i) {
            var badgeColor = i.Estado === 'En Progreso'   ? 'warning' :
                             i.Estado === 'En Corrección' ? 'warning' :
                             i.Estado === 'Rechazado'     ? 'dark'    : 'secondary';
            // "En Progreso"/"En Corrección" → continuar sin llamar al SP de inicio
            var yaCorriendo = i.Estado === 'En Progreso' || i.Estado === 'En Corrección';
            var btnLabel  = i.Estado === 'Abierto'       ? 'Iniciar conteo' :
                            i.Estado === 'Rechazado'     ? 'Iniciar corrección' :
                            i.Estado === 'En Corrección' ? 'Continuar corrección' : 'Continuar';
            var btnIcon   = i.Estado === 'Abierto'   ? 'fa-play' :
                            i.Estado === 'Rechazado' ? 'fa-redo' : 'fa-pencil-alt';
            var fnClick   = yaCorriendo
                ? 'continuar(' + i.IdInventario + ',' + i.IdTienda + ',\'' + esc(i.Numero) + '\',\'' + esc(i.MotivoRechazo) + '\')'
                : 'iniciar('   + i.IdInventario + ',' + i.IdTienda + ',\'' + esc(i.Numero) + '\',\'' + esc(i.MotivoRechazo) + '\')';
            var urlImprimir = $.MisUrls.url._Inv_ImprimirInventario + '?idInventario=' + i.IdInventario;
            t.append('<tr>' +
                '<td><strong>' + (i.Numero || '') + '</strong></td>' +
                '<td>' + (i.NombreTienda || '') + '</td>' +
                '<td>' + fmtFecha(i.FechaRegistro) + '</td>' +
                '<td class="text-center"><span class="badge badge-' + badgeColor + '">' + i.Estado + '</span></td>' +
                '<td class="text-center">' +
                    '<button class="btn btn-sm btn-primary mr-1" onclick="' + fnClick + '">' +
                        '<i class="fas ' + btnIcon + ' mr-1"></i>' + btnLabel +
                    '</button>' +
                    '<a href="' + urlImprimir + '" target="_blank" class="btn btn-sm btn-outline-secondary" title="Imprimir hoja de conteo">' +
                        '<i class="fas fa-print"></i>' +
                    '</a>' +
                '</td>' +
                '</tr>');
        });
    });
}

// ── Operador inicia el conteo → carga todos los productos en DataTable ───────
function iniciar(idInventario, idTienda, numero, motivoRechazo) {
    $.post($.MisUrls.url._Inv_IniciarConteo, { idInventario: idInventario }, function (r) {
        if (!r.resultado) { toastr.error(r.mensaje); return; }

        $('#hdnIdInventarioActivo').val(idInventario);
        $('#hdnIdTiendaConteo').val(idTienda);
        $('#lblNumeroConteo').text(numero);
        $('#txtObservacion').val('');

        if (motivoRechazo) {
            $('#textoMotivo').text('Motivo: ' + motivoRechazo);
            $('#alertaCorreccion').removeClass('d-none');
        } else {
            $('#alertaCorreccion').addClass('d-none');
        }

        // Cargar todos los productos de la tienda
        $.get($.MisUrls.url._Inv_ObtenerProductosParaConteo, { idTienda: idTienda }, function (resp) {
            var productos = (resp && resp.data) ? resp.data : [];
            construirTabla(productos);
            mostrarConteo();
            toastr.info(r.mensaje);
        }).fail(function () {
            toastr.error('No se pudieron cargar los productos.');
        });
    });
}

// ── Operador retoma un conteo ya iniciado (En Progreso / En Corrección) ──────
// No llama al SP — solo carga los productos y muestra el panel
function continuar(idInventario, idTienda, numero, motivoRechazo) {
    $('#hdnIdInventarioActivo').val(idInventario);
    $('#hdnIdTiendaConteo').val(idTienda);
    $('#lblNumeroConteo').text(numero);
    $('#txtObservacion').val('');

    if (motivoRechazo) {
        $('#textoMotivo').text('Motivo: ' + motivoRechazo);
        $('#alertaCorreccion').removeClass('d-none');
    } else {
        $('#alertaCorreccion').addClass('d-none');
    }

    $.get($.MisUrls.url._Inv_ObtenerProductosParaConteo, { idTienda: idTienda }, function (resp) {
        var productos = (resp && resp.data) ? resp.data : [];
        construirTabla(productos);
        mostrarConteo();
        toastr.info('Retomando conteo de ' + numero + '.');
    }).fail(function () {
        toastr.error('No se pudieron cargar los productos.');
    });
}

// ── Construir DataTable con todos los productos ───────────────────────────────
function construirTabla(productos) {
    // Destruir instancia previa si existe
    if (dtConteo) { dtConteo.destroy(); dtConteo = null; }

    var tbody = $('#tbodyConteo').empty();

    productos.forEach(function (p, idx) {
        tbody.append(
            '<tr>' +
            '<td>' + esc(p.Categoria || 'Sin categoría') + '</td>' +
            '<td>' + esc(p.Codigo || '—') + '</td>' +
            '<td>' + esc(p.Nombre) + '</td>' +
            '<td class="text-center">' +
                '<input type="number" ' +
                    'class="form-control form-control-sm text-center qty-input" ' +
                    'data-id="' + p.IdProducto + '" ' +
                    'min="0" max="' + LIMITE_CANTIDAD + '" step="1" value="0" ' +
                    'oninput="this.value = Math.min(' + LIMITE_CANTIDAD + ', Math.max(0, parseInt(this.value) || 0))" ' +
                    'onkeypress="return /[0-9]/.test(event.key)" />' +
            '</td>' +
            '</tr>'
        );
    });

    // Inicializar DataTable
    dtConteo = $('#tblConteo').DataTable({
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        pageLength: 25,
        order: [[0, 'asc'], [2, 'asc']],   // ordenar por categoría, luego nombre
        columnDefs: [
            { targets: 3, orderable: false, searchable: false }  // columna cantidad: no ordenar/buscar
        ],
        dom: '<"row mb-2"<"col-sm-6"l><"col-sm-6"f>>rtip'
    });

    actualizarContador();

    // Actualizar contador al cambiar cantidades
    $('#tblConteo').on('input', '.qty-input', function () {
        actualizarContador();
    });
}

function actualizarContador() {
    if (!dtConteo) return;
    var allInputs = $(dtConteo.rows().nodes().toArray()).find('.qty-input');
    var total = allInputs.length;
    var conCantidad = allInputs.filter(function () {
        return parseInt($(this).val()) > 0;
    }).length;
    $('#lblCantItems').text(conCantidad + ' de ' + total + ' productos con cantidad > 0');
}

// ── Finalizar conteo — envía TODOS los productos (incluso los en 0) ──────────
function finalizar() {
    var idInventario = parseInt($('#hdnIdInventarioActivo').val());

    if (!dtConteo) { toastr.warning('No hay productos cargados.'); return; }

    // API de DataTables: obtiene TODAS las filas (incluso filtradas/paginadas)
    var inputs = $(dtConteo.rows().nodes().toArray()).find('.qty-input');

    if (inputs.length === 0) {
        toastr.warning('No hay productos cargados en la tabla.');
        return;
    }

    var observacion = $('#txtObservacion').val().trim();
    if (observacion.length < 2) {
        toastr.warning('La observación es obligatoria antes de finalizar el conteo (mínimo 2 caracteres).');
        $('#txtObservacion').focus();
        return;
    }

    // Validación defensiva: ningún valor puede superar el tope permitido
    var fueraDeRango = inputs.filter(function () {
        var v = parseInt($(this).val()) || 0;
        return v < 0 || v > LIMITE_CANTIDAD;
    }).length;
    if (fueraDeRango > 0) {
        toastr.error('Hay ' + fueraDeRango + ' producto(s) con una cantidad fuera de rango (0 a ' + LIMITE_CANTIDAD + '). Corríjalos antes de finalizar.');
        return;
    }

    var conCantidad = inputs.filter(function () { return parseInt($(this).val()) > 0; }).length;
    var enCero      = inputs.length - conCantidad;

    Swal.fire({
        title: '¿Finalizar inventario?',
        html: '<table class="table table-sm table-bordered mt-2 mb-1">' +
              '<tr><td class="text-left">Productos contados (cantidad &gt; 0)</td><td class="text-center font-weight-bold text-success">' + conCantidad + '</td></tr>' +
              '<tr><td class="text-left">Productos no contados (no se registran)</td><td class="text-center font-weight-bold text-muted">' + enCero + '</td></tr>' +
              '<tr class="table-dark"><td class="text-left">Total productos en la sucursal</td><td class="text-center font-weight-bold">' + inputs.length + '</td></tr>' +
              '</table>' +
              'Solo se enviarán los <strong>' + conCantidad + '</strong> productos con cantidad ingresada.<br>El inventario pasará a <em>Pendiente de Aprobación</em>.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, finalizar',
        confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (res) {
        if (!res.isConfirmed) return;

        // Solo incluir productos con cantidad > 0 (los que el operador contó físicamente)
        var xml = '<Detalle>';
        var contados = 0;
        inputs.each(function () {
            var qty = parseInt($(this).val()) || 0;
            if (qty > 0) {
                xml += '<Item>' +
                    '<IdProducto>' + $(this).data('id') + '</IdProducto>' +
                    '<CantidadContada>' + qty + '</CantidadContada>' +
                    '</Item>';
                contados++;
            }
        });
        xml += '</Detalle>';

        if (contados === 0) {
            toastr.warning('Debe ingresar al menos un producto con cantidad mayor a 0.');
            return;
        }

        $.post($.MisUrls.url._Inv_FinalizarConteo, {
            idInventario: idInventario,
            detalleXml:   xml,
            observacion:  $('#txtObservacion').val()
        }, function (r) {
            if (r.resultado) {
                toastr.success(r.mensaje);
                if (dtConteo) { dtConteo.destroy(); dtConteo = null; }
                mostrarLista();
                cargarAsignados();
            } else {
                // No se toca la tabla: las cantidades cargadas siguen ahí, el operador solo corrige y reintenta.
                toastr.error(r.mensaje);
            }
        }).fail(function () {
            // Error de red/sesión (no llegó a responder el servidor): tampoco se pierde nada,
            // la tabla de conteo sigue intacta para reintentar.
            toastr.error('No se pudo guardar el conteo (problema de conexión o sesión expirada). Sus cantidades siguen cargadas; revise su conexión e intente "Finalizar" de nuevo.');
        });
    });
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function mostrarLista()  { $('#panelLista').show();  $('#panelConteo').hide(); }
function mostrarConteo() { $('#panelLista').hide();  $('#panelConteo').show(); }

function esc(s) { return (s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

function fmtFecha(dt) {
    if (!dt) return '—';
    var ms = /\/Date\((\d+)/.exec(dt);
    var f = ms ? new Date(parseInt(ms[1], 10)) : new Date(dt.replace(' ', 'T'));
    if (isNaN(f.getTime())) return dt;
    var p = function (n) { return ('0' + n).slice(-2); };
    return p(f.getDate()) + '/' + p(f.getMonth() + 1) + '/' + f.getFullYear() +
           ' ' + p(f.getHours()) + ':' + p(f.getMinutes());
}
