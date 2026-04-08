var tablaproducto;
var tablacliente;


$(document).ready(function () {

    activarMenu("Ventas");
    $("#txtproductocantidad").val("0");
    $("#txtfechaventa").val(ObtenerFecha());


    //OBTENER PROVEEDORES
    jQuery.ajax({
        url: $.MisUrls.url._ObtenerUsuario,
        type: "GET",
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            //TIENDA
            $("#txtIdTienda").val(data.oTienda.IdTienda);
            $("#lbltiendanombre").text(data.oTienda.Nombre);
            $("#lbltiendaruc").text(data.oTienda.RUC);
            $("#lbltiendadireccion").text(data.oTienda.Direccion);

            //USUARIO
            $("#txtIdUsuario").val(data.IdUsuario);
            $("#lblempleadonombre").text(data.Nombres);
            $("#lblempleadoapellido").text(data.Apellidos);
            $("#lblempleadocorreo").text(data.Correo);
        },
        error: function (error) {
            console.log(error)
        },
        beforeSend: function () {
            $("#cboProveedor").LoadingOverlay("show");
        },
    });


    //OBTENER PRODUCTOS
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductoStockPorTienda + "?IdTienda=0",
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdProductoTienda", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-sm btn-primary ml-2' type='button' onclick='productoSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>"
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            },
            {
                "data": "oProducto", render: function (data) {
                    return data.Codigo
                }
            },
            {
                "data": "oProducto", render: function (data) {
                    return data.Nombre
                }
            },
            {
                "data": "oProducto", render: function (data) {
                    return data.Descripcion
                }
            },
            { "data": "Stock" }

        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });

    tablacliente = $('#tbcliente').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerClientes,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": "IdCliente", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-sm btn-primary ml-2' type='button' onclick='clienteSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>"
                },
                "orderable": false,
                "searchable": false,
                "width": "90px"
            },
            { "data": "TipoDocumento" },
            { "data": "NumeroDocumento" },
            { "data": "Nombre" },
            { "data": "Direccion" }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });

})

function ObtenerFecha() {

    var d = new Date();
    var month = d.getMonth() + 1;
    var day = d.getDate();
    var output = (('' + day).length < 2 ? '0' : '') + day + '/' + (('' + month).length < 2 ? '0' : '') + month + '/' + d.getFullYear();

    return output;
}


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

$("#txtproductocantidad").inputFilter(function (value) {
    return /^-?\d*$/.test(value);
});

$("#txtmontopago").inputFilter(function (value) {
    return /^-?\d*[.]?\d{0,2}$/.test(value);
});

$('#btnBuscarProducto').on('click', function () {


    tablaproducto.ajax.url($.MisUrls.url._ObtenerProductoStockPorTienda + "?IdTienda=" + parseInt($("#txtIdTienda").val())).load();

    $('#modalProducto').modal('show');
})

$('#btnBuscarCliente').on('click', function () {

    tablacliente.ajax.reload();

    $('#modalCliente').modal('show');
})

function productoSelect(json) {
    $("#txtIdProducto").val(json.oProducto.IdProducto);
    $("#txtproductocodigo").val(json.oProducto.Codigo);
    $("#txtproductonombre").val(json.oProducto.Nombre);
    $("#txtproductodescripcion").val(json.oProducto.Descripcion);
    $("#txtproductostock").val(json.Stock);

    // Ajuste: usar PrecioVenta y PrecioIvaIncluido del JSON recibido
    $("#txtproductoprecio").val(json.PrecioVenta);
    $("#txtproductoprecioiva").val(json.PrecioIvaIncluido);
    $("#txtproductoprecioiva").val(json.PrecioVentaIvaIncluido); // Con IVA


    $("#txtproductocantidad").val("0");
    $('#modalProducto').modal('hide');
}


function clienteSelect(json) {

    $("#cboclientetipodocumento").val(json.TipoDocumento);
    $("#txtclientedocumento").val(json.NumeroDocumento);
    $("#txtclientenombres").val(json.Nombre);
    $("#txtclientedireccion").val(json.Direccion);
    $("#txtclientetelefono").val(json.Telefono);
    $('#modalCliente').modal('hide');
}

$("#txtproductocodigo").on('keypress', function (e) {


    if (e.which == 13) {

        var request = { IdTienda: parseInt($("#txtIdTienda").val()) }


        //OBTENER PROVEEDORES
        jQuery.ajax({
            url: $.MisUrls.url._ObtenerProductoStockPorTienda + "?IdTienda=" + parseInt($("#txtIdTienda").val()),
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {

                var encontrado = false;
                if (data.data != null) {
                    $.each(data.data, function (i, item) {
                        if (item.oProducto.Codigo == $("#txtproductocodigo").val()) {

                            $("#txtIdProducto").val(item.oProducto.IdProducto);
                            $("#txtproductocodigo").val(item.oProducto.Codigo);
                            $("#txtproductonombre").val(item.oProducto.Nombre);
                            $("#txtproductodescripcion").val(item.oProducto.Descripcion);
                            $("#txtproductostock").val(item.Stock);
                            $("#txtproductoprecio").val(item.PrecioUnidadVenta);
                            $("#txtproductoprecioiva").val(item.PrecioVentaIvaIncluido); // <- Agregar esta línea

                            encontrado = true;
                            return false;
                        }
                    })

                    if (!encontrado) {

                        $("#txtIdProducto").val("0");
                        $("#txtproductocodigo").val("");
                        $("#txtproductonombre").val("");
                        $("#txtproductodescripcion").val("");
                        $("#txtproductostock").val("");
                        $("#txtproductoprecio").val("");
                        $("#txtproductocantidad").val("0");

                    }
                }

            },
            error: function (error) {
                console.log(error)
            },
            beforeSend: function () {
                $("#cboProveedor").LoadingOverlay("show");
            },
        });



    }
});


$("#btnAgregar").on("click", function () {
    var idproducto = $("#txtIdProducto").val();
    var nombre = $("#txtproductonombre").val();
    var descripcion = $("#txtproductodescripcion").val();
    var precio = parseFloat($("#txtproductoprecio").val()); // Precio sin IVA
    var precioiva = parseFloat($("#txtproductoprecioiva").val()); // Precio con IVA
    var cantidad = parseInt($("#txtproductocantidad").val());

    if (!idproducto || !nombre || isNaN(precio) || isNaN(precioiva) || isNaN(cantidad) || cantidad <= 0) {
        toastr.warning("Complete los campos del producto correctamente.");
        return;
    }

    var importetotal = Math.round(precio * cantidad);       // Sin decimales, entero
    var importetotaliva = Math.round(precioiva * cantidad); // Sin decimales, entero


    var filaHtml = '<tr>' +
        '<td><button class="btn btn-danger btn-sm eliminar-producto"><i class="fa fa-trash"></i></button></td>' +
        '<td class="productocantidad">' + cantidad + '</td>' +
        '<td class="producto" data-idproducto="' + idproducto + '">' + nombre + '</td>' +
        '<td class="productodescripcion">' + descripcion + '</td>' +
        '<td class="productoprecio" data-precio="' + precio + '">' + formatoGuaranies(precio) + '</td>' +
        '<td class="productoprecioiva" data-precioiva="' + precioiva + '">' + formatoGuaranies(precioiva) + '</td>' +
        '<td class="importetotal" data-importetotal="' + importetotal + '">' + formatoGuaranies(importetotal) + '</td>' +
        '<td class="importetotaliva" data-importetotaliva="' + importetotaliva + '">' + formatoGuaranies(importetotaliva) + '</td>' +
        '</tr>';




    $("#tbVenta > tbody").append(filaHtml);

    // Limpiar campos
    $("#txtIdProducto").val("0");
    $("#txtproductocodigo").val("");
    $("#txtproductonombre").val("");
    $("#txtproductodescripcion").val("");
    $("#txtproductoprecio").val("");
    $("#txtproductoprecioiva").val("");
    $("#txtproductocantidad").val("");

    calcularPrecios();
    actualizarTotalesTabla();
});





$('#tbVenta tbody').on('click', 'button[class="btn btn-danger btn-sm"]', function () {
    var idproducto = $(this).data("idproducto");
    var cantidadproducto = $(this).data("cantidadproducto");

    controlarStock(idproducto, parseInt($("#txtIdTienda").val()), cantidadproducto, false);
    $(this).parents("tr").remove();

    calcularPrecios();
    actualizarTotalesTabla();  // <== Añadir esta línea
})

$('#btnTerminarGuardarVenta').on('click', function () {

    // VALIDACIONES DE CLIENTE
    if ($("#txtclientedocumento").val().trim() == "" || $("#txtclientenombres").val().trim() == "") {
        swal("Mensaje", "Complete los datos del cliente", "warning");
        return;
    }
    // VALIDACIONES DE PRODUCTOS
    if ($('#tbVenta tbody tr').length == 0) {
        swal("Mensaje", "Debe registrar mínimo un producto en la venta", "warning");
        return;
    }

    var $totalproductos = 0;
    var $totalimportes = 0;

    var DETALLE = "";
    var VENTA = "";
    var DETALLE_CLIENTE = "";
    var DETALLE_VENTA = "";
    var DATOS_VENTA = "";

    // Recorremos la tabla para armar los datos
    $('#tbVenta > tbody > tr').each(function (index, tr) {
        var fila = tr;

        var productocantidad = parseInt($(fila).find("td.productocantidad").text());
        var idproducto = $(fila).find("td.producto").data("idproducto");
        var importetotal = parseInt($(fila).find("td.importetotal").attr("data-importetotal"));
        var importetotaliva = parseInt($(fila).find("td.importetotaliva").attr("data-importetotaliva"));
        var productoprecio = parseInt($(fila).find("td.productoprecio").attr("data-precio"));

        $totalproductos += productocantidad;
        $totalimportes += importetotal;

        DATOS_VENTA += "<DATOS>" +
            "<IdVenta>0</IdVenta>" +
            "<IdProducto>" + idproducto + "</IdProducto>" +
            "<Cantidad>" + productocantidad + "</Cantidad>" +
            "<PrecioUnidad>" + productoprecio + "</PrecioUnidad>" +
            "<ImporteTotal>" + importetotal + "</ImporteTotal>" +
            "<ImporteTotalIva>" + importetotaliva + "</ImporteTotalIva>" +
            "</DATOS>";
    });

    VENTA = "<VENTA>" +
        "<IdTienda>" + $("#txtIdTienda").val() + "</IdTienda>" +
        "<IdUsuario>" + $("#txtIdUsuario").val() + "</IdUsuario>" +
        "<IdCliente>0</IdCliente>" +
        "<TipoDocumento>" + $("#cboventatipodocumento").val() + "</TipoDocumento>" +
        "<CantidadProducto>" + $('#tbVenta tbody tr').length + "</CantidadProducto>" +
        "<CantidadTotal>" + $totalproductos + "</CantidadTotal>" +
        "<TotalCosto>" + $totalimportes + "</TotalCosto>" +
        "<ImporteRecibido>" + $totalimportes.toFixed(2) + "</ImporteRecibido>" +
        "<ImporteCambio>0</ImporteCambio>" +
        "</VENTA>";

    DETALLE_CLIENTE = "<DETALLE_CLIENTE><DATOS>" +
        "<TipoDocumento>" + $("#cboclientetipodocumento").val() + "</TipoDocumento>" +
        "<NumeroDocumento>" + $("#txtclientedocumento").val() + "</NumeroDocumento>" +
        "<Nombre>" + $("#txtclientenombres").val() + "</Nombre>" +
        "<Direccion>" + $("#txtclientedireccion").val() + "</Direccion>" +
        "<Telefono>" + $("#txtclientetelefono").val() + "</Telefono>" +
        "</DATOS></DETALLE_CLIENTE>";

    DETALLE_VENTA = "<DETALLE_VENTA>" + DATOS_VENTA + "</DETALLE_VENTA>";

    DETALLE = "<DETALLE>" + VENTA + DETALLE_CLIENTE + DETALLE_VENTA + "</DETALLE>"

    var request = { xml: DETALLE };

    jQuery.ajax({
        url: $.MisUrls.url._RegistrarVenta,
        type: "POST",
        data: JSON.stringify(request),
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        beforeSend: function () {
            $(".card-venta").LoadingOverlay("show");
        },
        success: function (data) {
            $(".card-venta").LoadingOverlay("hide");

            if (data.estado) {
                swal("¡Éxito!", "La venta se registró correctamente.", "success");

                // Limpiar campos cliente
                $("#txtclientedocumento").val("");
                $("#txtclientenombres").val("");
                $("#txtclientedireccion").val("");
                $("#txtclientetelefono").val("");

                // Limpiar tabla productos
                $("#tbVenta tbody").empty();

                // Resetear totales
                $('#total-cantidad').text(0);
                $('#total-preciounidad').text("0");
                $('#total-precioiva').text("0");
                $('#total-importesiniva').text("0");
                $('#total-importeconiva').text("0");
            }
            else {
                swal("Error", data.valor || "No se pudo registrar la venta. Intente nuevamente.", "error");
            }
        },
        error: function (error) {
            console.log(error);
            $(".card-venta").LoadingOverlay("hide");
            swal("Error", "Ocurrió un problema al registrar la venta.", "error");
        }
    });

});



function calcularCambio() {
    var montopago = $("#txtmontopago").val().trim() == "" ? 0 : parseFloat($("#txtmontopago").val().trim());
    var totalcosto = parseFloat($("#txttotal").val().trim());  // Usamos el total con IVA para el cálculo del vuelto
    var cambio = (montopago <= totalcosto ? totalcosto : montopago) - totalcosto;

    $("#txtcambio").val(cambio.toFixed(2));
}



$('#btncalcular').on('click', function () {
    calcularCambio();
})


function calcularPrecios() {
    var subtotal = 0;
    var totalconiva = 0;
    var iva = 0.10;  // IVA del 10%

    $('#tbVenta > tbody > tr').each(function (index, tr) {
        var fila = tr;
        var siniva = parseFloat($(fila).find("td.importetotal").text());
        var coniva = parseFloat($(fila).find("td.importetotaliva").text());

        subtotal += siniva;
        totalconiva += coniva;
    });

    // Calcular el IVA sobre el subtotal
    var totalIVA = subtotal * iva;

    // Actualizamos los campos de subtotal y total con IVA
    $("#txtsubtotal").val(subtotal.toFixed(2));  // Muestra el subtotal (sin IVA)
    $("#txttotal").val((subtotal + totalIVA).toFixed(2));  // Muestra el total (con IVA)
}









function controlarStock($idproducto, $idtienda, $cantidad, $restar) {
    var request = {
        idproducto: $idproducto,
        idtienda: $idtienda,
        cantidad: $cantidad,
        restar: $restar
    }


    jQuery.ajax({
        url: $.MisUrls.url._ControlarStockProducto,
        type: "POST",
        data: JSON.stringify(request),
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {

        },
        error: function (error) {
            console.log(error)
        },
        beforeSend: function () {
        },
    });


}


window.onbeforeunload = function () {
    if ($('#tbVenta tbody tr').length > 0) {

        $('#tbVenta > tbody  > tr').each(function (index, tr) {
            var fila = tr;
            var productocantidad = parseInt($(fila).find("td.productocantidad").text());
            var idproducto = $(fila).find("td.producto").data("idproducto");

            controlarStock(parseInt(idproducto), parseInt($("#txtIdTienda").val()), parseInt(productocantidad), false);
        });
    }
};

//function formatoMoneda(valor) {
//    if (isNaN(valor)) return valor;
//    return new Intl.NumberFormat('es-ES', {
//        minimumFractionDigits: 2,
//        maximumFractionDigits: 2
//    }).format(valor);
//}

function formatoGuaranies(valor) {
    return new Intl.NumberFormat('es-PY', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(valor);
}

function actualizarTotalesTabla() {
    var totalCantidad = 0;
    var totalPrecioUnidad = 0;
    var totalPrecioIva = 0;
    var totalImporteSinIva = 0;
    var totalImporteConIva = 0;

    $('#tbVenta > tbody > tr').each(function () {
        var fila = $(this);

        var cantidad = parseInt(fila.find('td.productocantidad').text()) || 0;
        var precioUnidad = parseFloat(fila.find('td.productoprecio').data('precio')) || 0;
        var precioIva = parseFloat(fila.find('td.productoprecioiva').data('precioiva')) || 0;
        var importeSinIva = parseFloat(fila.find('td.importetotal').data('importetotal')) || 0;
        var importeConIva = parseFloat(fila.find('td.importetotaliva').data('importetotaliva')) || 0;

        totalCantidad += cantidad;
        totalPrecioUnidad += precioUnidad * cantidad;
        totalPrecioIva += precioIva * cantidad;
        totalImporteSinIva += importeSinIva;
        totalImporteConIva += importeConIva;
    });

    $('#total-cantidad').text(totalCantidad);
    $('#total-preciounidad').text(formatoGuaranies(totalPrecioUnidad));
    $('#total-precioiva').text(formatoGuaranies(totalPrecioIva));
    $('#total-importesiniva').text(formatoGuaranies(totalImporteSinIva));
    $('#total-importeconiva').text(formatoGuaranies(totalImporteConIva));
}