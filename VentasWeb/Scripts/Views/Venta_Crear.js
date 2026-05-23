// ============================================================
//  Venta_Crear.js  —  Venta Directa
// ============================================================

var dtCliente = null;
var dtProducto = null;
var itemsDetalle = [];

$(function () {
    cargarFormasCobro();
    iniciarTablaCliente();
    iniciarTablaProducto();
});

function cargarFormasCobro() {
    $.get($.MisUrls.url._Venta_FormasCobro, function (r) {
        if (r && r.data) {
            r.data.forEach(function (f) {
                $('#cboFormaCobro').append($('<option>', { value: f.IdFormaCobro, text: f.Nombre }));
            });
            // Seleccionar "Efectivo" por defecto
            $('#cboFormaCobro option').filter(function () {
                return $(this).text().trim().toLowerCase() === 'efectivo';
            }).prop('selected', true);
        }
    });
}

function iniciarTablaCliente() {
    dtCliente = $('#tbCliente').DataTable({
        ajax: { url: $.MisUrls.url._Venta_ObtenerClientes, dataSrc: 'data', type: 'GET' },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    return '<button class="btn btn-success btn-sm" onclick="seleccionarCliente(' +
                        d.IdCliente + ',\'' + escapar(d.NumeroDocumento) + '\',\'' + escapar(d.Nombre) + '\')">Elegir</button>';
                }
            },
            { data: 'NumeroDocumento' },
            { data: 'Nombre' },
            { data: 'Telefono', defaultContent: '' }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[2, 'asc']]
    });
}

function buscarCliente() {
    if (dtCliente) dtCliente.ajax.reload();
    $('#modalCliente').modal('show');
}

function seleccionarCliente(id, doc, nombre) {
    $('#hdnIdCliente').val(id);
    $('#txtDocumentoCliente').val(doc);
    $('#txtNombreCliente').val(nombre);
    $('#modalCliente').modal('hide');
}

function iniciarTablaProducto() {
    dtProducto = $('#tbProducto').DataTable({
        ajax: {
            url: $.MisUrls.url._Venta_ProductoStock,
            data: { soloConStock: true, idtienda: AppSession.tiendaOperativa },
            dataSrc: 'data', type: 'GET'
        },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var existe = itemsDetalle.some(function (x) { return x.id === d.oProducto.IdProducto; });
                    if (existe) return '<span class="badge badge-success"><i class="fas fa-check"></i> Agregado</span>';
                    // Usar PrecioSugerido (margen de categoría); fallback a PrecioVenta si no está disponible
                    var precio = (d.PrecioSugerido && d.PrecioSugerido > 0)
                        ? d.PrecioSugerido : (d.PrecioVenta || 0);
                    return '<button class="btn btn-info btn-sm" onclick="agregarProducto(' +
                        d.oProducto.IdProducto + ',\'' + escapar(d.oProducto.Codigo) + '\',\'' +
                        escapar(d.oProducto.Nombre) + '\',' + precio + ',' +
                        (d.PorcentajeIva || 10) + ',' + d.Stock +
                        ')"><i class="fas fa-plus"></i> Agregar</button>';
                }
            },
            { data: 'oProducto.Codigo', defaultContent: '' },
            { data: 'oProducto.Nombre' },
            {
                data: null, className: 'text-right',
                render: function (d) {
                    var precio = (d.PrecioSugerido && d.PrecioSugerido > 0)
                        ? d.PrecioSugerido : (d.PrecioVenta || 0);
                    return formatGs(precio);
                }
            },
            {
                data: 'MargenCategoria', className: 'text-center',
                render: function (v) { return (v || 0) + '%'; }
            },
            { data: 'Stock', className: 'text-center' },
            { data: 'PorcentajeIva', className: 'text-center', render: function (v) { return (v || 10) + '%'; } }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[2, 'asc']]
    });
}

function abrirModalProductos() {
    if (dtProducto) dtProducto.ajax.reload();
    $('#modalProducto').modal('show');
}

function agregarProducto(id, codigo, nombre, precio, iva, stock) {
    if (itemsDetalle.some(function (x) { return x.id === id; })) {
        toastr.info('El producto ya está en el detalle.');
        return;
    }
    itemsDetalle.push({ id: id, codigo: codigo, nombre: nombre, precio: precio, iva: iva, stock: stock, cantidad: 1 });
    renderizarDetalle();
    if (dtProducto) dtProducto.draw(false);
}

function renderizarDetalle() {
    var tbody = $('#tbDetalle tbody').empty();
    itemsDetalle.forEach(function (item, idx) {
        var total = item.precio * item.cantidad;
        var fila = '<tr>' +
            '<td><button class="btn btn-danger btn-sm" onclick="quitarItem(' + idx + ')"><i class="fas fa-trash"></i></button></td>' +
            '<td>' + item.codigo + '</td>' +
            '<td>' + item.nombre + '</td>' +
            '<td class="text-center">' + item.stock + '</td>' +
            '<td class="text-center"><input type="number" class="form-control form-control-sm text-center" style="width:70px" value="' + item.cantidad + '" min="1" max="' + item.stock + '" onchange="actualizarCantidad(' + idx + ',this.value)"></td>' +
            '<td class="text-right">' + formatGs(item.precio) + '</td>' +
            '<td class="text-center">' + item.iva + '%</td>' +
            '<td class="text-right">' + formatGs(total) + '</td>' +
            '</tr>';
        tbody.append(fila);
    });
    actualizarTotales();
}

function quitarItem(idx) {
    itemsDetalle.splice(idx, 1);
    renderizarDetalle();
    if (dtProducto) dtProducto.draw(false);
}

function actualizarCantidad(idx, val) {
    var cant = parseInt(val);
    if (isNaN(cant) || cant < 1) cant = 1;
    if (cant > itemsDetalle[idx].stock) {
        toastr.warning('Cantidad excede el stock disponible (' + itemsDetalle[idx].stock + ').');
        cant = itemsDetalle[idx].stock;
    }
    itemsDetalle[idx].cantidad = cant;
    renderizarDetalle();
}

function actualizarTotales() {
    var totalCant = 0, totalGs = 0, iva10 = 0, iva5 = 0, exento = 0, grav10 = 0, grav5 = 0;
    itemsDetalle.forEach(function (item) {
        var linea = item.precio * item.cantidad;
        totalCant += item.cantidad;
        totalGs += linea;
        if (item.iva == 10) {
            iva10 += Math.round(linea * 10 / 110);
            grav10 += Math.round(linea * 100 / 110);
        } else if (item.iva == 5) {
            iva5 += Math.round(linea * 5 / 105);
            grav5 += Math.round(linea * 100 / 105);
        } else {
            exento += linea;
        }
    });
    $('#tfCantidad').text(totalCant);
    $('#tfTotal').text('Gs. ' + formatGs(totalGs));
    $('#tfGravado10').text(formatGs(grav10));
    $('#tfIva10').text(formatGs(iva10));
    $('#tfGravado5').text(formatGs(grav5));
    $('#tfIva5').text(formatGs(iva5));
    $('#tfExento').text(formatGs(exento));
    $('#tfTotalFinal').text('Gs. ' + formatGs(totalGs));
    calcularCambio();
}

function calcularCambio() {
    var total = calcularTotal();
    var recibido = parseFloat($('#txtImporteRecibido').val()) || 0;
    var cambio = recibido - total;
    $('#txtCambio').val(formatGs(Math.max(0, cambio)));
    if (recibido > 0 && recibido < total) {
        $('#txtCambio').addClass('text-danger').removeClass('text-success');
        $('#lblValidacion').text('⚠ Importe recibido insuficiente.').addClass('text-danger');
    } else {
        $('#txtCambio').removeClass('text-danger').addClass('text-success');
        $('#lblValidacion').text('');
    }
}

function calcularTotal() {
    var t = 0;
    itemsDetalle.forEach(function (i) { t += i.precio * i.cantidad; });
    return t;
}

function guardarVenta() {
    if (itemsDetalle.length === 0) { toastr.warning('Agregue al menos un producto.'); return; }
    var formaCobro = parseInt($('#cboFormaCobro').val());
    if (!formaCobro) { toastr.warning('Seleccione la forma de cobro.'); return; }
    var recibido = parseFloat($('#txtImporteRecibido').val()) || 0;
    var total = calcularTotal();
    if (recibido < total) { toastr.warning('El importe recibido es menor al total (' + formatGs(total) + ' Gs.).'); return; }

    var xml = '<Detalle>';
    itemsDetalle.forEach(function (item) {
        xml += '<Item><IdProducto>' + item.id + '</IdProducto><Cantidad>' + item.cantidad +
               '</Cantidad><PrecioUnidad>' + item.precio + '</PrecioUnidad><IvaPorcentaje>' + item.iva + '</IvaPorcentaje></Item>';
    });
    xml += '</Detalle>';

    $('#btnGuardar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Procesando...');

    $.ajax({
        url: $.MisUrls.url._Venta_GuardarDirecta,
        method: 'POST',
        data: { idCliente: parseInt($('#hdnIdCliente').val()) || 0, idFormaCobro: formaCobro, importeRecibido: recibido, detalleXml: xml },
        success: function (r) {
            if (r.resultado) {
                toastr.success('Venta registrada! Factura: ' + r.numeroFactura);
                setTimeout(function () { window.open(r.urlDocumento, '_blank'); }, 800);
                resetForm();
            } else {
                toastr.error(r.mensaje || 'Error al registrar la venta.');
            }
        },
        error: function () { toastr.error('Error de conexión.'); },
        complete: function () {
            $('#btnGuardar').prop('disabled', false).html('<i class="fas fa-cash-register"></i> Cobrar y Facturar');
        }
    });
}

function resetForm() {
    itemsDetalle = [];
    renderizarDetalle();
    $('#hdnIdCliente').val(0);
    $('#txtDocumentoCliente,#txtNombreCliente').val('');
    $('#txtImporteRecibido').val(0);
    $('#txtCambio').val(0);
    $('#cboFormaCobro').val(0);
    $('#lblValidacion').text('');
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s) { return (s || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'"); }
