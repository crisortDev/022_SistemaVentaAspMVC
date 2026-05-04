var tablaproveedor;
var tablatienda;
var tablaproducto;
var tablaordencompra;

// ═══════════════════════════════════════════════════════
//  UTILIDADES
// ═══════════════════════════════════════════════════════

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

// Extensión jQuery para inputFilter (previene entrada inválida)
$.fn.inputFilter = function (inputFilter) {
    return this.on("input keydown keyup mousedown mouseup select contextmenu drop", function () {
        if (inputFilter(this.value)) {
            this.oldValue = this.value;
            this.oldSelectionStart = this.selectionStart;
            this.oldSelectionEnd = this.selectionEnd;
        } else if (this.hasOwnProperty("oldValue")) {
            this.value = this.oldValue;
            this.setSelectionRange(this.oldSelectionStart, this.oldSelectionEnd);
        } else {
            this.value = "";
        }
    });
};

$(document).ready(function () {
    activarMenu("Compras");
    inicializarDataTables();

    // ── Controlar sección tienda según rol ────────────────
    if (!AppSession.esSuperAdmin) {
        // Ocultar botón buscar tienda — el usuario no puede cambiarla
        $("#divBtnBuscarTienda").hide();

        // Cargar automáticamente la tienda del usuario
        cargarTiendaAutomatica(AppSession.idTienda);
    }

    $(document).on('click', '#tbCompra tbody button.btn-danger', function () {
        $(this).closest('tr').remove();
        actualizarTotalesCompra();
    });
});

// Carga automática de tienda para usuarios no SuperAdmin
function cargarTiendaAutomatica(idTienda) {
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        success: function (data) {
            if (data && data.data) {
                var tienda = data.data.find(function (t) { return t.IdTienda == idTienda; });
                if (tienda) {
                    $("#txtIdTienda").val(tienda.IdTienda);
                    $("#txtRucTienda").val(tienda.RUC);
                    $("#txtNombreTienda").val(tienda.Nombre);
                    actualizarProductosPorTienda(tienda.IdTienda);
                }
            }
        }
    });
}

// Delegación del evento para seleccionar proveedor desde el modal
$(document).on('click', '.seleccionar-proveedor', function () {
    const id = $(this).data('id');
    const ruc = $(this).data('ruc');
    const razon = $(this).data('razon');

    $("#txtIdProveedor").val(id);
    $("#txtRucProveedor").val(ruc);
    $("#txtRazonSocialProveedor").val(razon);
    $('#modalProveedor').modal('hide');
});

function inicializarDataTables() {
    // DataTable Proveedores
    tablaproveedor = $('#tbProveedor').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProveedores,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `
                <button class="btn btn-sm btn-primary seleccionar-proveedor"
                        data-id="${row.IdProveedor}"
                        data-ruc="${row.Ruc}"
                        data-razon="${row.RazonSocial}">
                    <i class="fas fa-check"></i>
                </button>`;
                },
                "orderable": false,
                "searchable": false,
                "width": "60px"
            },
            { "data": "Ruc" },
            { "data": "RazonSocial" },
            { "data": "Direccion" }
        ],
        "language": lenguajeDataTable()
    });

    // DataTable Órdenes de Compra (Aprobadas)
    tablaordencompra = $('#tbOrdenCompra').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerOrdenesCompraAprobadas,
            "type": "GET",
            "datatype": "json",
            "data": function (d) {
                // Filtrar por proveedor seleccionado
                d.idproveedor = $("#txtIdProveedor").val() || 0;
            }
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `
                <button class="btn btn-sm btn-success seleccionar-ordencompra"
                        data-id="${row.IdOrdenCompra}"
                        data-numero="${row.NumeroOrden}"
                        data-estado="${row.Estado}"
                        data-observacion="${row.Observacion || ''}"
                        data-detalle="${JSON.stringify(row).replace(/"/g, '&quot;')}">
                    <i class="fas fa-check"></i>
                </button>`;
                },
                "orderable": false,
                "searchable": false,
                "width": "60px"
            },
            { "data": "NumeroOrden" },
            { "data": "oProveedor", "render": function (data) { return data ? data.RazonSocial : ""; } },
            { "data": "oTienda", "render": function (data) { return data ? data.Nombre : ""; } },
            { "data": "FechaOrden" },
            { "data": "TotalEstimado", "render": function (data) { return formatearMonedaGs(Math.round(data)); } },
            { "data": "Estado" }
        ],
        "language": lenguajeDataTable()
    });

    // Evento para seleccionar Orden de Compra
    $(document).on('click', '.seleccionar-ordencompra', function () {
        const id = $(this).data('id');
        const numero = $(this).data('numero');
        const estado = $(this).data('estado');
        const observacion = $(this).data('observacion');

        $("#txtIdOrdenCompra").val(id);
        $("#txtNumeroOrden").val(numero);
        $("#txtEstadoOrden").val(estado);
        $("#txtObservacionOrden").val(observacion);

        // 🆕 CARGAR AUTOMÁTICAMENTE LOS PRODUCTOS DE LA ORDEN
        cargarProductosDeOrdenCompra(id);

        $('#modalOrdenCompra').modal('hide');
    });

    // DataTable Tiendas — solo inicializa si es SuperAdmin
    if (AppSession.esSuperAdmin) {
        tablatienda = $('#tbTienda').DataTable({
            "ajax": {
                "url": $.MisUrls.url._ObtenerTiendas,
                "type": "GET",
                "datatype": "json"
            },
            "columns": [
                {
                    "data": null,
                    "render": function (data, type, row) {
                        return `
                        <button class="btn btn-sm btn-primary seleccionar-tienda"
                                data-id="${row.IdTienda}"
                                data-ruc="${row.RUC}"
                                data-nombre="${row.Nombre}">
                            <i class="fas fa-check"></i>
                        </button>`;
                    },
                    "orderable": false,
                    "searchable": false,
                    "width": "60px"
                },
                { "data": "RUC" },
                { "data": "Nombre" },
                {
                    "data": "Direccion",
                    "render": function (data) { return data; }
                }
            ],
            "language": lenguajeDataTable()
        });

        $(document).on('click', '.seleccionar-tienda', function () {
            const id = $(this).data('id');
            const ruc = $(this).data('ruc');
            const nombre = $(this).data('nombre');

            $("#txtIdTienda").val(id);
            $("#txtRucTienda").val(ruc);
            $("#txtNombreTienda").val(nombre);
            actualizarProductosPorTienda(id);
            $('#modalTienda').modal('hide');
        });
    }

    $(document).on('click', '.seleccionar-producto', function () {
        const id = $(this).data('id');
        const codigo = $(this).data('codigo');
        const nombre = $(this).data('nombre');

        $("#txtIdProducto").val(id);
        $("#txtCodigoProducto").val(codigo);
        $("#txtNombreProducto").val(nombre);
        cargarHistorialPrecioCompra(id);
        $('#modalProducto').modal('hide');
    });

    // DataTable Productos
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": `${$.MisUrls.url._ObtenerProductosPorTienda}?IdTienda=0`,
            "type": "GET",
            "datatype": "json",
            "dataSrc": function(json) {
                // Manejar respuestas en diferentes formatos
                if (json && json.data) {
                    return json.data;
                } else if (Array.isArray(json)) {
                    return json;
                } else {
                    console.warn("Formato de respuesta inesperado:", json);
                    return [];
                }
            },
            "error": function(xhr, status, error) {
                console.error("Error al cargar productos:", error, xhr);
            }
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `
                <button class="btn btn-sm btn-primary seleccionar-producto"
                        data-id="${row.IdProducto}"
                        data-codigo="${row.Codigo}"
                        data-nombre="${row.Nombre}"
                        data-iva="${row.IvaPorcentaje || 10}">
                    <i class="fas fa-check"></i>
                </button>`;
                },
                "orderable": false,
                "searchable": false,
                "width": "60px"
            },
            { "data": "Codigo" },
            { "data": "Nombre" },
            { "data": "Descripcion" },
            {
                "data": "oCategoria",
                "render": data => data?.Descripcion || ""
            }
        ],
        "language": lenguajeDataTable()
    });

    // Evento seleccionar producto
    $(document).on('click', '.seleccionar-producto', function () {
        const id = $(this).data('id');
        const codigo = $(this).data('codigo');
        const nombre = $(this).data('nombre');
        const iva = $(this).data('iva') || 10;

        $("#txtIdProducto").val(id);
        $("#txtCodigoProducto").val(codigo);
        $("#txtNombreProducto").val(nombre);
        $("#txtIvaPorcentaje").val(iva);
        $("#txtCantidadProducto").val("0");
        $("#txtPrecioCompraProducto").val("0");
        $("#txtPrecioCompraConIva").val("0");

        calcularPrecioConIva();
        $('#modalProducto').modal('hide');
    });

    function calcularPrecioConIva() {
        const precioCompra = parseFloat($("#txtPrecioCompraProducto").val()) || 0;
        const iva = parseFloat($("#txtIvaPorcentaje").val()) || 0;
        const precioConIva = precioCompra * (1 + (iva / 100));
        $("#txtPrecioCompraConIva").val(formatearMonedaGs(Math.round(precioConIva)));
    }

    $("#txtPrecioCompraProducto, #txtIvaPorcentaje").on("input", function () {
        calcularPrecioConIva();
    });

    configurarFiltrosEntrada();
}

function configurarFiltrosEntrada() {
    $("#txtCantidadProducto").inputFilter(value => /^\d*$/.test(value));
    $("#txtPrecioCompraProducto").inputFilter(value => /^\d*[.]?\d{0,2}$/.test(value));
    $("#txtIvaPorcentaje").inputFilter(value => /^\d{0,2}([.]\d{0,2})?$/.test(value));

    $("#txtPrecioCompraProducto, #txtIvaPorcentaje").on("input", function () {
        calcularPrecioConIva();
    });

    $("#txtCodigoProducto").on('keypress', async function (e) {
        if (e.which === 13) await buscarProductoPorCodigo();
    });
}

function calcularPrecioConIva() {
    const precioCompra = parseFloat($("#txtPrecioCompraProducto").val()) || 0;
    const iva = parseFloat($("#txtIvaPorcentaje").val()) || 0;
    const precioConIva = precioCompra * (1 + (iva / 100));
    $("#txtPrecioCompraConIva").val(formatearMonedaGs(Math.round(precioConIva)));
}

async function buscarProductoPorCodigo() {
    try {
        const codigo = $("#txtCodigoProducto").val().trim();
        if (!codigo) return;

        const response = await $.ajax({
            url: `${$.MisUrls.url._ObtenerProductoPorCodigo}/${codigo}`,
            type: "GET"
        });

        if (response.resultado && response.data) {
            const producto = response.data;
            $("#txtIdProducto").val(producto.IdProducto);
            $("#txtNombreProducto").val(producto.Nombre);
            cargarHistorialPrecioCompra(producto.IdProducto);
        } else {
            limpiarCamposProducto();
            mostrarError("Producto no encontrado");
        }
    } catch (error) {
        limpiarCamposProducto();
        mostrarError("Error al buscar producto");
    }
}

function limpiarCamposProducto() {
    $("#txtIdProducto").val("0");
    $("#txtCodigoProducto").val("");
    $("#txtNombreProducto").val("");
    $("#txtCantidadProducto").val("0");
    $("#txtPrecioCompraProducto").val("0");
    $("#txtPrecioCompraConIva").val("");
    $("#txtIvaPorcentaje").val("10");
    $("#txtPrecioVentaProducto").val("0");
}

function proveedorSelect(proveedor) {
    $("#txtIdProveedor").val(proveedor.IdProveedor);
    $("#txtRucProveedor").val(proveedor.Ruc);
    $("#txtRazonSocialProveedor").val(proveedor.RazonSocial);
    $('#modalProveedor').modal('hide');
}

function tiendaSelect(tienda) {
    $("#txtIdTienda").val(tienda.IdTienda);
    $("#txtRucTienda").val(tienda.RUC);
    $("#txtNombreTienda").val(tienda.Nombre);
    actualizarProductosPorTienda(tienda.IdTienda);
    $('#modalTienda').modal('hide');
}

function productoSelect(producto) {
    $("#txtIdProducto").val(producto.IdProducto);
    $("#txtCodigoProducto").val(producto.Codigo);
    $("#txtNombreProducto").val(producto.Nombre);
    cargarHistorialPrecioCompra(producto.IdProducto);
    $('#modalProducto').modal('hide');
}

function actualizarProductosPorTienda(idTienda) {
    tablaproducto.ajax.url(
        `${$.MisUrls.url._ObtenerProductosPorTienda}?IdTienda=${idTienda}`
    ).load();
}

// 🆕 NUEVA LÓGICA: Productos cargados automáticamente desde Orden de Compra
// (Ver funciones al final del archivo)

// 🆕 EVENTO: Rehabilitar Tienda cuando se limpia la OC
$(document).on('change', '#txtIdOrdenCompra', function() {
    if (!$(this).val()) {
        // Si se vacía la OC, habilitar nuevamente la Tienda
        $("#txtIdTienda").val("").prop('disabled', false);
        console.log('✅ Tienda rehabilitada (OC vacía)');
    }
});

$('#btnTerminarGuardarCompra').on('click', guardarCompra);

async function guardarCompra() {
    if (!validarListaProductos()) return;

    try {
        const xmlData = construirXMLCompra();

        // ── LOG DE DIAGNÓSTICO ────────────────────────────────
        console.log('=== DIAGNÓSTICO DE COMPRA ===');
        console.log('IdOrdenCompra en campo:', $("#txtIdOrdenCompra").val());
        console.log('NumeroOrden en campo:', $("#txtNumeroOrden").val());
        console.log('XML completo:', xmlData);
        console.log('==============================');
        // ──────────────────────────────────────────────────────

        const response = await enviarCompraAlServidor(xmlData);

        if (response.resultado) {
            mostrarExito("Compra registrada exitosamente");
            setTimeout(() => { location.reload(); }, 1000);
        } else {
            manejarErrorServidor(response);
        }
    } catch (error) {
        console.error("Error guardando compra:", error);
        mostrarError("Error al procesar la compra");
    }
}

// 🆕 VALIDAR LISTA DE PRODUCTOS DESDE TABLA tbProductosOrden
function validarListaProductos() {
    let hayCantidades = false;

    $("#tbProductosOrdenBody tr").each(function () {
        const cantidad = parseInt($(this).find('.cantidad-facturar').val()) || 0;
        if (cantidad > 0) {
            hayCantidades = true;
            return false; // break
        }
    });

    if (!hayCantidades) {
        mostrarError("Debe ingresar la cantidad a facturar para al menos un producto.");
        return false;
    }
    return true;
}

// 🆕 CONSTRUIR XML DESDE TABLA tbProductosOrden
function construirXMLCompra() {
    let totalCosto = 0;
    let detalleXML = "";

    // Iterar sobre la tabla de productos de la orden
    $("#tbProductosOrdenBody tr").each(function () {
        const $row = $(this);
        const idDetalleOrdenCompra = $row.data('id-detalle');
        const idProducto = parseInt($row.find('.cantidad-facturar').data('id-producto')) || 0;
        const cantidad = parseInt($row.find('.cantidad-facturar').val()) || 0;
        const precio = parseFloat($row.find('.cantidad-facturar').data('precio'));
        const iva = parseFloat($row.find('.cantidad-facturar').data('iva'));

        // Saltar si no hay cantidad
        if (cantidad === 0) return;

        // Validación defensiva: nunca enviar undefined/0 como IdProducto
        if (!idProducto || idProducto <= 0) {
            console.error("Fila sin IdProducto válido:", $row);
            throw new Error("Hay productos sin identificador. Recargue la orden de compra.");
        }

        const totalSinIva = cantidad * precio;
        const totalConIva = totalSinIva * (1 + iva / 100);

        totalCosto += totalSinIva;

        detalleXML += `
            <DETALLE>
                <IdDetalleOrdenCompra>${idDetalleOrdenCompra}</IdDetalleOrdenCompra>
                <IdProducto>${idProducto}</IdProducto>
                <Cantidad>${cantidad}</Cantidad>
                <PrecioUnitarioCompra>${precio}</PrecioUnitarioCompra>
                <PrecioUnitarioCompraConIva>${Math.round(totalConIva / cantidad)}</PrecioUnitarioCompraConIva>
                <PrecioUnitarioVenta>0</PrecioUnitarioVenta>
                <TotalCosto>${totalSinIva}</TotalCosto>
            </DETALLE>`;
    });

    return `
        <DETALLE>
            <COMPRA>
                <IdUsuario>${obtenerIdUsuario()}</IdUsuario>
                <IdProveedor>${$("#txtIdProveedor").val()}</IdProveedor>
                <IdOrdenCompra>${$("#txtIdOrdenCompra").val()}</IdOrdenCompra>
                <IdTienda>${$("#txtIdTienda").val()}</IdTienda>
                <NumeroFactura>${$("#txtNumeroFactura").val()}</NumeroFactura>
                <NumeroTimbrado>${$("#txtNumeroTimbrado").val()}</NumeroTimbrado>
                <FechaVencimientoTimbrado>${$("#txtFechaVencimientoTimbrado").val()}</FechaVencimientoTimbrado>
                <TotalCosto>${totalCosto}</TotalCosto>
            </COMPRA>
            <DETALLE_COMPRA>
                ${detalleXML}
            </DETALLE_COMPRA>
        </DETALLE>`;
}

function obtenerIdUsuario() {
    return $("#hdnIdUsuario").val();
}

async function enviarCompraAlServidor(xmlData) {
    return await $.ajax({
        url: $.MisUrls.url._GuardarCompra,
        type: "POST",
        data: JSON.stringify({ xml: xmlData }),
        dataType: "json",
        contentType: "application/json"
    });
}

function manejarErrorServidor(response) {
    mostrarError(response.error || "Error desconocido al guardar la compra");
}

function mostrarError(mensaje) {
    Swal.fire({
        title: "Error",
        text: mensaje,
        icon: "error"
    });
}

function mostrarExito(mensaje) {
    Swal.fire({
        title: "Éxito",
        text: mensaje,
        icon: "success"
    });
}

function cargarHistorialPrecioCompra(idProducto) {
    $.ajax({
        url: `${$.MisUrls.url._ObtenerHistorialPrecio}?idproducto=${idProducto}`,
        type: "GET",
        success: function (data) {
            const tbody = $("#tbHistorialPrecio tbody").empty();
            if (data.data && data.data.length > 0) {
                data.data.forEach(item => {
                    tbody.append(`
                        <tr>
                            <td>${formatearFecha(item.FechaRegistro)}</td>
                            <td>${item.PrecioCompra.toLocaleString("es-PY")} Gs.</td>
                            <td>${item.Observaciones || ''}</td>
                        </tr>
                    `);
                });
            }
        }
    });
}

function formatearFecha(fechaISO) {
    return new Date(fechaISO).toLocaleDateString('es-PY');
}

$(function () {
    $('[data-toggle="tooltip"]').tooltip();
});

function buscarProveedor() {
    $('#modalProveedor').modal('show');
    tablaproveedor.ajax.reload();
}

function buscarTienda() {
    // Solo SuperAdmin puede abrir este modal
    if (!AppSession.esSuperAdmin) return;
    $('#modalTienda').modal('show');
    tablatienda.ajax.reload();
}

function buscarProducto() {
    $('#modalProducto').modal('show');
    tablaproducto.ajax.reload();
}

function buscarOrdenCompra() {
    if ($("#txtIdProveedor").val() === "0" || !$("#txtIdProveedor").val()) {
        mostrarError("Debe seleccionar un proveedor primero");
        return;
    }
    $('#modalOrdenCompra').modal('show');
    tablaordencompra.ajax.reload();
}

function buscarProductoEnLista() {
    const idProductoActual = $("#txtIdProducto").val();
    let encontrado = false;

    $("#tbCompra tbody tr").each(function () {
        const idEnTabla = $(this).find("td.codigoproducto").data("idproducto");
        if (idProductoActual && idProductoActual === idEnTabla.toString()) {
            encontrado = true;
            return false;
        }
    });

    return encontrado;
}

function parseMonedaGs(valor) {
    if (!valor) return 0;
    return parseInt(valor.toString().replace(/\./g, ''), 10) || 0;
}

function formatearMonedaGs(valor) {
    if (isNaN(valor)) return "0";
    return valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

function actualizarTotalesCompra() {
    let totalCantidad = 0;
    let totalPrecioUnidadCompra = 0;
    let totalPrecioTotalCompra = 0;
    let totalPrecioTotalCompraIVA = 0;

    $("#tbCompra tbody tr").each(function () {
        const $tds = $(this).find('td');
        let cantidad = parseFloat($tds.eq(3).text()) || 0;
        let precioUnidad = parseMonedaGs($tds.eq(4).text());
        let totalSinIva = parseMonedaGs($tds.eq(5).text());
        let totalConIva = parseMonedaGs($tds.eq(6).text());

        totalCantidad += cantidad;
        totalPrecioUnidadCompra += precioUnidad;
        totalPrecioTotalCompra += totalSinIva;
        totalPrecioTotalCompraIVA += totalConIva;
    });

    $("#totalCantidad").text(totalCantidad);
    $("#totalPrecioUnidadCompra").text(formatearMonedaGs(Math.round(totalPrecioUnidadCompra)));
    $("#totalPrecioTotalCompra").text(formatearMonedaGs(Math.round(totalPrecioTotalCompra)));
    $("#totalPrecioTotalCompraIVA").text(formatearMonedaGs(Math.round(totalPrecioTotalCompraIVA)));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  🆕 NUEVAS FUNCIONES PARA AUTO-CARGA DE PRODUCTOS DESDE ORDEN DE COMPRA
// ═══════════════════════════════════════════════════════════════════════════════

async function cargarProductosDeOrdenCompra(idOrdenCompra) {
    try {
        const response = await $.ajax({
            url: `${$.MisUrls.url._ObtenerDetalleOrdenCompra}?idordencompra=${idOrdenCompra}`,
            type: "GET",
            dataType: "json"
        });

        if (response.resultado && response.data) {
            const oc = response.data;

            // 🆕 AUTO-LLENAR Y DESHABILITAR LA TIENDA DESDE LA OC
            if (oc.oTienda && oc.oTienda.IdTienda) {
                $("#txtIdTienda").val(oc.oTienda.IdTienda);
                $("#txtRucTienda").val(oc.oTienda.RUC);
                $("#txtNombreTienda").val(oc.oTienda.Nombre);
                $("#txtIdTienda").prop('disabled', true);
                console.log(`✅ Tienda auto-llenada: ${oc.oTienda.IdTienda} - ${oc.oTienda.Nombre} (desde OC)`);
            }

            // Limpiar tabla anterior
            $("#tbProductosOrdenBody").empty();

            if (!oc.oListaDetalle || oc.oListaDetalle.length === 0) {
                mostrarError("La orden de compra no tiene productos");
                return;
            }

            // Cargar cada detalle
            oc.oListaDetalle.forEach(detalle => {
                const disponible = detalle.Cantidad - detalle.CantidadFacturada;
                // El IdProducto vive dentro del objeto oProducto del modelo DetalleOrdenCompra
                const idProducto = detalle.oProducto ? detalle.oProducto.IdProducto : 0;
                const nombreProducto = detalle.oProducto ? detalle.oProducto.Nombre : 'Producto ' + idProducto;
                const fila = `
                    <tr data-id-detalle="${detalle.IdDetalleOrdenCompra}">
                        <td>${nombreProducto}</td>
                        <td class="text-center">${detalle.Cantidad}</td>
                        <td class="text-center">${detalle.CantidadFacturada}</td>
                        <td class="text-center disponible">${disponible}</td>
                        <td class="text-center">
                            <input type="number"
                                   class="form-control form-control-sm cantidad-facturar"
                                   max="${disponible}"
                                   min="0"
                                   value="0"
                                   ${disponible <= 0 ? 'disabled' : ''}
                                   data-precio="${detalle.PrecioUnitario}"
                                   data-iva="${detalle.IvaPorcentaje}"
                                   data-id-producto="${idProducto}"
                                   data-id-detalle-oc="${detalle.IdDetalleOrdenCompra}">
                        </td>
                        <td class="text-right">${formatearMonedaGs(Math.round(detalle.PrecioUnitario))}</td>
                        <td class="text-right total-linea">0 Gs.</td>
                    </tr>
                `;
                $("#tbProductosOrdenBody").append(fila);
            });

            // Agregar evento para calcular totales cuando cambian cantidades
            attachEventosCantidades();
            mostrarExito("Productos cargados desde la orden");
        } else {
            mostrarError(response.mensaje || "Error cargando productos de la orden");
        }
    } catch (error) {
        console.error("Error:", error);
        mostrarError("Error al obtener los productos de la orden");
    }
}

function attachEventosCantidades() {
    // Remover eventos anteriores para evitar duplicados
    $(document).off('input', '.cantidad-facturar');

    $(document).on('input', '.cantidad-facturar', function () {
        const $input = $(this);
        let cantidad = parseFloat($input.val()) || 0;
        const precio = parseFloat($input.data('precio'));
        const iva = parseFloat($input.data('iva')) || 10;
        const max = parseFloat($input.attr('max'));

        // Validar máximo
        if (cantidad > max) {
            cantidad = max;
            $input.val(max);
            mostrarError(`Máximo disponible: ${max}`);
        }

        // Validar mínimo
        if (cantidad < 0) {
            cantidad = 0;
            $input.val(0);
        }

        // Calcular total de la línea
        const totalSinIva = cantidad * precio;
        const totalConIva = totalSinIva * (1 + iva / 100);

        $input.closest('tr').find('.total-linea').text(
            formatearMonedaGs(Math.round(totalConIva))
        );

        actualizarTotalesGenerales();
    });
}

function actualizarTotalesGenerales() {
    let totalGeneral = 0;
    let totalIvaGeneral = 0;
    let cantidadTotal = 0;

    $("#tbProductosOrdenBody tr").each(function () {
        const cantidad = parseFloat($(this).find('.cantidad-facturar').val()) || 0;
        const precio = parseFloat($(this).find('.cantidad-facturar').data('precio')) || 0;
        const iva = parseFloat($(this).find('.cantidad-facturar').data('iva')) || 10;

        const totalSinIva = cantidad * precio;
        const totalIva = totalSinIva * (iva / 100);
        const totalConIva = totalSinIva + totalIva;

        cantidadTotal += cantidad;
        totalIvaGeneral += totalIva;
        totalGeneral += totalConIva;
    });

    $("#totalCantidad").text(cantidadTotal);
    $("#totalCompra").text(formatearMonedaGs(Math.round(totalGeneral - totalIvaGeneral)));
    $("#totalIva").text(formatearMonedaGs(Math.round(totalIvaGeneral)));
    $("#totalCompraFinal").text(formatearMonedaGs(Math.round(totalGeneral)));
}