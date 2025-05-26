var tablaproveedor;
var tablatienda;
var tablaproducto;
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
});
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


    // DataTable Tiendas
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
            { "data": "Direccion" }
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
            "datatype": "json"
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `
                <button class="btn btn-sm btn-primary seleccionar-producto"
                        data-id="${row.IdProducto}"
                        data-codigo="${row.Codigo}"
                        data-nombre="${row.Nombre}">
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

    configurarFiltrosEntrada();
}

function columnaBotonSeleccion(clickHandler) {
    return {
        "data": null,
        "render": (data, type, row) =>
            `<button class="btn btn-sm btn-primary ml-2" 
                    type="button" 
                    onclick="${clickHandler.name}(${JSON.stringify(row)})">
                <i class="fas fa-check"></i>
            </button>`,
        "orderable": false,
        "searchable": false,
        "width": "90px"
    };
}

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

function configurarFiltrosEntrada() {
    // Configurar filtros de entrada numéricos
    $("#txtCantidadProducto").inputFilter(value => /^\d*$/.test(value));
    $("#txtPrecioCompraProducto").inputFilter(value => /^\d*[.]?\d{0,2}$/.test(value));
    $("#txtPrecioVentaProducto").inputFilter(value => /^\d*[.]?\d{0,2}$/.test(value));

    // Evento búsqueda por código producto
    $("#txtCodigoProducto").on('keypress', async function (e) {
        if (e.which === 13) await buscarProductoPorCodigo();
    });
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
        console.error("Error buscando producto:", error);
        mostrarError("Error al buscar producto");
    }
}

// Funciones de selección
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

// Gestión de compra
$('#btnAgregarCompra').on('click', agregarProductoALista);

function agregarProductoALista() {
    const camposRequeridos = validarCamposRequeridos();
    if (!camposRequeridos.validos) {
        mostrarError(camposRequeridos.mensaje);
        return;
    }

    const productoExistente = buscarProductoEnLista();
    if (productoExistente) {
        mostrarError("El producto ya existe en la lista");
        return;
    }

    agregarFilaProducto();
    limpiarCamposProducto();
}

function validarCamposRequeridos() {
    const campos = [
        { id: "#txtIdProveedor", nombre: "Proveedor" },
        { id: "#txtIdTienda", nombre: "Tienda" },
        { id: "#txtIdProducto", nombre: "Producto" },
        { id: "#txtCantidadProducto", nombre: "Cantidad" },
        { id: "#txtPrecioCompraProducto", nombre: "Precio Compra" },
        { id: "#txtPrecioVentaProducto", nombre: "Precio Venta" }
    ];

    for (let campo of campos) {
        const valor = $(campo.id).val();
        if (!valor || valor === "0" || (typeof valor === "string" && !valor.trim())) {
            return { validos: false, mensaje: `${campo.nombre} es requerido` };
        }
    }
    return { validos: true };
}

function agregarFilaProducto() {
    const fila = `
        <tr>
            <td><button class="btn btn-danger btn-sm">Eliminar</button></td>
            <td>${$("#txtRucProveedor").val()}</td>
            <td>${$("#txtRucTienda").val()}</td>
            <td class="codigoproducto" data-idproducto="${$("#txtIdProducto").val()}">
                ${$("#txtCodigoProducto").val()}
            </td>
            <td>${$("#txtNombreProducto").val()}</td>
            <td class="cantidad">${$("#txtCantidadProducto").val()}</td>
            <td class="preciocompra">${$("#txtPrecioCompraProducto").val()}</td>
            <td class="precioventa">${$("#txtPrecioVentaProducto").val()}</td>
        </tr>`;
    $("#tbCompra tbody").append(fila);
}

// Gestión del formulario
$('#btnTerminarGuardarCompra').on('click', guardarCompra);

async function guardarCompra() {
    if (!validarListaProductos()) return;

    try {
        const xmlData = construirXMLCompra();
        const response = await enviarCompraAlServidor(xmlData);

        if (response.resultado) {
            mostrarExito("Compra registrada exitosamente");
            resetPurchaseForm();
        } else {
            manejarErrorServidor(response);
        }
    } catch (error) {
        console.error("Error guardando compra:", error);
        mostrarError("Error al procesar la compra");
    }
}

function construirXMLCompra() {
    let totalCosto = 0;
    let detalleXML = "";

    $("#tbCompra tbody tr").each(function () {
        const $tds = $(this).find('td');
        const cantidad = parseFloat($tds.eq(5).text());
        const precioCompra = parseFloat($tds.eq(6).text());
        const total = cantidad * precioCompra;
        totalCosto += total;

        detalleXML += `
            <DETALLE>
                <IdProducto>${$tds.eq(3).data('idproducto')}</IdProducto>
                <Cantidad>${cantidad}</Cantidad>
                <PrecioUnidadCompra>${precioCompra}</PrecioUnidadCompra>
                <PrecioUnidadVenta>${parseFloat($tds.eq(7).text())}</PrecioUnidadVenta>
                <TotalCosto>${total.toFixed(2)}</TotalCosto>
            </DETALLE>`;
    });

    return `
        <DETALLE>
            <COMPRA>
                <IdUsuario>${obtenerIdUsuario()}</IdUsuario>
                <IdProveedor>${$("#txtIdProveedor").val()}</IdProveedor>
                <IdTienda>${$("#txtIdTienda").val()}</IdTienda>
                <NumeroFactura>${$("#txtNumeroFactura").val()}</NumeroFactura>
                <NumeroTimbrado>${$("#txtNumeroTimbrado").val()}</NumeroTimbrado>
                <FechaVencimientoTimbrado>${$("#txtFechaVencimientoTimbrado").val()}</FechaVencimientoTimbrado>
                <TotalCosto>${totalCosto.toFixed(2)}</TotalCosto>
            </COMPRA>
            <DETALLE_COMPRA>
                ${detalleXML}
            </DETALLE_COMPRA>
        </DETALLE>`;
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

// Helpers
function mostrarError(mensaje) {
    swal("Error", mensaje, "error");
}

function mostrarExito(mensaje) {
    swal("Éxito", mensaje, "success");
}

function resetPurchaseForm() {
    $("#tbCompra tbody").empty();
    $(".form-control").val("");
    $("input[type='hidden']").val("0");
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

// Inicializar tooltips
$(function () {
    $('[data-toggle="tooltip"]').tooltip()
});

function buscarProveedor() {
    $('#modalProveedor').modal('show');
    tablaproveedor.ajax.reload(); // Cargar datos cada vez que se abre
}


function buscarTienda() {
    $('#modalTienda').modal('show');
    tablatienda.ajax.reload(); // Recarga la tabla de tiendas
}

function buscarProducto() {
    $('#modalProducto').modal('show');
    tablaproducto.ajax.reload(); // Cargar la tabla de productos cada vez que se abre
}
