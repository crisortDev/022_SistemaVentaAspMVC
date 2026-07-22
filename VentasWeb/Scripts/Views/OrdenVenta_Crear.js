// OrdenVenta_Crear.js  —  Pre-venta / Presupuesto
var dtCliente = null;
var dtProducto = null;
var itemsDetalle = [];
var saldoFavorCliente = 0;   // saldo a favor del cliente seleccionado

$(function () {
    iniciarTablaCliente();
    iniciarTablaProducto();
    // Datepicker vencimiento (mínimo: hoy, default: hoy)
    if ($.fn.datepicker) {
        var hoy = new Date();
        $('#txtFechaVencimiento').datepicker({
            format: 'dd/mm/yyyy', autoclose: true, language: 'es',
            startDate: hoy
        }).datepicker('setDate', hoy);
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
                        d.IdCliente + ',\'' + escapar(d.NumeroDocumento) + '\',\'' + escapar(d.Nombre) + '\',' + (d.SaldoFavor || 0) + ')">Elegir</button>';
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

function seleccionarCliente(id, doc, nombre, saldoFavor) {
    $('#hdnIdCliente').val(id);
    $('#txtDocumentoCliente').val(doc);
    $('#txtNombreCliente').val(nombre);
    $('#modalCliente').modal('hide');

    // Guardar saldo y recalcular totales con el descuento
    saldoFavorCliente = saldoFavor || 0;
    actualizarTotales();

    // Alerta informativa debajo del campo cliente
    $('#alertaSaldoFavorOV').remove();
    if (saldoFavorCliente > 0) {
        var alerta = '<div class="alert alert-success py-1 px-2 mt-1" id="alertaSaldoFavorOV" style="font-size:12px;">' +
            '<i class="fas fa-gift mr-1"></i>' +
            '<strong>Este cliente tiene Gs. ' + formatGs(saldoFavorCliente) + ' a favor por nota de crédito</strong> ' +
            '— se descuenta al facturar <strong>solo si paga al contado</strong>. Si paga en cuotas, el saldo queda para futuras compras.' +
            '</div>';
        $('#txtNombreCliente').closest('.row').after(alerta);
    }
}

function iniciarTablaProducto() {
    dtProducto = $('#tbProducto').DataTable({
        ajax: {
            url: $.MisUrls.url._Venta_ProductoStock,
            data: { soloConStock: false, idtienda: AppSession.tiendaOperativa },
            dataSrc: 'data', type: 'GET'
        },
        columns: [
            {
                data: null, orderable: false, searchable: false,
                render: function (d) {
                    var existe = itemsDetalle.some(function (x) { return x.id === d.oProducto.IdProducto; });
                    if (existe) return '<span class="badge badge-info"><i class="fas fa-check"></i></span>';
                    var precio       = (d.PrecioSugerido && d.PrecioSugerido > 0) ? d.PrecioSugerido : (d.PrecioVenta || 0);
                    var cpp          = d.CostoPromedio || 0;
                    var um           = d.UnidadMedida  || 'Unidad';
                    var descMax      = d.DescuentoMaxPermitido || 0;
                    return '<button class="btn btn-info btn-sm" onclick="agregarProducto(' +
                        d.oProducto.IdProducto + ',\'' + escapar(d.oProducto.Codigo) + '\',\'' +
                        escapar(d.oProducto.Nombre) + '\',' + precio + ',' +
                        (d.PorcentajeIva || 10) + ',' + d.Stock + ',' +
                        cpp + ',\'' + um + '\',' + descMax +
                        ')"><i class="fas fa-plus"></i></button>';
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
            {
                data: 'Stock', className: 'text-center',
                render: function (v) {
                    return v > 0
                        ? '<span class="badge badge-success"><i class="fas fa-check-circle"></i> Disponible</span>'
                        : '<span class="badge badge-danger"><i class="fas fa-times-circle"></i> No disponible</span>';
                }
            },
            { data: 'PorcentajeIva', className: 'text-center', render: function (v) { return (v || 10) + '%'; } }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish }, order: [[2, 'asc']]
    });
}

function abrirModalProductos() {
    if (dtProducto) dtProducto.ajax.reload();
    $('#modalProducto').modal('show');
}

function agregarProducto(id, codigo, nombre, precio, iva, stock, cpp, unidadMedida, descuentoMax) {
    if (itemsDetalle.some(function (x) { return x.id === id; })) { toastr.info('Ya está en el detalle.'); return; }
    if (stock <= 0) {
        toastr.warning('"' + nombre + '" no tiene stock disponible y no puede agregarse a la pre-venta.');
        return;
    }
    itemsDetalle.push({
        id: id, codigo: codigo, nombre: nombre, precio: precio, iva: iva,
        stock: stock, cantidad: 1, descuento: 0,
        cpp: cpp || 0,
        unidadMedida: unidadMedida || 'Unidad',
        descuentoMax: descuentoMax || 0
    });
    renderizarDetalle();
    if (dtProducto) dtProducto.draw(false);
}

function calcularSemaforo(item) {
    // Devuelve { clase, badge, tooltip } según análisis de margen vs CPP
    var desc       = item.descuento || 0;
    var precioEfec = item.precio * (1 - desc / 100);
    var cpp        = item.cpp || 0;
    var iva        = item.iva || 10;
    var descMax    = item.descuentoMax || 0;

    if (desc === 0) return { clase: '', badge: '', tooltip: '' };

    // Costo total incluyendo IVA (lo que pagamos + IVA al revender)
    var costoConIva = cpp > 0 ? cpp * (1 + iva / 100) : 0;

    if (costoConIva > 0 && precioEfec <= costoConIva) {
        return {
            clase: 'table-danger',
            badge: '<span class="badge badge-danger ml-1" title="¡Precio por debajo del costo! (CPP + IVA: Gs. ' + formatGs(costoConIva) + ')"><i class="fas fa-exclamation-triangle"></i> Pérdida</span>',
            tooltip: '¡Atención! Precio efectivo (Gs. ' + formatGs(precioEfec) + ') ≤ Costo (Gs. ' + formatGs(costoConIva) + '). Se vende a pérdida.'
        };
    }
    if (descMax > 0 && desc > descMax) {
        return {
            clase: 'table-warning',
            badge: '<span class="badge badge-warning ml-1" title="Descuento supera el máximo permitido (' + descMax + '%)"><i class="fas fa-exclamation-circle"></i> Límite</span>',
            tooltip: 'El descuento (' + desc + '%) supera el máximo permitido para esta categoría (' + descMax + '%).'
        };
    }
    return {
        clase: 'table-success',
        badge: '<span class="badge badge-success ml-1"><i class="fas fa-check"></i></span>',
        tooltip: ''
    };
}

function renderizarDetalle() {
    var tbody = $('#tbDetalle tbody').empty();
    itemsDetalle.forEach(function (item, idx) {
        var desc       = item.descuento || 0;
        var precioEfec = item.precio * (1 - desc / 100);
        var total      = Math.round(precioEfec * item.cantidad);
        var label      = item.unidadMedida === 'Metro' ? 'mts' : (item.unidadMedida === 'Kg' ? 'kg' : 'und.');
        var sem        = calcularSemaforo(item);

        var precioCell = '<td class="text-right">';
        if (desc > 0) {
            precioCell += '<small class="text-muted text-decoration-line-through d-block" style="font-size:10px">Gs. ' + formatGs(item.precio) + '</small>';
            precioCell += 'Gs. ' + formatGs(Math.round(precioEfec));
        } else {
            precioCell += 'Gs. ' + formatGs(item.precio);
        }
        precioCell += sem.badge + '</td>';

        tbody.append(
            '<tr class="' + sem.clase + '">' +
            '<td><button class="btn btn-danger btn-sm" onclick="quitarItem(' + idx + ')"><i class="fas fa-trash"></i></button></td>' +
            '<td>' + item.codigo + '</td>' +
            '<td>' + item.nombre + (sem.tooltip ? '<br><small class="text-danger font-weight-bold">' + sem.tooltip + '</small>' : '') + '</td>' +
            '<td class="text-center">' +
              '<input type="number" class="form-control form-control-sm text-center" style="width:70px" value="' + item.cantidad + '" min="1" ' +
              'onchange="actualizarCantidad(' + idx + ',this.value)">' +
              '<small class="text-muted">' + label + '</small>' +
            '</td>' +
            '<td class="text-center">' +
              '<div class="input-group input-group-sm" style="width:90px;margin:auto">' +
              '<input type="number" class="form-control form-control-sm text-center" value="' + desc + '" ' +
              'min="0" max="100" step="1" placeholder="0" onchange="actualizarDescuento(' + idx + ',this.value)">' +
              '<div class="input-group-append"><span class="input-group-text" style="padding:2px 4px">%</span></div>' +
              '</div>' +
            '</td>' +
            precioCell +
            '<td class="text-center">' + item.iva + '%</td>' +
            '<td class="text-right">' + formatGs(total) + '</td>' +
            '</tr>'
        );
    });
    actualizarTotales();
}

function actualizarDescuento(idx, val) {
    var desc = parseFloat(val);
    if (isNaN(desc) || desc < 0) desc = 0;
    if (desc > 100) desc = 100;
    itemsDetalle[idx].descuento = desc;
    renderizarDetalle();
}

function quitarItem(idx) { itemsDetalle.splice(idx, 1); renderizarDetalle(); if (dtProducto) dtProducto.draw(false); }

function actualizarCantidad(idx, val) {
    var cant = parseInt(val); if (isNaN(cant) || cant < 1) cant = 1;
    var stockDisp = itemsDetalle[idx].stock || 0;
    if (stockDisp > 0 && cant > stockDisp) {
        toastr.warning('La cantidad supera el stock disponible (' + stockDisp + '). Se ajustó al máximo.');
        cant = stockDisp;
    }
    itemsDetalle[idx].cantidad = cant;
    renderizarDetalle();
}

// Redondea al múltiplo de 50 superior (moneda mínima en Paraguay = 50 Gs)
function r50(n) { return Math.ceil((n || 0) / 50) * 50; }

function actualizarTotales() {
    var totalCant = 0, totalGs = 0, iva10 = 0, iva5 = 0, grav10 = 0, grav5 = 0;
    itemsDetalle.forEach(function (item) {
        var desc       = item.descuento || 0;
        var precioEfec = item.precio * (1 - desc / 100);
        var linea      = Math.round(precioEfec * item.cantidad);
        totalCant += item.cantidad;
        totalGs   += linea;
        if (item.iva == 10) { iva10 += Math.round(linea * 10 / 110); grav10 += Math.round(linea * 100 / 110); }
        else if (item.iva == 5) { iva5 += Math.round(linea * 5 / 105); }
    });

    // Redondear el total al múltiplo de 50 superior
    var totalRedondeado = r50(totalGs);

    // Saldo a favor: solo se aplica si el total >= saldo (todo o nada)
    var saldoAplicado = (saldoFavorCliente > 0 && totalRedondeado >= saldoFavorCliente)
        ? saldoFavorCliente
        : 0;
    var totalAPagar = totalRedondeado - saldoAplicado;

    $('#tfCantidad').text(totalCant);
    $('#tfTotal').text('Gs. ' + formatGs(totalRedondeado));
    $('#tfIva10').text(formatGs(iva10));
    $('#tfIva5').text(formatGs(iva5));

    if (saldoAplicado > 0) {
        $('#trSaldoFavor').removeClass('d-none');
        $('#tfSaldoAplicado').html(
            '- Gs. ' + formatGs(saldoAplicado) +
            ' <small class="text-muted font-weight-normal">(solo si paga al contado)</small>'
        );
        $('#tfTotalFinal').text('Gs. ' + formatGs(totalAPagar));
    } else {
        $('#trSaldoFavor').addClass('d-none');
        $('#tfTotalFinal').text('Gs. ' + formatGs(totalRedondeado));
        // Mostrar aviso si hay saldo pero el total no alcanza para aplicarlo al contado
        if (saldoFavorCliente > 0 && totalRedondeado < saldoFavorCliente) {
            $('#trSaldoFavor').removeClass('d-none');
            $('#tfSaldoAplicado').html(
                '<span class="text-warning"><i class="fas fa-exclamation-triangle mr-1"></i>' +
                'Necesita Gs. ' + formatGs(saldoFavorCliente - totalRedondeado) + ' más para usar el saldo por NC al contado</span>'
            );
        }
    }
}

function guardarPreVenta() {
    if (itemsDetalle.length === 0) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'Agregue al menos un producto.', confirmButtonColor: '#0984e3' });
        return;
    }
    var idCliente = parseInt($('#hdnIdCliente').val()) || 0;
    if (idCliente === 0) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'Debe seleccionar un cliente para registrar la pre-venta.', confirmButtonColor: '#0984e3' })
            .then(function () { buscarCliente(); });
        return;
    }
    var obs = $('#txtObservacion').val().trim();
    if (!obs) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'La Observación es obligatoria.', confirmButtonColor: '#0984e3' });
        $('#txtObservacion').focus(); return;
    }
    var fecVenc = $('#txtFechaVencimiento').val().trim();
    if (!fecVenc) {
        Swal.fire({ icon: 'warning', title: 'Atención', text: 'Ingrese la fecha de vencimiento.', confirmButtonColor: '#0984e3' });
        return;
    }

    ejecutarGuardadoPreVenta();
}

function ejecutarGuardadoPreVenta() {
    var fecVenc = $('#txtFechaVencimiento').val().trim();
    var xml = '<Detalle>';
    itemsDetalle.forEach(function (item) {
        xml += '<Item><IdProducto>' + item.id + '</IdProducto><Cantidad>' + item.cantidad +
               '</Cantidad><PrecioUnidad>' + item.precio + '</PrecioUnidad><IvaPorcentaje>' + item.iva +
               '</IvaPorcentaje><PorcentajeDescuento>' + (item.descuento || 0) + '</PorcentajeDescuento></Item>';
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
