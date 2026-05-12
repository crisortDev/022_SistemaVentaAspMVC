// ══════════════════════════════════════════════════════════════════════
//  OrdenCompra_Crear.js
//  - Proveedor y Tienda se bloquean tras agregar el primer producto
//  - Selección múltiple desde modal (no se cierra al seleccionar)
//  - Cantidad y Precio editables inline en la tabla
// ══════════════════════════════════════════════════════════════════════

var tablaproveedor;
var tablatienda;
var tablaproducto;

// ─── Utilidades ───────────────────────────────────────────────────────
function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

function formatNum(n) {
    n = Number(n || 0);
    return n.toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

// Debounce: ejecuta fn solo si pasaron `ms` ms sin nuevas llamadas
function debounce(fn, ms) {
    var timer;
    return function () {
        var args = arguments, ctx = this;
        clearTimeout(timer);
        timer = setTimeout(function () { fn.apply(ctx, args); }, ms);
    };
}

// ─── Validación de fechas ─────────────────────────────────────────────
/**
 * Valida la coherencia entre Fecha Entrega Estimada y Fecha Tope de Entrega.
 * @param {boolean} mostrarError  Si true muestra SweetAlert en caso de error.
 * @returns {boolean}  true = fechas OK (o vacías), false = hay error.
 */
function parseFechaDDMMYYYY(str) {
    if (!str) return null;
    var p = str.split('/');
    if (p.length !== 3) return null;
    var d = new Date(parseInt(p[2]), parseInt(p[1]) - 1, parseInt(p[0]));
    return isNaN(d.getTime()) ? null : d;
}

function validarFechas(mostrarError) {
    var strEntrega = $("#txtFechaEntrega").val().trim();
    var strTope    = $("#txtFechaTopeEntrega").val().trim();

    var hoy     = new Date(); hoy.setHours(0, 0, 0, 0);
    var minTope = new Date(hoy); minTope.setDate(minTope.getDate() + 7);

    // ── Validar Fecha Tope ────────────────────────────────────────────
    if (strTope) {
        var dtTope = parseFechaDDMMYYYY(strTope);
        if (!dtTope) {
            if (mostrarError) Swal.fire({ title: 'Fecha inválida', text: 'La Fecha Tope de Entrega no tiene un formato válido (dd/mm/aaaa).', icon: 'warning' });
            $("#txtFechaTopeEntrega").addClass('is-invalid');
            return false;
        }
        if (dtTope < minTope) {
            if (mostrarError) Swal.fire({ title: 'Fecha Tope muy cercana', text: 'La Fecha Tope de Entrega debe ser al menos 7 días desde hoy.', icon: 'warning' });
            $("#txtFechaTopeEntrega").addClass('is-invalid');
            return false;
        }
        $("#txtFechaTopeEntrega").removeClass('is-invalid').addClass('is-valid');

        // ── Validar que Entrega Estimada ≤ Tope ──────────────────────
        if (strEntrega) {
            var dtEntrega = parseFechaDDMMYYYY(strEntrega);
            if (dtEntrega && dtEntrega > dtTope) {
                if (mostrarError) Swal.fire({
                    title: 'Fechas inconsistentes',
                    text:  'La Fecha de Entrega Estimada no puede ser posterior a la Fecha Tope de Entrega.',
                    icon:  'warning'
                });
                $("#txtFechaEntrega").addClass('is-invalid');
                return false;
            }
            $("#txtFechaEntrega").removeClass('is-invalid');
        }
    }

    return true;
}

// ─── Validación de stock en tiempo real (por fila) ────────────────────
var _stockTimers = {};   // timers por fila para debounce individual

function verificarStockFila(tr) {
    var idProducto = parseInt(tr.data('idproducto')) || 0;
    var idTienda   = parseInt($("#txtIdTienda").val()) || 0;
    var cantidad   = parseInt(tr.find('.inp-cantidad').val()) || 0;
    var $alerta    = tr.find('.stock-alert-fila');

    if (idProducto <= 0 || idTienda <= 0 || cantidad <= 0) {
        $alerta.hide();
        return;
    }

    $.ajax({
        url:      $.MisUrls.url._OC_ValidarStockItem,
        type:     "GET",
        dataType: "json",
        data:     { idtienda: idTienda, idproducto: idProducto, cantidad: cantidad },
        success: function (res) {
            if (res.supera) {
                $alerta
                    .html('<i class="fas fa-exclamation-triangle"></i> '
                        + 'Stock máx: <strong>' + res.stockMax + '</strong> | '
                        + 'Actual: ' + res.stockActual + ' | '
                        + 'Proyectado: <strong class="text-danger">' + res.proyectado + '</strong>')
                    .show();
                tr.find('.inp-cantidad').addClass('border-warning');
            } else {
                $alerta.hide();
                tr.find('.inp-cantidad').removeClass('border-warning');
            }
        },
        error: function () { $alerta.hide(); }
    });
}

// ─── Inicialización ───────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Compras");

    $.datepicker.setDefaults($.datepicker.regional['es']);

    // Fecha Entrega Estimada — sin restricción de mínimo
    $("#txtFechaEntrega").datepicker({
        dateFormat: 'dd/mm/yy',
        minDate:    0   // no puede ser en el pasado
    });

    // Fecha Tope de Entrega — mínimo 7 días desde hoy
    $("#txtFechaTopeEntrega").datepicker({
        dateFormat: 'dd/mm/yy',
        minDate:    '+7d',
        onSelect: function () {
            // Cuando se cambia el tope, revalidar la estimada si ya tiene valor
            validarFechas(false);
        }
    });

    inicializarDataTables();

    // Si no es SuperAdmin → cargar tienda automática y ocultar botón
    if (!AppSession.esSuperAdmin) {
        $("#divBtnBuscarTienda").hide();
        cargarTiendaAutomatica(AppSession.idTienda);
    }

    // Guardar orden
    $("#btnGuardarOrden").on("click", guardarOrden);

    // Eliminar fila del detalle
    $(document).on('click', '#tbDetalle tbody .btn-eliminar-fila', function () {
        $(this).closest('tr').remove();
        actualizarLockEstado();
        recalcularTotales();
    });

    // Edición inline: recalcular cuando cambia cantidad o precio
    $(document).on('input', '#tbDetalle tbody .inp-cantidad, #tbDetalle tbody .inp-precio', function () {
        actualizarFilaTotales($(this).closest('tr'));
        recalcularTotales();
    });

    // Validación de stock en tiempo real al cambiar la cantidad (debounce 600ms)
    $(document).on('input', '#tbDetalle tbody .inp-cantidad', function () {
        var tr      = $(this).closest('tr');
        var trIndex = tr.index();

        clearTimeout(_stockTimers[trIndex]);
        _stockTimers[trIndex] = setTimeout(function () {
            verificarStockFila(tr);
        }, 600);
    });

    // IVA global: ya no aplica — el IVA se toma del producto individual.
    // Se mantiene el campo en la vista solo como referencia informativa.
    // (sin handler de cambio)
});

// ─── DataTables ───────────────────────────────────────────────────────
function inicializarDataTables() {

    // Proveedores
    tablaproveedor = $('#tbProveedor').DataTable({
        "ajax": { "url": $.MisUrls.url._OC_ObtenerProveedores, "type": "GET", "datatype": "json" },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class="btn btn-sm btn-primary sel-proveedor-oc"
                                data-id="${row.IdProveedor}"
                                data-ruc="${row.Ruc}"
                                data-razon="${row.RazonSocial}">
                                <i class="fas fa-check"></i>
                            </button>`;
                },
                "orderable": false, "searchable": false, "width": "60px"
            },
            { "data": "Ruc" },
            { "data": "RazonSocial" },
            { "data": "Direccion" }
        ],
        "language": lenguajeDataTable()
    });

    $(document).on('click', '.sel-proveedor-oc', function () {
        $("#txtIdProveedor").val($(this).data('id'));
        $("#txtRucProveedor").val($(this).data('ruc'));
        $("#txtRazonSocialProveedor").val($(this).data('razon'));
        $('#modalProveedor').modal('hide');
    });

    // Tiendas (solo SuperAdmin)
    if (AppSession.esSuperAdmin) {
        tablatienda = $('#tbTienda').DataTable({
            "ajax": { "url": $.MisUrls.url._ObtenerTiendas, "type": "GET", "datatype": "json" },
            "columns": [
                {
                    "data": null,
                    "render": function (data, type, row) {
                        return `<button class="btn btn-sm btn-primary sel-tienda-oc"
                                    data-id="${row.IdTienda}"
                                    data-ruc="${row.RUC}"
                                    data-nombre="${row.Nombre}">
                                    <i class="fas fa-check"></i>
                                </button>`;
                    },
                    "orderable": false, "searchable": false, "width": "60px"
                },
                { "data": "RUC" },
                { "data": "Nombre" },
                { "data": "Direccion" }
            ],
            "language": lenguajeDataTable()
        });

        $(document).on('click', '.sel-tienda-oc', function () {
            var idTienda = $(this).data('id');
            $("#txtIdTienda").val(idTienda);
            $("#txtRucTienda").val($(this).data('ruc'));
            $("#txtNombreTienda").val($(this).data('nombre'));
            $('#modalTienda').modal('hide');
            if (tablaproducto) recargarProductosPorTienda(idTienda);
        });
    }

    // Productos
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductos,
            "type": "GET",
            "datatype": "json",
            "dataSrc": function (json) {
                if (json && json.data) return json.data;
                if (Array.isArray(json)) return json;
                return [];
            }
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class="btn btn-sm btn-success sel-producto-oc"
                                data-id="${row.IdProducto}"
                                data-codigo="${row.Codigo}"
                                data-nombre="${row.Nombre}"
                                data-iva="${row.IvaPorcentaje != null ? row.IvaPorcentaje : 10}">
                                <i class="fas fa-plus"></i>
                            </button>`;
                },
                "orderable": false, "searchable": false, "width": "50px"
            },
            { "data": "Codigo",      "width": "80px" },
            { "data": "Nombre" },
            { "data": "Descripcion" },
            { "data": "oCategoria",  "render": function(d) { return d ? d.Descripcion : ""; } },
            {
                "data": "IvaPorcentaje",
                "render": function(d) { return (d != null ? d : 10) + ' %'; },
                "className": "text-center",
                "width": "70px",
                "orderable": false,
                "searchable": false
            }
        ],
        "language": lenguajeDataTable()
    });

    // ── Selección de producto desde modal (NO cierra el modal) ─────────
    $(document).on('click', '.sel-producto-oc', function () {
        var btn        = $(this);
        var idProducto = btn.data('id');
        var codigo     = btn.data('codigo');
        var nombre     = btn.data('nombre');
        // Usar el IVA propio del producto; solo si es 0 puede ser exento (no usar global)
        var iva        = parseFloat(btn.data('iva'));
        if (isNaN(iva)) iva = 10;

        // Validar que proveedor y tienda estén seleccionados
        if (parseInt($("#txtIdProveedor").val()) <= 0) {
            Swal.fire({ title: "Atención", text: "Primero seleccioná un proveedor.", icon: "warning" });
            return;
        }
        if (parseInt($("#txtIdTienda").val()) <= 0) {
            Swal.fire({ title: "Atención", text: "Primero seleccioná una tienda.", icon: "warning" });
            return;
        }

        // Evitar duplicados — destacar la fila existente
        if ($("#tbDetalle tbody tr[data-idproducto='" + idProducto + "']").length > 0) {
            btn.html('<i class="fas fa-check-double"></i>').addClass('btn-warning').removeClass('btn-success');
            setTimeout(function () {
                btn.html('<i class="fas fa-plus"></i>').addClass('btn-success').removeClass('btn-warning');
            }, 1200);
            return;
        }

        // Agregar fila con qty/precio editables
        var tr = `<tr data-idproducto="${idProducto}" data-iva="${iva}">
            <td>
                <button type="button" class="btn btn-danger btn-sm btn-eliminar-fila">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
            <td>${codigo}</td>
            <td>${nombre}</td>
            <td>
                <input type="number" class="form-control form-control-sm inp-cantidad"
                       value="1" min="1" style="width:75px">
                <small class="stock-alert-fila text-warning d-block mt-1"
                       style="display:none!important;font-size:0.72em;line-height:1.3"></small>
            </td>
            <td>
                <input type="number" class="form-control form-control-sm inp-precio"
                       value="0" min="0" style="width:120px">
            </td>
            <td class="td-iva">${iva}</td>
            <td class="text-right td-total">0</td>
            <td class="text-right td-totaliva">0</td>
        </tr>`;

        $("#tbDetalle tbody").append(tr);
        actualizarLockEstado();
        recalcularTotales();

        // Feedback visual en el botón del modal
        btn.html('<i class="fas fa-check"></i> Agregado')
           .addClass('btn-secondary').removeClass('btn-success')
           .prop('disabled', true);
    });

    // Resetear botones al abrir el modal de productos
    $('#modalProducto').on('show.bs.modal', function () {
        // Rehabilitar todos los botones del modal
        $('#tbProducto tbody .sel-producto-oc')
            .html('<i class="fas fa-plus"></i>')
            .addClass('btn-success').removeClass('btn-secondary btn-warning')
            .prop('disabled', false);

        // Marcar los que ya están en la tabla
        $("#tbDetalle tbody tr").each(function () {
            var id = $(this).data('idproducto');
            $('#tbProducto tbody .sel-producto-oc[data-id="' + id + '"]')
                .html('<i class="fas fa-check"></i> Agregado')
                .addClass('btn-secondary').removeClass('btn-success')
                .prop('disabled', true);
        });
    });
}

function abrirModalProductos() { $('#modalProducto').modal('show'); }
function buscarProveedor()     { $('#modalProveedor').modal('show'); }
function buscarTienda()        { $('#modalTienda').modal('show'); }

function recargarProductosPorTienda(idTienda) {
    // En una OC se pueden pedir todos los productos (no solo los de esa tienda)
    // por lo que siempre cargamos el listado completo
    try {
        if (tablaproducto) {
            tablaproducto.ajax.url($.MisUrls.url._ObtenerProductos).load();
        }
    } catch (e) { console.error("Error al recargar productos:", e); }
}

function cargarTiendaAutomatica(idTienda) {
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        success: function (data) {
            if (data && data.data) {
                var t = data.data.find(x => x.IdTienda == idTienda);
                if (t) {
                    $("#txtIdTienda").val(t.IdTienda);
                    $("#txtRucTienda").val(t.RUC);
                    $("#txtNombreTienda").val(t.Nombre);
                }
            }
        }
    });
}

// ─── Lock de Proveedor y Tienda ───────────────────────────────────────
function actualizarLockEstado() {
    var tieneItems = $("#tbDetalle tbody tr").length > 0;

    if (tieneItems) {
        // Bloquear proveedor
        $("#btnBuscarProveedor")
            .prop('disabled', true)
            .removeClass('btn-success').addClass('btn-secondary')
            .html('<i class="fas fa-lock"></i> Bloqueado');

        // Bloquear tienda (solo SuperAdmin)
        if (AppSession.esSuperAdmin) {
            $("#btnBuscarTienda")
                .prop('disabled', true)
                .removeClass('btn-success').addClass('btn-secondary')
                .html('<i class="fas fa-lock"></i> Bloqueado');
        }
    } else {
        // Desbloquear
        $("#btnBuscarProveedor")
            .prop('disabled', false)
            .removeClass('btn-secondary').addClass('btn-success')
            .html('<i class="fas fa-search"></i> Buscar');

        if (AppSession.esSuperAdmin) {
            $("#btnBuscarTienda")
                .prop('disabled', false)
                .removeClass('btn-secondary').addClass('btn-success')
                .html('<i class="fas fa-search"></i> Buscar');
        }
    }
}

// Click en botón bloqueado → ofrecer limpiar
$(document).on('click', '#btnBuscarProveedor[disabled], #btnBuscarTienda[disabled]', function (e) {
    e.preventDefault();
    var tipo = $(this).attr('id') === 'btnBuscarProveedor' ? 'proveedor' : 'tienda';
    Swal.fire({
        title: "¿Cambiar " + tipo + "?",
        text: "Se limpiarán todos los productos del detalle.",
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: "Sí, limpiar",
        cancelButtonText: "Cancelar"
    }).then(function (r) {
        if (r.isConfirmed) {
            $("#tbDetalle tbody").empty();
            recalcularTotales();
            actualizarLockEstado();
        }
    });
});

// ─── Cálculos inline ─────────────────────────────────────────────────
function actualizarFilaTotales(tr) {
    var cantidad = parseFloat(tr.find('.inp-cantidad').val()) || 0;
    var precio   = parseFloat(tr.find('.inp-precio').val())   || 0;
    var iva      = parseFloat(tr.data('iva')) || 10;
    var total    = cantidad * precio;
    var totalIva = total * (1 + iva / 100);

    tr.find('.td-total').text(formatNum(total));
    tr.find('.td-totaliva').text(formatNum(totalIva));
}

function recalcularTotales() {
    var totalCantidad = 0, totalLinea = 0, totalLineaIva = 0;
    $("#tbDetalle tbody tr").each(function () {
        var tr       = $(this);
        var cantidad = parseFloat(tr.find('.inp-cantidad').val()) || 0;
        var precio   = parseFloat(tr.find('.inp-precio').val())   || 0;
        var iva      = parseFloat(tr.data('iva')) || 10;
        totalCantidad += cantidad;
        totalLinea    += cantidad * precio;
        totalLineaIva += cantidad * precio * (1 + iva / 100);
    });
    $("#tfCantidad").text(totalCantidad);
    $("#tfTotal").text(formatNum(totalLinea));
    $("#tfTotalIva").text(formatNum(totalLineaIva));
}

// ─── Guardar Orden ────────────────────────────────────────────────────
function guardarOrden() {
    var idProveedor      = parseInt($("#txtIdProveedor").val()) || 0;
    var idTienda         = parseInt($("#txtIdTienda").val())    || 0;
    var fechaEntrega     = $("#txtFechaEntrega").val().trim();
    var observacion      = $("#txtObservacion").val().trim();
    var idCategoriaOC    = parseInt($("#cboCategoria").val())   || 0;
    var fechaTopeEntrega = $("#txtFechaTopeEntrega").val().trim();

    if (idProveedor <= 0) { Swal.fire({ title: "Atención", text: "Debe seleccionar un proveedor.", icon: "warning" }); return; }
    if (idTienda    <= 0) { Swal.fire({ title: "Atención", text: "Debe seleccionar una tienda.",    icon: "warning" }); return; }

    // ── Validar coherencia de fechas ──────────────────────────────────
    if (!validarFechas(true)) return;

    // Construir detalle desde inputs inline
    var detalle = [];
    var filaInvalida = false;

    $("#tbDetalle tbody tr").each(function () {
        var tr       = $(this);
        var cantidad = parseInt(tr.find('.inp-cantidad').val())    || 0;
        var precio   = parseFloat(tr.find('.inp-precio').val())    || 0;
        var iva      = parseFloat(tr.data('iva'))                  || 10;

        if (cantidad <= 0 || precio <= 0) {
            filaInvalida = true;
            tr.find('.inp-cantidad, .inp-precio').addClass('is-invalid');
            return false;
        }
        tr.find('.inp-cantidad, .inp-precio').removeClass('is-invalid');

        detalle.push({
            oProducto:      { IdProducto: parseInt(tr.data('idproducto')) },
            Cantidad:        cantidad,
            PrecioUnitario:  precio,
            IvaPorcentaje:   iva,
            TotalLinea:      cantidad * precio,
            TotalLineaIva:   cantidad * precio * (1 + iva / 100)
        });
    });

    if (filaInvalida) {
        Swal.fire({ title: "Atención", text: "Hay productos con cantidad o precio en 0. Completá todos los campos.", icon: "warning" });
        return;
    }
    if (detalle.length === 0) {
        Swal.fire({ title: "Atención", text: "Debe agregar al menos un producto.", icon: "warning" });
        return;
    }

    // ── PASO 1: Validar stock máximo antes de confirmar ───────────────
    var itemsValidar = detalle.map(function (d) {
        return { IdProducto: d.oProducto.IdProducto, Cantidad: d.Cantidad };
    });

    var postData = { idtienda: idTienda };
    itemsValidar.forEach(function (it, i) {
        postData['items[' + i + '].IdProducto'] = it.IdProducto;
        postData['items[' + i + '].Cantidad']   = it.Cantidad;
    });

    $("body").LoadingOverlay("show");

    $.ajax({
        url:  $.MisUrls.url._OC_ValidarStock,
        type: "POST",
        data: postData,
        dataType: "json",
        complete: function () { $("body").LoadingOverlay("hide"); },
        success: function (res) {
            var advertencias = res.advertencias || [];

            if (advertencias.length > 0) {
                // Construir tabla de advertencias para el Swal
                var filas = advertencias.map(function (a) {
                    return '<tr>'
                         + '<td class="text-left"><strong>' + a.Producto + '</strong></td>'
                         + '<td class="text-center">' + a.StockActual + '</td>'
                         + '<td class="text-center text-primary">' + a.Pedido + '</td>'
                         + '<td class="text-center text-danger"><strong>' + a.Proyectado + '</strong></td>'
                         + '<td class="text-center">' + a.StockMax + '</td>'
                         + '</tr>';
                }).join('');

                var tablaHtml = '<div style="max-height:200px;overflow-y:auto;font-size:0.85em">'
                    + '<table class="table table-sm table-bordered mb-0">'
                    + '<thead class="thead-light"><tr>'
                    + '<th>Producto</th><th>Stock actual</th>'
                    + '<th>A pedir</th><th>Proyectado</th><th>Máximo</th>'
                    + '</tr></thead><tbody>' + filas + '</tbody></table></div>';

                Swal.fire({
                    title:             '⚠ Stock máximo superado',
                    html:              '<p class="mb-2 text-muted">Los siguientes productos superarían el stock máximo configurado:</p>'
                                     + tablaHtml
                                     + '<p class="mt-2 mb-0 text-muted" style="font-size:0.85em">Podés continuar igual o ajustar las cantidades.</p>',
                    icon:              'warning',
                    showCancelButton:  true,
                    confirmButtonText: 'Continuar de todas formas',
                    cancelButtonText:  'Ajustar cantidades',
                    confirmButtonColor: '#e67e22',
                    cancelButtonColor:  '#6c757d',
                    width:             '650px'
                }).then(function (r) {
                    if (r.isConfirmed) enviarGuardarOC(idProveedor, idTienda, fechaEntrega, observacion, idCategoriaOC, fechaTopeEntrega, detalle);
                });

            } else {
                // Sin advertencias → confirmar y guardar directamente
                Swal.fire({
                    title:             '¿Guardar la Orden de Compra?',
                    text:              'Quedará en estado Pendiente de aprobación.',
                    icon:              'info',
                    showCancelButton:  true,
                    confirmButtonText: 'Confirmar',
                    cancelButtonText:  'Cancelar'
                }).then(function (r) {
                    if (r.isConfirmed) enviarGuardarOC(idProveedor, idTienda, fechaEntrega, observacion, idCategoriaOC, fechaTopeEntrega, detalle);
                });
            }
        },
        error: function () {
            // Si la validación falla, igual preguntar y dejar guardar
            Swal.fire({
                title:             '¿Guardar la Orden de Compra?',
                text:              'Quedará en estado Pendiente de aprobación.',
                icon:              'info',
                showCancelButton:  true,
                confirmButtonText: 'Confirmar',
                cancelButtonText:  'Cancelar'
            }).then(function (r) {
                if (r.isConfirmed) enviarGuardarOC(idProveedor, idTienda, fechaEntrega, observacion, idCategoriaOC, fechaTopeEntrega, detalle);
            });
        }
    });
}

// ─── Enviar POST de guardado ───────────────────────────────────────────
function enviarGuardarOC(idProveedor, idTienda, fechaEntrega, observacion, idCategoriaOC, fechaTopeEntrega, detalle) {
    $.ajax({
        url:      $.MisUrls.url._OC_Guardar,
        type:     "POST",
        dataType: "json",
        data: {
            idproveedor:      idProveedor,
            idtienda:         idTienda,
            fechaentrega:     fechaEntrega,
            observacion:      observacion,
            idcategoriaoc:    idCategoriaOC,
            fechatopeentrega: fechaTopeEntrega,
            detalle:          detalle
        },
        traditional: false,
        beforeSend: function () { $("body").LoadingOverlay("show"); },
        complete:   function () { $("body").LoadingOverlay("hide"); },
        success: function (resp) {
            if (resp.resultado) {
                Swal.fire({ title: "Éxito", text: resp.mensaje || "Orden registrada correctamente.", icon: "success" })
                    .then(function () { window.location.href = $.MisUrls.url._OC_Consultar; });
            } else {
                Swal.fire({ title: "Error", text: resp.mensaje || "No se pudo registrar la orden.", icon: "error" });
            }
        },
        error: function () {
            Swal.fire({ title: "Error", text: "Error de comunicación con el servidor.", icon: "error" });
        }
    });
}
