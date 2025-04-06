
var tabladata;
var tablaproveedor;
var tablatienda;
var tablaproducto;


$(document).ready(function () {
    activarMenu("Compras");

    //OBTENER PROVEEDORES
    tablaproveedor = $('#tbProveedor').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProveedores,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdProveedor", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-sm btn-primary ml-2' type='button' onclick='proveedorSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>"
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            },
            { "data": "Ruc" },
            { "data": "RazonSocial" },
            { "data": "Direccion" }

        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });

    //OBTENER TIENDAS
    tablatienda = $('#tbTienda').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerTiendas,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdTienda", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-sm btn-primary ml-2' type='button' onclick='tiendaSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>" 
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            },
            { "data": "RUC" },
            { "data": "Nombre" },
            { "data": "Direccion" }

        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });

    //OBTENER PRODUCTOS
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductosPorTienda + "?IdTienda=0",
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdProducto", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-sm btn-primary ml-2' type='button' onclick='productoSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>"
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            },
            { "data": "Codigo" },
            { "data": "Nombre" },
            { "data": "Descripcion" },
            {
                "data": "oCategoria", render: function (data) {
                    return data.Descripcion
                }
            }

        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });

})

function buscarProveedor() {
    tablaproveedor.ajax.reload();
    $('#modalProveedor').modal('show');
}


function buscarTienda() {
    tablatienda.ajax.reload();
    $('#modalTienda').modal('show');
}

function buscarProducto() {
    if (parseInt($("#txtIdTienda").val()) == 0) {
        swal("Mensaje", "Debe seleccionar una tienda primero", "warning")
        return;
    }
    tablaproducto.ajax.url($.MisUrls.url._ObtenerProductosPorTienda + "?IdTienda=" + $("#txtIdTienda").val()).load();

    $('#modalProducto').modal('show');
}

function proveedorSelect(json) {

    $("#txtIdProveedor").val(json.IdProveedor);
    $("#txtRucProveedor").val(json.Ruc);
    $("#txtRazonSocialProveedor").val(json.RazonSocial);

    $('#modalProveedor').modal('hide');
}

function tiendaSelect(json) {
    $("#txtIdTienda").val(json.IdTienda);
    $("#txtRucTienda").val(json.RUC);
    $("#txtNombreTienda").val(json.Nombre);

    $('#modalTienda').modal('hide');
}

function productoSelect(json) {
    $("#txtIdProducto").val(json.IdProducto);
    $("#txtCodigoProducto").val(json.Codigo);
    $("#txtNombreProducto").val(json.Nombre);

    $('#modalProducto').modal('hide');
}



$("#txtCodigoProducto").on('keypress', function (e) {

    if (e.which == 13) {
        
        //OBTENER PRODUCTOS
        jQuery.ajax({
            url: $.MisUrls.url._ObtenerProductos,
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                $("#txtCodigoProducto").LoadingOverlay("hide");
                var encontrado = false;
                if (data.data != null) {
                    $.each(data.data, function (i, item) {
                        if (item.Activo == true && item.Codigo == $("#txtCodigoProducto").val()) {

                            $("#txtIdProducto").val(item.IdProducto);
                            $("#txtCodigoProducto").val(item.Codigo);
                            $("#txtNombreProducto").val(item.Nombre);

                            encontrado = true;
                            return false;
                        }
                    })

                    if (!encontrado) {
                        $("#txtIdProducto").val("0");
                        $("#txtNombreProducto").val("");
                    }
                }
            },
            error: function (error) {
                console.log(error)
            },
            beforeSend: function () {
                $("#txtCodigoProducto").LoadingOverlay("show");
            },
        });


    }
});

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

$("#txtCantidadProducto").inputFilter(function (value) {
    return /^-?\d*$/.test(value);
});

$("#txtPrecioCompraProducto").inputFilter(function (value) {
    return /^-?\d*[.]?\d{0,2}$/.test(value);
});

$("#txtPrecioVentaProducto").inputFilter(function (value) {
    return /^-?\d*[.]?\d{0,2}$/.test(value);
});



$('#btnAgregarCompra').on('click', function () {
    var existe_codigo = false;

    if (
        parseInt($("#txtIdProveedor").val()) == 0 ||
        parseInt($("#txtIdTienda").val()) == 0 ||
        parseInt($("#txtIdProducto").val()) == 0 ||
        parseFloat($("#txtCantidadProducto").val()) == 0 ||
        parseFloat($("#txtPrecioCompraProducto").val()) == 0 ||
        parseFloat($("#txtPrecioVentaProducto").val()) == 0
    ) {
        swal("Mensaje", "Debe completar todos los campos", "warning")
        return;
    }

    $('#tbCompra > tbody  > tr').each(function (index, tr) {
        var fila = tr;
        var codigoproducto = $(fila).find("td.codigoproducto").text();

        if (codigoproducto == $("#txtCodigoProducto").val()) {
            existe_codigo = true;
            return false;
        }
    });

    if (!existe_codigo) {
        $("<tr>").append(
            $("<td>").append(
                $("<button>").addClass("btn btn-danger btn-sm").text("Eliminar")
            ),
            $("<td>").append($("#txtRucProveedor").val()),
            $("<td>").append($("#txtRucTienda").val()),
            $("<td>").addClass("codigoproducto").data("idproducto", $("#txtIdProducto").val()).append($("#txtCodigoProducto").val()),
            $("<td>").append($("#txtNombreProducto").val()),
            $("<td>").addClass("cantidad").append($("#txtCantidadProducto").val()),
            $("<td>").addClass("preciocompra").append($("#txtPrecioCompraProducto").val()),
            $("<td>").addClass("precioventa").append($("#txtPrecioVentaProducto").val())
        ).appendTo("#tbCompra tbody");

        // Limpiar solo campos de producto
        $("#txtIdProducto").val("0");
        $("#txtCodigoProducto").val("");
        $("#txtNombreProducto").val("");
        $("#txtCantidadProducto").val("0");
        $("#txtPrecioCompraProducto").val("0");
        $("#txtPrecioVentaProducto").val("0");

    } else {
        swal("Mensaje", "El producto ya existe en la compra", "warning")
    }
});


$('#tbCompra tbody').on('click', 'button[class="btn btn-danger btn-sm"]', function () {
    $(this).parents("tr").remove();
})



$('#btnTerminarGuardarCompra').on('click', function () {
    if ($('#tbCompra > tbody  > tr').length === 0) {
        swal("Mensaje", "No existen detalles de compra", "warning");
        return;
    }

    const numeroFactura = $("#txtNumeroFactura").val().trim();
    const numeroTimbrado = $("#txtNumeroTimbrado").val().trim();
    const fechaVencimientoTimbrado = $("#txtFechaVencimientoTimbrado").val().trim();

    if (!numeroFactura || !numeroTimbrado || !fechaVencimientoTimbrado) {
        swal("Mensaje", "Debe completar todos los campos de facturación", "warning");
        return;
    }

    $.LoadingOverlay("show");

    try {
        let $xml = "<DETALLE>";

        let compra = "<COMPRA>" +
            "<IdUsuario>!idusuario¡</IdUsuario>" +
            "<IdProveedor>" + $("#txtIdProveedor").val() + "</IdProveedor>" +
            "<IdTienda>" + $("#txtIdTienda").val() + "</IdTienda>" +
            "<NumeroFactura>" + numeroFactura + "</NumeroFactura>" +
            "<NumeroTimbrado>" + numeroTimbrado + "</NumeroTimbrado>" +
            "<FechaVencimientoTimbrado>" + fechaVencimientoTimbrado + "</FechaVencimientoTimbrado>" +
            "<TotalCosto>!totalcosto¡</TotalCosto>" +
            "</COMPRA>";

        let detallecompra = "<DETALLE_COMPRA>";
        let detalle = "";
        let totalcostocompra = 0;

        $('#tbCompra > tbody  > tr').each(function (index, tr) {
            const fila = $(tr);
            const idproducto = parseFloat(fila.find("td.codigoproducto").data("idproducto"));
            const cantidad = parseFloat(fila.find("td.cantidad").text());
            const preciocompra = parseFloat(fila.find("td.preciocompra").text());
            const precioventa = parseFloat(fila.find("td.precioventa").text());
            const totalcosto = cantidad * preciocompra;

            detalle += "<DETALLE>" +
                "<IdCompra>0</IdCompra>" +
                "<IdProducto>" + idproducto + "</IdProducto>" +
                "<Cantidad>" + cantidad + "</Cantidad>" +
                "<PrecioUnidadCompra>" + preciocompra + "</PrecioUnidadCompra>" +
                "<PrecioUnidadVenta>" + precioventa + "</PrecioUnidadVenta>" +
                "<TotalCosto>" + totalcosto.toFixed(2) + "</TotalCosto>" +
                "</DETALLE>";

            totalcostocompra += totalcosto;
        });

        compra = compra.replace("!totalcosto¡", totalcostocompra.toFixed(2));
        $xml += compra + detallecompra + detalle + "</DETALLE_COMPRA></DETALLE>";

        const request = { xml: $xml };

        jQuery.ajax({
            url: $.MisUrls.url._GuardarCompra,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                $.LoadingOverlay("hide");

                // Caso de éxito
                if (data.resultado === true) {  // Verifica explícitamente si es true
                    resetPurchaseForm();
                    swal("Éxito", "Compra registrada correctamente", "success");
                }
                // Caso de error controlado (stock máximo)
                else if (data.resultado === false && data.error) {
                    swal("Error", data.error, "error"); // Muestra el mensaje específico
                }
                // Otros errores no controlados
                else {
                    swal("Error", "No se pudo registrar la compra", "error");
                }
            },
            error: function (error) {
                console.error("Error:", error);
                $.LoadingOverlay("hide");

                // Si el servidor retorna un JSON con error (ej: excepciones no capturadas)
                if (error.responseJSON && error.responseJSON.error) {
                    swal("Error", error.responseJSON.error, "error");
                } else {
                    swal("Error", "Ocurrió un error al procesar la compra", "error");
                }
            }
        });

    } catch (error) {
        console.error("Error processing purchase:", error);
        $.LoadingOverlay("hide");
        swal("Error", "Ocurrió un error al procesar la compra", "error");
    }
});

// Function to reset the purchase form
function resetPurchaseForm() {
    $("#txtIdProveedor").val("0");
    $("#txtRucProveedor").val("");
    $("#txtRazonSocialProveedor").val("");

    $("#txtIdTienda").val("0");
    $("#txtRucTienda").val("");
    $("#txtNombreTienda").val("");

    $("#txtIdProducto").val("0");
    $("#txtCodigoProducto").val("");
    $("#txtNombreProducto").val("");
    $("#txtCantidadProducto").val("0");
    $("#txtPrecioCompraProducto").val("0");
    $("#txtPrecioVentaProducto").val("0");

    $("#txtNumeroFactura").val("");
    $("#txtNumeroTimbrado").val("");
    $("#txtFechaVencimientoTimbrado").val("");

    $("#tbCompra tbody").empty();
}