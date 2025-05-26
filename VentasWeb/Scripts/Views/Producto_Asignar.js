
var tabladata;
var tablatienda;
var tablaproducto;


$(document).ready(function () {
    activarMenu("Compras");


    ////validamos el formulario
    $("#form").validate({
        rules: {
            Nombre: "required",
            Descripcion: "required"
        },
        messages: {
            Nombre: "(*)",
            Descripcion: "(*)"

        },
        errorElement: 'span'
    });


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

    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductos,
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


    tabladata = $('#tbdata').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerAsignaciones,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            { "data": "oTienda", render: function (data) { return data.Nombre; } },
            { "data": "oTienda", render: function (data) { return data.RUC; } },
            { "data": "oProducto", render: function (data) { return data.Codigo; } },
            { "data": "oProducto", render: function (data) { return data.Nombre; } },
            { "data": "Stock" },
            {
                "data": "IdProductoTienda", "render": function (data, type, row, meta) {
                    return "<button class='btn btn-danger btn-sm ml-2' type='button' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                },
                "orderable": false,
                "searchable": false,
                "width": "80px"
            },
            // Nueva columna: Baja de Stock
            // Dentro de la configuración de tabladata:
            {
                "data": "Stock",
                "render": function (data, type, row, meta) {
                    return "<button class='btn btn-warning btn-sm ml-2' type='button' onclick='bajaStock(" + row.IdProductoTienda + ", " + data + ", " + row.oProducto.IdProducto + ")'><i class='fas fa-arrow-down'></i></button>";
                },
                "orderable": false,
                "searchable": false,
                "width": "80px"
            }
        ],
        "language": {
            "url": $.MisUrls.url.Url_datatable_spanish
        },
        responsive: true
    });



})


function buscarTienda() {
    tablatienda.ajax.reload();
    $('#modalTienda').modal('show');
}

function buscarProducto(){
    tablaproducto.ajax.reload();
    $('#modalProducto').modal('show');
}

function tiendaSelect(json) {
    $("#txtIdTienda").val(json.IdTienda);
    $("#txtRuc").val(json.RUC);
    $("#txtRazonSocial").val(json.Nombre);
    $("#txtDireccion").val(json.Direccion);

    $('#modalTienda').modal('hide');
}

function productoSelect(json) {
    $("#txtIdProducto").val(json.IdProducto);
    $("#txtCodigo").val(json.Codigo);
    $("#txtNombre").val(json.Nombre);
    $("#txtDescripcion").val(json.Descripcion);

    $('#modalProducto').modal('hide');
}

$("#txtCodigo").on('keypress', function (e) {

    if (e.which == 13) {
        
        //OBTENER PRODUCTOS
        jQuery.ajax({
            url: $.MisUrls.url._ObtenerProductos,
            type: "GET",
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                $("#txtCodigo").LoadingOverlay("hide");
                var encontrado = false;
                if (data.data != null) {
                    $.each(data.data, function (i, item) {
                        if (item.Activo == true && item.Codigo == $("#txtCodigo").val()) {

                            $("#txtIdProducto").val(item.IdProducto);
                            $("#txtCodigo").val(item.Codigo);
                            $("#txtNombre").val(item.Nombre);
                            $("#txtDescripcion").val(item.Descripcion);

                            encontrado = true;
                            return false;
                        }
                    })

                    if (!encontrado) {
                        $("#txtIdProducto").val("0");
                        $("#txtNombre").val("");
                        $("#txtDescripcion").val("");
                    }
                }

            },
            error: function (error) {
                console.log(error)
            },
            beforeSend: function () {
                $("#txtCodigo").LoadingOverlay("show");
            },
        });


    }
});


function asignarProducto() {
    var camposvacios = false;

    if ($("#txtIdTienda").val() == "0" || $("#txtIdProducto").val() == "0") {
        camposvacios = true;
    }

    var stockMinimo = parseInt($("#txtStockMinimo").val()) || 0;
    var stockMaximo = parseInt($("#txtStockMaximo").val()) || 0;

    // Validamos que StockMinimo y StockMaximo no sean cero
    if (stockMinimo === 0 || stockMaximo === 0) {
        camposvacios = true;
        swal("Mensaje", "El Stock Mínimo y Stock Máximo no pueden ser cero", "warning");
    }

    if (!camposvacios) {
        var request = {
            objeto: {
                oProducto: { IdProducto: parseInt($("#txtIdProducto").val()) },
                oTienda: { IdTienda: parseInt($("#txtIdTienda").val()) },
                StockMinimo: stockMinimo,
                StockMaximo: stockMaximo,
                PrecioUnidadCompra: parseFloat($("#txtPrecioCompra").val()) || 0,
                PrecioUnidadVenta: parseFloat($("#txtPrecioVenta").val()) || 0
            }
        };

        jQuery.ajax({
            url: $.MisUrls.url._RegistrarProductoTienda,
            type: "POST",
            data: JSON.stringify(request),
            dataType: "json",
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    // Limpiar campos después de asignar
                    $("#txtIdProducto").val("0");
                    $("#txtCodigo").val("");
                    $("#txtNombre").val("");
                    $("#txtDescripcion").val("");
                    $("#txtStockMinimo").val("0");
                    $("#txtStockMaximo").val("0");
                } else {
                    swal("Mensaje", "No se pudo registrar la asignación", "warning");
                }
            },
            error: function (error) {
                console.log(error);
            }
        });
    } else {
        swal("Mensaje!", "Es necesario completar todos los campos correctamente", "warning");
    }
}



function eliminar($id) {
    swal({
        title: "Mensaje",
        text: "¿Desea eliminar la asignación?",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Si",
        confirmButtonColor: "#DD6B55",
        cancelButtonText: "No",
        closeOnConfirm: true
    },
        function () {
            jQuery.ajax({
                url: $.MisUrls.url._EliminarProductoTienda, // Sin el ?id=...
                type: "POST", // Cambiado a POST
                data: { id: $id }, // Envía el id en el cuerpo
                dataType: "json",
                success: function (data) {
                    if (data.resultado) {
                        tabladata.ajax.reload();
                    } else {
                        swal("Mensaje", data.mensaje || "No se pudo eliminar", "warning");
                    }
                },
                error: function (xhr, status, error) {
                    swal("Error", "No se pudo procesar la solicitud", "error");
                }
            });
        });
}

function bajaStock(idProductoTienda, stockActual, idProducto) {

    // El resto de tu lógica de baja de stock
    Swal.fire({
        title: "Ingrese los detalles de la baja",
        html: `
            <div>
                <label for="cantidad">Cantidad a reducir:</label>
                <input type="number" id="cantidad" class="swal2-input" min="1" max="${stockActual}" value="1">
                <br><br>
                <label for="motivo">Motivo de la baja:</label>
                <input type="text" id="motivo" class="swal2-input" placeholder="Motivo de la baja">
            </div>
        `,
        focusConfirm: false,
        showCancelButton: true,
        confirmButtonText: 'Aceptar',
        cancelButtonText: 'Cancelar',
        preConfirm: () => {
            const cantidad = document.getElementById('cantidad').value;
            const motivo = document.getElementById('motivo').value;

            // Validaciones
            if (!cantidad || isNaN(cantidad) || cantidad <= 0) {
                Swal.showValidationMessage('Por favor ingrese una cantidad válida mayor a cero');
                return false;
            }

            if (cantidad > stockActual) {
                Swal.showValidationMessage('No puede reducir más stock del disponible');
                return false;
            }

            if (!motivo.trim()) {
                Swal.showValidationMessage('Por favor ingrese un motivo para la baja de stock');
                return false;
            }

            return {
                cantidad: cantidad,
                motivo: motivo
            };
        }
    }).then((result) => {
        if (result.isConfirmed) {
            const { cantidad, motivo } = result.value;

            // Llamada AJAX para reducir el stock
            jQuery.ajax({
                url: '/Producto/BajaStockProductoTienda',
                type: 'POST',
                data: {
                    idProductoTienda: idProductoTienda,
                    cantidad: cantidad,
                    motivo: motivo,
                    idProducto: idProducto // Asegúrate de enviar idProducto
                },
                success: function (data) {
                    if (data.resultado) {
                        tabladata.ajax.reload();
                        Swal.fire('Éxito', 'El stock se ha reducido correctamente', 'success');
                    } else {
                        Swal.fire('Error', data.mensaje, 'error');
                    }
                },
                error: function (xhr, status, error) {
                    console.log("Error:", error);
                    console.log("Response Text:", xhr.responseText);
                    Swal.fire('Error', 'Error al procesar la solicitud', 'error');
                }
            });
        }
    });
}









