// OrdenVenta_Crear.js  —  Pre-venta / Presupuesto
var dtCliente = null;
var dtProducto = null;
var itemsDetalle = [];

$(function () {
    iniciarTablaCliente();
    iniciarTablaProducto();
    // Datepicker vencimiento (mínimo: mañana)
    if ($.fn.datepicker) {
        $('#txtFechaVencimiento').datepicker({
            format: 'dd/mm/yyyy', autoclose: true, language: 'es',
            startDate: new Date(new Date().setDate(new Date().getDate() + 1))
        });
    }
});

function iniciarTablaCliente() {
    dtCliente = $('#tbCliente').DataTable({
        ajax: { url: $.MisUrls.url._Venta_ObtenerClientes, dataSrc: 'data', type: 'GET' },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    return '<button class="btn btn-info btn-sm" onclick="seleccionarCliente(' +
                        d.IdCliente + ',\'' + escapar(d.NumeroDocumento) + '\',\'' + escapar(d.Nombre) + '\')">Elegir</button>';
                }
            },
            { data: 'NumeroDocumento' },
            { data: 'Nombre' },
            { data: 'Telefono', defaultContent: '' }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }, order: [[2, 'asc']]
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
            data: { soloConStock: false, idtienda: AppSession.idTienda > 0 ? AppSession.idTienda : 1 },
            dataSrc: 'data', type: 'GET'
        },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var existe = itemsDetalle.some(function (x) { return x.id === d.oProducto.IdProducto; });
                    if (existe) return '<span class="badge badge-info"><i class="fas fa-check"></i></span>';
                    // Usar PrecioVentaSugerido (margen de categoría); fallback a PrecioVenta
                    var precio = (d.PrecioVentaSugerido && d.PrecioVentaSugerido > 0)
                        ? d.PrecioVentaSugerido : (d.PrecioVenta || 0);
                    return '<button class="btn btn-info btn-sm" onclick="agregarProducto(' +
                        d.oProducto.IdProducto + ',\'' + escapar(d.oProducto.Codigo) + '\',\'' +
                        escapar(d.oProducto.Nombre) + '\',' + precio + ',' +
                        (d.oProducto.IvaPorcentaje || 10) + ',' + d.Stock +
                        ')"><i class="fas fa-plus"></i></button>';
                }
            },
            { data: 'oProducto.Codigo', defaultContent: '' },
            { data: 'oProducto.Nombre' },
            {
                data: null, className: 'text-right',
                render: function (d) {
                    var precio = (d.PrecioVentaSugerido && d.PrecioVentaSugerido > 0)
                        ? d.PrecioVentaSugerido : (d.PrecioVenta || 0);
                    return formatGs(precio);
                }
            },
            {
                data: 'PorcentajeGananciaCategoria', className: 'text-center',
                render: function (v) { return (v || 0) + '%'; }
            },
            { data: 'Stock', className: 'text-center' },
            { data: 'oProducto.IvaPorcentaje', className: 'text-center', render: function (v) { return v + '%'; } }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }, order: [[2, 'asc']]
    });
}

function abrirModalProductos() {
    if (dtProducto) dtProducto.ajax.reload();
    $('#modalProducto').modal('show');
}

function agregarProducto(id, codigo, nombre, precio, iva, stock) {
    if (itemsDetalle.some(function (x) { return x.id === id; })) { toastr.info('Ya está en el detalle.'); return; }
    itemsDetalle.push({ id: id, codigo: codigo, nombre: nombre, precio: precio, iva: iva, stock: stock, cantidad: 1 });
    renderizarDetalle();
    if (dtProducto) dtProducto.draw(false);
}

function renderizarDetalle() {
    var tbody = $('#tbDetalle tbody').empty();
    itemsDetalle.forEach(function (item, idx) {
        var total = item.precio * item.cantidad;
        tbody.append('<tr>' +
            '<td><button class="btn btn-danger btn-sm" onclick="quitarItem(' + idx + ')"><i class="fas fa-trash"></i></button></td>' +
            '<td>' + item.codigo + '</td><td>' + item.nombre + '</td>' +
            '<td class="text-center"><input type="number" class="form-control form-control-sm text-center" style="width:70px" value="' + item.cantidad + '" min="1" onchange="actualizarCantidad(' + idx + ',this.value)"></td>' +
            '<td class="text-right">' + formatGs(item.precio) + '</td>' +
            '<td class="text-center">' + item.iva + '%</td>' +
            '<td class="text-right">' + formatGs(total) + '</td></tr>');
    });
    actualizarTotales();
}

function quitarItem(idx) { itemsDetalle.splice(idx, 1); renderizarDetalle(); if (dtProducto) dtProducto.draw(false); }

function actualizarCantidad(idx, val) {
    var cant = parseInt(val); if (isNaN(cant) || cant < 1) cant = 1;
    itemsDetalle[idx].cantidad = cant;
    renderizarDetalle();
}

function actualizarTotales() {
    var totalCant = 0, totalGs = 0, iva10 = 0, iva5 = 0, grav10 = 0, grav5 = 0;
    itemsDetalle.forEach(function (item) {
        var linea = item.precio * item.cantidad; totalCant += item.cantidad; totalGs += linea;
        if (item.iva == 10) { iva10 += Math.round(linea * 10 / 110); grav10 += Math.round(linea * 100 / 110); }
        else if (item.iva == 5) { iva5 += Math.round(linea * 5 / 105); }
    });
    $('#tfCantidad').text(totalCant);
    $('#tfTotal').text('Gs. ' + formatGs(totalGs));
    $('#tfIva10').text(formatGs(iva10));
    $('#tfIva5').text(formatGs(iva5));
    $('#tfTotalFinal').text('Gs. ' + formatGs(totalGs));
}

function guardarPreVenta() {
    if (itemsDetalle.length === 0) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'Agregue al menos un producto.', confirmButtonColor: '#0984e3' });
        return;
    }
    var fecVenc = $('#txtFechaVencimiento').val().trim();
    if (!fecVenc) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'Ingrese la fecha de vencimiento.', confirmButtonColor: '#0984e3' });
        return;
    }

    var xml = '<Detalle>';
    itemsDetalle.forEach(function (item) {
        xml += '<Item><IdProducto>' + item.id + '</IdProducto><Cantidad>' + item.cantidad +
               '</Cantidad><PrecioUnidad>' + item.precio + '</PrecioUnidad><IvaPorcentaje>' + item.iva + '</IvaPorcentaje></Item>';
    });
    xml += '</Detalle>';

    $('#btnGuardar').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Guardando...');

    $.ajax({
        url: $.MisUrls.url._OV_Guardar,
        method: 'POST',
        data: { idCliente: parseInt($('#hdnIdCliente').val()) || 0, observacion: $('#txtObservacion').val(), fechaVencimiento: fecVenc, detalleXml: xml },
        success: function (r) {
            if (r.resultado) {
                Swal.fire({ icon: 'success', title: '¡Guardado!', text: r.mensaje || 'Pre-venta registrada correctamente.', confirmButtonColor: '#0984e3', timer: 1500, showConfirmButton: false });
                setTimeout(function () { window.location.href = $.MisUrls.url._OV_Consultar; }, 1600);
            } else {
                Swal.fire({ icon: 'error', title: 'Error', text: r.mensaje || 'Error al guardar.', confirmButtonColor: '#0984e3' });
                $('#btnGuardar').prop('disabled', false).html('<i class="fas fa-save"></i> Guardar Pre-venta');
            }
        },
        error: function (xhr) {
            var msg = 'Error de conexión al servidor.';
            try { var j = JSON.parse(xhr.responseText); if (j && j.mensaje) msg = j.mensaje; } catch(e) {}
            Swal.fire({ icon: 'error', title: 'Error ' + xhr.status, text: msg, confirmButtonColor: '#0984e3' });
            $('#btnGuardar').prop('disabled', false).html('<i class="fas fa-save"></i> Guardar Pre-venta');
        }
    });
}

function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s) { return (s || '').replace(/'/g, "\\'"); }
