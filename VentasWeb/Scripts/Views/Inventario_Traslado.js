// Inventario_Traslado.js
// Flujo 4 pasos — Operador:
//   Paso 1 (DESTINO): Solicitar traslado con múltiples productos
//   Paso 3 (ORIGEN):  Despachar traslado aprobado
//   Paso 4 (DESTINO): Recepcionar traslado despachado
//   Paso 2 → Inventario_AprobarTraslados.js (supervisor ORIGEN)

'use strict';

var carrito = [];           // { idProducto, codigo, nombre, stock }
var _productosOrigen = [];  // cache de productos del origen seleccionado

// ══════════════════════════════════════════════════════════════
// INIT
// ══════════════════════════════════════════════════════════════
$(document).ready(function () {
    cargarTiendas();
    cargarDespachar();
    cargarRecepcionar();
    inicializarFechasHistorial();

    $('#cboTiendaOrigen').on('change', function () {
        var id = parseInt($(this).val());
        carrito = [];
        _productosOrigen = [];
        renderizarCarrito();
        if (!id) {
            $('#divTablaProductos').hide();
            $('#divSinTienda').show();
        } else {
            cargarProductos(id);
        }
    });

    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        var target = $(e.target).attr('href');
        if (target === '#panel-despachar') cargarDespachar();
        if (target === '#panel-recepcionar') cargarRecepcionar();
    });
});

// ══════════════════════════════════════════════════════════════
// PASO 1 — SOLICITAR
// ══════════════════════════════════════════════════════════════

function cargarTiendas() {
    var miTienda = parseInt(AppSession.tiendaOperativa) || 0;

    // Mostrar mi sucursal en campo readonly
    $.get($.MisUrls.url._ObtenerTiendas, function (r) {
        var lista = (r && r.data) ? r.data : [];
        var $cbo = $('#cboTiendaOrigen');
        $cbo.find('option:not(:first)').remove();

        var miNombre = '';
        $.each(lista, function (_, t) {
            if (t.IdTienda === miTienda) {
                miNombre = t.Nombre;
            } else {
                $cbo.append('<option value="' + t.IdTienda + '">' + t.Nombre + '</option>');
            }
        });
        $('#txtMiSucursal').val(miNombre || 'Mi sucursal');
    });
}

function cargarProductos(idTienda) {
    $('#tbodyProductos').html('<tr><td colspan="4" class="text-center py-2"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');
    $('#divTablaProductos').show();
    $('#divSinTienda').hide();

    $.get($.MisUrls.url._ObtenerStock, { idtienda: idTienda }, function (r) {
        _productosOrigen = (r && r.data) ? r.data : [];
        // Filtrar solo productos con stock > 0
        _productosOrigen = _productosOrigen.filter(function (p) { return p.Stock > 0; });
        $('#lblTotalProductos').text(_productosOrigen.length + ' producto(s) con stock disponible');
        renderizarTablaProductos(_productosOrigen);
    }).fail(function () {
        $('#tbodyProductos').html('<tr><td colspan="4" class="text-center text-danger">Error al cargar productos.</td></tr>');
    });
}

function renderizarTablaProductos(lista) {
    var $tbody = $('#tbodyProductos');
    if (!lista || lista.length === 0) {
        $tbody.html('<tr><td colspan="4" class="text-center text-muted py-2">Sin productos con stock en esta sucursal.</td></tr>');
        return;
    }
    var html = '';
    $.each(lista, function (_, p) {
        var enCarrito = carrito.some(function (c) { return c.idProducto === p.IdProducto; });
        var btnClass = enCarrito ? 'btn-success disabled' : 'btn-outline-warning';
        var btnText  = enCarrito
            ? '<i class="fas fa-check"></i> Agregado'
            : '<i class="fas fa-plus"></i> Agregar';
        html += '<tr>' +
                '<td>' + p.Codigo + '</td>' +
                '<td>' + p.NombreProducto + '</td>' +
                '<td class="text-center">' + p.Stock + '</td>' +
                '<td class="text-center">' +
                '<button class="btn btn-sm ' + btnClass + '" ' +
                (enCarrito ? 'disabled ' : '') +
                'onclick="agregarAlCarrito(' + p.IdProducto + ',\'' + esc(p.Codigo) + '\',\'' + esc(p.NombreProducto) + '\',' + p.Stock + ')">' +
                btnText + '</button></td></tr>';
    });
    $tbody.html(html);
}

function filtrarProductos(query) {
    var q = (query || '').toLowerCase().trim();
    if (!q) { renderizarTablaProductos(_productosOrigen); return; }
    var filtrados = _productosOrigen.filter(function (p) {
        return (p.Codigo + ' ' + p.NombreProducto).toLowerCase().indexOf(q) >= 0;
    });
    renderizarTablaProductos(filtrados);
}

function agregarAlCarrito(idProducto, codigo, nombre, stock) {
    if (carrito.some(function (c) { return c.idProducto === idProducto; })) return;
    carrito.push({ idProducto: idProducto, codigo: codigo, nombre: nombre, stock: stock });
    renderizarTablaProductos(_productosOrigen);
    renderizarCarrito();
}

function quitarDelCarrito(idProducto) {
    carrito = carrito.filter(function (c) { return c.idProducto !== idProducto; });
    renderizarTablaProductos(_productosOrigen);
    renderizarCarrito();
}

function renderizarCarrito() {
    if (carrito.length === 0) {
        $('#divCarrito').hide();
        return;
    }
    var html = '';
    $.each(carrito, function (_, c) {
        html += '<tr>' +
                '<td>' + c.codigo + '</td>' +
                '<td>' + c.nombre + '</td>' +
                '<td class="text-center">' +
                '<input type="number" id="qty_' + c.idProducto + '" ' +
                'class="form-control form-control-sm text-center" ' +
                'min="1" max="' + c.stock + '" value="1" style="width:80px;display:inline-block;" />' +
                '</td>' +
                '<td class="text-center">' + c.stock + '</td>' +
                '<td class="text-center">' +
                '<button class="btn btn-sm btn-outline-danger" onclick="quitarDelCarrito(' + c.idProducto + ')">' +
                '<i class="fas fa-trash-alt"></i></button></td></tr>';
    });
    $('#tbodyCarrito').html(html);
    $('#divCarrito').show();
}

function enviarSolicitud() {
    if (carrito.length === 0) {
        Swal.fire('Atención', 'Agregá al menos un producto al carrito.', 'warning');
        return;
    }
    var obs = $('#txtObservaciones').val().trim();
    if (!obs) {
        Swal.fire('Atención', 'El campo Observaciones es obligatorio.', 'warning');
        $('#txtObservaciones').focus();
        return;
    }

    var errCantidad = false;
    $.each(carrito, function (_, c) {
        var qty = parseInt($('#qty_' + c.idProducto).val());
        if (isNaN(qty) || qty < 1 || qty > c.stock) { errCantidad = true; return false; }
    });
    if (errCantidad) {
        Swal.fire('Atención', 'Revisá las cantidades: deben ser entre 1 y el stock disponible.', 'warning');
        return;
    }

    var xml = '<D>';
    $.each(carrito, function (_, c) {
        var qty = parseInt($('#qty_' + c.idProducto).val());
        xml += '<I><P>' + c.idProducto + '</P><C>' + qty + '</C></I>';
    });
    xml += '</D>';

    var idOrigen = parseInt($('#cboTiendaOrigen').val());

    Swal.fire({
        title: '¿Confirmar solicitud?',
        text: 'Se enviará la solicitud al supervisor de la sucursal origen para aprobación.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, enviar',
        cancelButtonText: 'Cancelar'
    }).then(function (result) {
        if (!result.isConfirmed) return;

        $.post($.MisUrls.url._Inv_CrearSolicitudTraslado, {
            idTiendaOrigen: idOrigen,
            detalleXml: xml,
            observaciones: obs
        }, function (data) {
            if (data && data.resultado) {
                Swal.fire('¡Enviado!', 'Solicitud de traslado creada. Aguardá la aprobación del supervisor.', 'success');
                carrito = [];
                _productosOrigen = [];
                $('#cboTiendaOrigen').val('');
                $('#txtObservaciones').val('');
                $('#divTablaProductos').hide();
                $('#divSinTienda').show();
                $('#divCarrito').hide();
            } else {
                Swal.fire('Error', (data && data.mensaje) || 'No se pudo crear la solicitud.', 'error');
            }
        }).fail(function () {
            Swal.fire('Error', 'Error de comunicación con el servidor.', 'error');
        });
    });
}

// ══════════════════════════════════════════════════════════════
// PASO 3 — DESPACHAR (mi tienda es ORIGEN)
// ══════════════════════════════════════════════════════════════

function cargarDespachar() {
    $.get($.MisUrls.url._Inv_ObtenerTraslados, { estado: 'Aprobado', rol: 'origen' }, function (r) {
        var lista = (r && r.data) ? r.data : [];
        var $tbody = $('#tbodyDespachar');
        actualizarBadge('badgeDespachar', lista.length);

        if (lista.length === 0) {
            $('#divDespacharVacio').show();
            $tbody.html('');
            return;
        }
        $('#divDespacharVacio').hide();

        var html = '';
        $.each(lista, function (_, t) {
            html += '<tr>' +
                    '<td><strong>' + t.Numero + '</strong></td>' +
                    '<td>' + t.FechaTraslado + '</td>' +
                    '<td>' + t.TiendaDestino + '</td>' +
                    '<td>' + t.Usuario + '</td>' +
                    '<td>' + (t.UsuarioAprueba || '-') + '</td>' +
                    '<td class="text-center">' + t.CantidadItems + ' ítem(s) / ' + t.TotalUnidades + ' u.</td>' +
                    '<td class="text-center">' +
                    '<button class="btn btn-sm btn-outline-dark mr-1" onclick="verDetalle(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                    '<i class="fas fa-eye"></i></button>' +
                    '<button class="btn btn-sm btn-primary" onclick="despachar(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                    '<i class="fas fa-truck mr-1"></i>Despachar</button>' +
                    '</td></tr>';
        });
        $tbody.html(html);
    });
}

function despachar(idTraslado, numero) {
    Swal.fire({
        title: 'Despachar T-' + numero,
        text: 'Se descontará el stock de tu sucursal para los productos del traslado. Esta acción no se puede deshacer.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, despachar',
        confirmButtonColor: '#007bff',
        cancelButtonText: 'Cancelar'
    }).then(function (result) {
        if (!result.isConfirmed) return;
        $.post($.MisUrls.url._Inv_DespacharTraslado, { idTraslado: idTraslado }, function (data) {
            if (data && data.resultado) {
                Swal.fire('¡Despachado!', 'Traslado N° ' + numero + ' marcado como despachado.', 'success');
                cargarDespachar();
            } else {
                Swal.fire('Error', (data && data.mensaje) || 'No se pudo despachar.', 'error');
            }
        }).fail(function () {
            Swal.fire('Error', 'Error de comunicación con el servidor.', 'error');
        });
    });
}

// ══════════════════════════════════════════════════════════════
// PASO 4 — RECEPCIONAR (mi tienda es DESTINO)
// ══════════════════════════════════════════════════════════════

function cargarRecepcionar() {
    $.get($.MisUrls.url._Inv_ObtenerTraslados, { estado: 'Despachado', rol: 'destino' }, function (r) {
        var lista = (r && r.data) ? r.data : [];
        var $tbody = $('#tbodyRecepcionar');
        actualizarBadge('badgeRecepcionar', lista.length);

        if (lista.length === 0) {
            $('#divRecepcionarVacio').show();
            $tbody.html('');
            return;
        }
        $('#divRecepcionarVacio').hide();

        var html = '';
        $.each(lista, function (_, t) {
            html += '<tr>' +
                    '<td><strong>' + t.Numero + '</strong></td>' +
                    '<td>' + t.FechaTraslado + '</td>' +
                    '<td>' + t.TiendaOrigen + '</td>' +
                    '<td>' + (t.UsuarioDespacha || '-') + '</td>' +
                    '<td>' + (t.FechaDespacho || '-') + '</td>' +
                    '<td class="text-center">' + t.CantidadItems + ' ítem(s) / ' + t.TotalUnidades + ' u.</td>' +
                    '<td class="text-center">' +
                    '<button class="btn btn-sm btn-outline-dark mr-1" onclick="verDetalle(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                    '<i class="fas fa-eye"></i></button>' +
                    '<button class="btn btn-sm btn-success" onclick="recepcionar(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                    '<i class="fas fa-box-open mr-1"></i>Recepcionar</button>' +
                    '</td></tr>';
        });
        $tbody.html(html);
    });
}

function recepcionar(idTraslado, numero) {
    Swal.fire({
        title: 'Recepcionar T-' + numero,
        text: 'Se acreditará el stock en tu sucursal. Esta acción no se puede deshacer.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Sí, recepcionar',
        confirmButtonColor: '#28a745',
        cancelButtonText: 'Cancelar'
    }).then(function (result) {
        if (!result.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RecepcionarTraslado, { idTraslado: idTraslado }, function (data) {
            if (data && data.resultado) {
                Swal.fire('¡Completado!', 'Traslado N° ' + numero + ' recibido. Stock actualizado en tu sucursal.', 'success');
                cargarRecepcionar();
            } else {
                Swal.fire('Error', (data && data.mensaje) || 'No se pudo recepcionar.', 'error');
            }
        }).fail(function () {
            Swal.fire('Error', 'Error de comunicación con el servidor.', 'error');
        });
    });
}

// ══════════════════════════════════════════════════════════════
// DETALLE (modal compartido)
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
            html += '<tr>' +
                    '<td>' + item.CodigoProducto + '</td>' +
                    '<td>' + item.NombreProducto + '</td>' +
                    '<td class="text-center">' + item.Cantidad + '</td>' +
                    '<td class="text-center">' + item.StockOrigen + '</td>' +
                    '</tr>';
        });
        $('#tbodyDetalle').html(html);
    }).fail(function () {
        $('#tbodyDetalle').html('<tr><td colspan="4" class="text-center text-danger">Error al cargar detalle.</td></tr>');
    });
}

// ══════════════════════════════════════════════════════════════
// HISTORIAL
// ══════════════════════════════════════════════════════════════

function inicializarFechasHistorial() {
    var hoy = new Date();
    var primerDia = new Date(hoy.getFullYear(), hoy.getMonth(), 1);

    function fmt(d) {
        var dd = ('0' + d.getDate()).slice(-2);
        var mm = ('0' + (d.getMonth() + 1)).slice(-2);
        return dd + '/' + mm + '/' + d.getFullYear();
    }
    $('#txtFechaInicio').val(fmt(primerDia));
    $('#txtFechaFin').val(fmt(hoy));

    if ($.fn.datepicker) {
        $('#txtFechaInicio, #txtFechaFin').datepicker({ format: 'dd/mm/yyyy', autoclose: true, language: 'es' });
    }
}

function buscarHistorial() {
    var fi = $('#txtFechaInicio').val().trim();
    var ff = $('#txtFechaFin').val().trim();
    if (!fi || !ff) { Swal.fire('Atención', 'Seleccioná ambas fechas.', 'warning'); return; }
    cargarHistorial(fi, ff, $('#ddlEstadoHistorial').val());
}

function cargarHistorial(fi, ff, estado) {
    var $tbody = $('#tbodyHistorial');
    $tbody.html('<tr><td colspan="9" class="text-center"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');

    $.get($.MisUrls.url._Inv_ObtenerHistorialTraslados, {
        fechainicio: fi,
        fechafin: ff,
        estado: estado || ''
    }, function (r) {
        var lista = (r && r.data) ? r.data : [];
        if (lista.length === 0) {
            $tbody.html('<tr><td colspan="9" class="text-center text-muted py-2">Sin registros para el período.</td></tr>');
            return;
        }
        var html = '';
        $.each(lista, function (_, t) {
            html += '<tr>' +
                    '<td>' + t.Numero + '</td>' +
                    '<td>' + t.FechaTraslado + '</td>' +
                    '<td>' + t.TiendaOrigen + '</td>' +
                    '<td>' + t.TiendaDestino + '</td>' +
                    '<td>' + t.Usuario + '</td>' +
                    '<td class="text-center">' + t.CantidadItems + '</td>' +
                    '<td class="text-center">' + t.TotalUnidades + '</td>' +
                    '<td class="text-center">' + badgeEstado(t.EstadoAprobacion) + '</td>' +
                    '<td class="text-center">' +
                    '<button class="btn btn-xs btn-outline-dark" onclick="verDetalle(' + t.IdTraslado + ',\'' + esc(t.Numero) + '\')">' +
                    '<i class="fas fa-eye"></i></button></td></tr>';
        });
        $tbody.html(html);
    }).fail(function () {
        $tbody.html('<tr><td colspan="9" class="text-center text-danger">Error al cargar historial.</td></tr>');
    });
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════

function actualizarBadge(id, count) {
    var $badge = $('#' + id);
    if (count > 0) { $badge.text(count).show(); }
    else { $badge.hide(); }
}

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
