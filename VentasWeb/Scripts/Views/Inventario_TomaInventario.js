// Inventario_TomaInventario.js — conteo físico por producto (buscar y agregar)
'use strict';

var items = [];   // {IdProductoTienda, IdProducto, Nombre, StockSistema, StockContado}

$(function () {
    activarMenu("Inventario");

    // ── Inicializar selector de sucursal ──────────────────────────────
    if (AppSession.esSuperAdmin) {
        // SuperAdmin: cargar todas las tiendas en el dropdown
        $.get($.MisUrls.url._ObtenerTiendas, function (r) {
            var lista = (r && r.data) ? r.data : [];
            var $cbo = $('#cboTiendaInventario').empty();
            $cbo.append('<option value="">-- Seleccione sucursal --</option>');
            lista.forEach(function (t) {
                if (t.Activo)
                    $cbo.append($('<option>').val(t.IdTienda).text(t.Nombre));
            });
            if (AppSession.tiendaOperativa)
                $cbo.val(AppSession.tiendaOperativa);
        });

        $('#cboTiendaInventario').on('change', function () {
            items = []; pintar();
            $('#txtBuscar').val(''); $('#txtContado').val('');
            $('#hdnIdProductoTienda').val(''); $('#hdnIdProducto').val(''); $('#hdnStockSistema').val('');
            $('#sugerencias').empty();
        });
    } else {
        // No-superAdmin: mostrar nombre de su tienda como etiqueta
        $.get($.MisUrls.url._ObtenerTiendas, function (r) {
            var lista = (r && r.data) ? r.data : [];
            var tienda = lista.filter(function (t) { return t.IdTienda == AppSession.tiendaOperativa; })[0];
            $('#lblNombreTienda').text(tienda ? tienda.Nombre : 'Sucursal ' + AppSession.tiendaOperativa);
        });
    }

    // ── Autocompletar productos de la tienda ──────────────────────────
    $('#txtBuscar').on('keyup', function () {
        var q = $(this).val().trim();
        if (q.length < 2) { $('#sugerencias').empty(); return; }
        var idTienda = getIdTienda();
        if (!idTienda) { toastr.warning('Seleccioná una sucursal primero.'); return; }

        $.get($.MisUrls.url._ObtenerProductosPorTiendaBaja, { idTienda: idTienda }, function (r) {
            var lista = (r && r.data) ? r.data : [];
            var ql = q.toLowerCase();
            var fil = lista.filter(function (p) {
                return (p.Nombre && p.Nombre.toLowerCase().indexOf(ql) >= 0) ||
                       (p.Codigo && p.Codigo.toLowerCase().indexOf(ql) >= 0);
            }).slice(0, 8);
            var c = $('#sugerencias').empty();
            fil.forEach(function (p) {
                $('<a href="#" class="list-group-item list-group-item-action py-1">')
                    .text((p.Codigo || '') + ' — ' + p.Nombre + ' (stock: ' + p.Stock + ')')
                    .on('click', function (e) {
                        e.preventDefault();
                        $('#hdnIdProductoTienda').val(p.IdProductoTienda);
                        $('#hdnIdProducto').val(p.IdProducto);
                        $('#hdnStockSistema').val(p.Stock);
                        $('#txtBuscar').val((p.Codigo || '') + ' — ' + p.Nombre);
                        $('#sugerencias').empty();
                        $('#txtContado').focus();
                    }).appendTo(c);
            });
        });
    });

    $('#btnAgregar').on('click', agregar);
    $('#btnGuardar').on('click', guardar);
});

// Devuelve el idTienda a usar: dropdown si SuperAdmin, sesión si no
function getIdTienda() {
    if (AppSession.esSuperAdmin)
        return parseInt($('#cboTiendaInventario').val()) || 0;
    return AppSession.tiendaOperativa || 0;
}

function agregar() {
    var idPT = parseInt($('#hdnIdProductoTienda').val()) || 0;
    var contado = $('#txtContado').val();
    if (idPT === 0) { toastr.warning('Seleccioná un producto de la lista.'); return; }
    if (contado === '' || parseInt(contado) < 0) { toastr.warning('Ingresá el stock contado.'); return; }
    if (items.some(function (i) { return i.IdProductoTienda === idPT; })) {
        toastr.warning('Ese producto ya está en la lista.'); return;
    }
    items.push({
        IdProductoTienda: idPT,
        IdProducto: parseInt($('#hdnIdProducto').val()),
        Nombre: $('#txtBuscar').val(),
        StockSistema: parseInt($('#hdnStockSistema').val()) || 0,
        StockContado: parseInt(contado)
    });
    pintar();
    $('#txtBuscar').val(''); $('#txtContado').val('');
    $('#hdnIdProductoTienda').val(''); $('#hdnIdProducto').val(''); $('#hdnStockSistema').val('');
}

function pintar() {
    var t = $('#tbodyConteo').empty();
    items.forEach(function (i, idx) {
        var dif = i.StockContado - i.StockSistema;
        var col = dif === 0 ? '' : (dif > 0 ? 'text-success' : 'text-danger');
        t.append('<tr>' +
            '<td>' + i.Nombre + '</td>' +
            '<td class="text-center">' + i.StockSistema + '</td>' +
            '<td class="text-center">' + i.StockContado + '</td>' +
            '<td class="text-center ' + col + '"><strong>' + (dif > 0 ? '+' : '') + dif + '</strong></td>' +
            '<td class="text-center"><button class="btn btn-xs btn-danger btn-sm" onclick="quitar(' + idx + ')"><i class="fas fa-trash"></i></button></td>' +
            '</tr>');
    });
}

function quitar(idx) { items.splice(idx, 1); pintar(); }

function guardar() {
    if (items.length === 0) { toastr.warning('Agregá al menos un producto contado.'); return; }
    var idTienda = getIdTienda();
    if (!idTienda) { toastr.warning('Seleccioná una sucursal antes de guardar.'); return; }

    var xml = '<Detalle>' + items.map(function (i) {
        return '<Item><IdProductoTienda>' + i.IdProductoTienda + '</IdProductoTienda>' +
               '<StockContado>' + i.StockContado + '</StockContado></Item>';
    }).join('') + '</Detalle>';

    Swal.fire({
        title: '¿Registrar inventario?', text: 'Quedará pendiente de aprobación.',
        icon: 'question', showCancelButton: true, confirmButtonText: 'Sí, registrar', confirmButtonColor: '#28a745'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RegistrarInventario, { detalleXml: xml, observacion: $('#txtObservacion').val(), idTienda: idTienda }, function (res) {
            if (res.resultado) {
                toastr.success(res.mensaje);
                items = []; pintar(); $('#txtObservacion').val('');
            } else toastr.error(res.mensaje);
        });
    });
}
