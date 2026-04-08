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

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
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
        { id: "#txtPrecioCompraProducto", nombre: "Precio Compra" }
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
    const cantidad = parseFloat($("#txtCantidadProducto").val()) || 0;
    const precioUnidad = parseFloat($("#txtPrecioCompraProducto").val()) || 0;
    const ivaPorcentaje = parseFloat($("#txtIvaPorcentaje").val()) || 0;

    const totalSinIva = cantidad * precioUnidad;
    const totalConIva = totalSinIva * (1 + ivaPorcentaje / 100);

    const fila = `
        <tr>
            <td><button class="btn btn-danger btn-sm">Eliminar</button></td>
            <td class="codigoproducto" data-idproducto="${$("#txtIdProducto").val()}">
                ${$("#txtCodigoProducto").val()}
            </td>
            <td>${$("#txtNombreProducto").val()}</td>
            <td class="cantidad">${cantidad}</td>
            <td class="preciocompra">${formatearMonedaGs(Math.round(precioUnidad))}</td>
            <td class="totalcompra">${formatearMonedaGs(Math.round(totalSinIva))}</td>
            <td class="totalcompraiva">${formatearMonedaGs(Math.round(totalConIva))}</td>
        </tr>`;
    $("#tbCompra tbody").append(fila);
    actualizarTotalesCompra();
}

$('#btnTerminarGuardarCompra').on('click', guardarCompra);

async function guardarCompra() {
    if (!validarListaProductos()) return;

    try {
        const xmlData = construirXMLCompra();
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

function validarListaProductos() {
    const filas = $("#tbCompra tbody tr");
    if (filas.length === 0) {
        mostrarError("Debe agregar al menos un producto a la lista de compra.");
        return false;
    }
    return true;
}

function construirXMLCompra() {
    let totalCosto = 0;
    let detalleXML = "";

    $("#tbCompra tbody tr").each(function () {
        const $tds = $(this).find('td');
        const idProducto = $tds.eq(1).data('idproducto');
        const cantidad = parseInt($tds.eq(3).text());
        const precioCompra = parseMonedaGs($tds.eq(4).text());
        const totalSinIva = parseMonedaGs($tds.eq(5).text());
        const totalConIva = parseMonedaGs($tds.eq(6).text());

        totalCosto += totalSinIva;

        detalleXML += `
            <DETALLE>
                <IdProducto>${idProducto}</IdProducto>
                <Cantidad>${cantidad}</Cantidad>
                <PrecioUnidadCompra>${precioCompra}</PrecioUnidadCompra>
                <PrecioUnidadCompraConIva>${totalConIva / cantidad}</PrecioUnidadCompraConIva>
                <PrecioUnidadVenta>0</PrecioUnidadVenta>
                <TotalCosto>${totalSinIva}</TotalCosto>
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
    swal("Error", mensaje, "error");
}

function mostrarExito(mensaje) {
    swal("Éxito", mensaje, "success");
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