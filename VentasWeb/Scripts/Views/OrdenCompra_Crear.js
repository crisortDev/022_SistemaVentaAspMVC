// ══════════════════════════════════════════════════════════════════════
//  OrdenCompra_Crear.js
//  - Proveedor y Tienda se bloquean tras agregar el primer producto
//  - Selección múltiple desde modal (no se cierra al seleccionar)
//  - Cantidad y Precio editables inline en la tabla
// ══════════════════════════════════════════════════════════════════════

var tablaproveedor;
var tablatienda;
var tablaproducto;
var _proveedorConDeuda = false;   // flag para bloquear guardado si proveedor tiene deuda

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

    var hoy     = _fechaServidorObj || (function(){ var d=new Date(); d.setHours(0,0,0,0); return d; })();
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
    var idProducto  = parseInt(tr.data('idproducto')) || 0;
    var idTienda    = parseInt($("#txtIdTienda").val()) || 0;
    var cantidad    = parseInt(tr.find('.inp-cantidad').val()) || 0;
    var $inp        = tr.find('.inp-cantidad');
    var $alerta     = tr.find('.stock-alert-fila');

    if (idProducto <= 0 || idTienda <= 0 || cantidad <= 0) {
        $alerta.hide();
        $inp.removeClass('is-invalid border-warning');
        return;
    }

    $.ajax({
        url:      $.MisUrls.url._OC_ValidarStockItem,
        type:     "GET",
        dataType: "json",
        data:     { idtienda: idTienda, idproducto: idProducto, cantidad: cantidad },
        success: function (res) {
            if (res.stockMax <= 0) {
                // Sin stock máximo configurado — sin restricción
                $alerta.hide();
                $inp.removeClass('is-invalid border-warning');
                return;
            }

            if (res.supera) {
                // Calcular cuánto se puede pedir como máximo
                var maxPedible = Math.max(0, res.stockMax - res.stockActual);

                if (maxPedible <= 0) {
                    // Ya está en stock máximo — no se puede pedir nada más
                    $alerta
                        .removeClass('text-warning').addClass('text-danger')
                        .html('<i class="fas fa-times-circle"></i> '
                            + 'El stock ya alcanzó el máximo permitido (<strong>' + res.stockMax + '</strong>). '
                            + '<strong>No se puede pedir más de este producto.</strong>')
                        .show();
                    $inp.val(0).addClass('is-invalid').removeClass('border-warning');
                } else {
                    // Ajustar automáticamente al máximo posible
                    $inp.val(maxPedible).removeClass('is-invalid').addClass('border-warning');
                    actualizarFilaTotales(tr);
                    recalcularTotales();
                    $alerta
                        .removeClass('text-danger').addClass('text-warning')
                        .html('<i class="fas fa-exclamation-triangle"></i> '
                            + 'Cantidad ajustada al máximo posible: <strong>' + maxPedible + '</strong> '
                            + '<small class="text-muted">(Stock actual: ' + res.stockActual
                            + ' · Stock máx: ' + res.stockMax + ')</small>')
                        .show();
                }
            } else {
                $alerta.hide();
                $inp.removeClass('is-invalid border-warning');
            }
        },
        error: function () {
            $alerta.hide();
            $inp.removeClass('is-invalid border-warning');
        }
    });
}

// ─── Fecha mínima desde servidor ─────────────────────────────────────
// Se obtiene una sola vez al cargar la página para que todos los
// datepickers usen la hora del servidor, no la del navegador del cliente.
var _fechaServidorStr = null;  // "dd/mm/yyyy"
var _fechaServidorObj = null;  // Date object (sin hora)

function cargarFechaServidor(callback) {
    $.ajax({
        url:      $.MisUrls.url._OC_FechaServidor,
        type:     'GET',
        dataType: 'json',
        success: function (r) {
            _fechaServidorStr = r.fecha;
            _fechaServidorObj = parseFechaDDMMYYYY(r.fecha);
            if (callback) callback();
        },
        error: function () {
            // Fallback al cliente si el servidor no responde
            var hoy = new Date(); hoy.setHours(0, 0, 0, 0);
            var dd  = String(hoy.getDate()).padStart(2, '0');
            var mm  = String(hoy.getMonth() + 1).padStart(2, '0');
            _fechaServidorStr = dd + '/' + mm + '/' + hoy.getFullYear();
            _fechaServidorObj = hoy;
            if (callback) callback();
        }
    });
}

// ─── Inicialización ───────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Compras");

    $.datepicker.setDefaults($.datepicker.regional['es']);

    // Primero obtener la fecha del servidor, luego inicializar datepickers
    cargarFechaServidor(function () {

        // Fecha Entrega Estimada — mínimo = hoy, valor por defecto = hoy
        $("#txtFechaEntrega").datepicker({
            dateFormat:  'dd/mm/yy',
            minDate:     _fechaServidorObj
        });
        $("#txtFechaEntrega").datepicker('setDate', _fechaServidorObj);

        // Fecha Tope de Entrega — mínimo = hoy + 7 días, valor por defecto = hoy + 7 días
        var minTope = new Date(_fechaServidorObj);
        minTope.setDate(minTope.getDate() + 7);

        $("#txtFechaTopeEntrega").datepicker({
            dateFormat: 'dd/mm/yy',
            minDate:    minTope,
            onSelect: function () {
                validarFechas(false);
            }
        });
        $("#txtFechaTopeEntrega").datepicker('setDate', minTope);
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
        var idProv  = $(this).data('id');
        var ruc     = $(this).data('ruc');
        var razon   = $(this).data('razon');

        $("#txtIdProveedor").val(idProv);
        $("#txtRucProveedor").val(ruc);
        $("#txtRazonSocialProveedor").val(razon);
        $('#modalProveedor').modal('hide');

        // ── Verificar deuda pendiente del proveedor ─────────────────
        _proveedorConDeuda = false;
        $('#alertaDeudaProveedor').remove();   // limpiar alerta anterior

        $.ajax({
            url:      $.MisUrls.url._OC_VerificarDeuda,
            type:     'GET',
            dataType: 'json',
            data:     { idproveedor: idProv },
            success: function (res) {
                if (res.tieneDeuda) {
                    _proveedorConDeuda = true;
                    var total = Math.round(res.total).toLocaleString('es-PY');
                    var alerta = '<div id="alertaDeudaProveedor" class="alert alert-danger mt-2 py-2" style="font-size:0.88rem">'
                        + '<i class="fas fa-exclamation-circle mr-1"></i>'
                        + '<strong>Atención:</strong> El proveedor <strong>' + razon + '</strong> tiene '
                        + '<strong>' + res.cantidad + '</strong> orden(es) de pago pendiente(s) '
                        + 'por un total de <strong>Gs. ' + total + '</strong>. '
                        + 'No se puede registrar una nueva OC hasta regularizar la deuda.'
                        + '</div>';
                    // Insertar alerta debajo del card de proveedor
                    $('.card.border-info:first').after(alerta);
                }
            }
        });
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

    // Productos — usa endpoint propio que incluye EstadoStock (sin revelar cantidad exacta)
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url":      $.MisUrls.url._OC_ProductosParaOC,
            "type":     "GET",
            "datatype": "json",
            "data":     function () {
                return { idtienda: parseInt($("#txtIdTienda").val()) || 0 };
            },
            "dataSrc": function (json) {
                return (json && json.data) ? json.data : [];
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
            { "data": "Codigo",    "width": "80px" },
            { "data": "Nombre",    "width": "20%" },
            {
                "data": "Descripcion",
                "render": function (val) {
                    if (!val) return '';
                    var corto = val.length > 55 ? val.substring(0, 55) + '…' : val;
                    return '<span title="' + val.replace(/"/g, '&quot;') + '">' + corto + '</span>';
                }
            },
            { "data": "Categoria", "width": "18%" },
            {
                "data": "IvaPorcentaje",
                "render": function(d) { return (d != null ? d : 10) + ' %'; },
                "className": "text-center",
                "width": "65px",
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
    // Recargar productos con el estado de stock de la tienda seleccionada
    try {
        if (tablaproducto) {
            tablaproducto.ajax.reload();
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
            // Si se cambia el proveedor, limpiar también la alerta de deuda
            _proveedorConDeuda = false;
            $('#alertaDeudaProveedor').remove();
            $("#txtIdProveedor").val('0');
            $("#txtRucProveedor").val('');
            $("#txtRazonSocialProveedor").val('');
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

    // ── Bloquear si el proveedor tiene deuda pendiente ────────────────
    if (_proveedorConDeuda) {
        Swal.fire({
            title: 'Proveedor con deuda pendiente',
            text:  'No se puede registrar una Orden de Compra. El proveedor tiene órdenes de pago pendientes. Regularizá la deuda antes de continuar.',
            icon:  'error'
        });
        return;
    }

    // ── Validar coherencia de fechas ──────────────────────────────────
    if (!validarFechas(true)) return;

    // ── Bloquear si algún ítem supera el stock máximo (cantidad = 0) ──
    if ($("#tbDetalle tbody .inp-cantidad.is-invalid").length > 0) {
        Swal.fire({
            title: 'Stock máximo alcanzado',
            text:  'Hay uno o más productos cuya cantidad es 0 porque el stock ya alcanzó el máximo permitido. Quitá esos ítems o ajustá las cantidades antes de guardar.',
            icon:  'error'
        });
        return;
    }

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
