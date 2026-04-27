/*
    SCRIPT DESACTIVADO - 26/04/2026
    La asignación de productos a tienda se realiza desde "Registrar Orden de Compra"
    Este archivo se mantiene para referencia histórica pero no se carga en la aplicación
*/

var tabladata;
var tablatienda;
var tablaproducto;

$(document).ready(function () {
    activarMenu("Compras");

    // Cargar motivos de baja al iniciar
    cargarMotivosBaja();

    // DataTable Tiendas
    // FIX: dataSrc:"data" para que DataTable lea el array correcto del JSON { data: [...] }
    tablatienda = $('#tbTienda').DataTable({
        ajax: { url: $.MisUrls.url._ObtenerTiendas, type: "GET", datatype: "json", dataSrc: "data" },
        columns: [
            {
                data: "IdTienda", render: function (data, type, row) {
                    return "<button class='btn btn-sm btn-primary ml-2' onclick='tiendaSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>";
                }, orderable: false, searchable: false, width: "90px"
            },
            { data: "RUC" },
            { data: "Nombre" },
            { data: "Direccion" }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true
    });

    // DataTable Productos
    // FIX: dataSrc:"data" para que DataTable lea el array correcto del JSON { data: [...] }
    tablaproducto = $('#tbProducto').DataTable({
        ajax: { url: $.MisUrls.url._ObtenerProductos, type: "GET", datatype: "json", dataSrc: "data" },
        columns: [
            {
                data: "IdProducto", render: function (data, type, row) {
                    return "<button class='btn btn-sm btn-primary ml-2' onclick='productoSelect(" + JSON.stringify(row) + ")'><i class='fas fa-check'></i></button>";
                }, orderable: false, searchable: false, width: "90px"
            },
            { data: "Codigo" },
            { data: "Nombre" },
            { data: "Descripcion" },
            { data: "oCategoria", render: function (data) { return data ? data.Descripcion : ""; } }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true
    });

    // DataTable Asignaciones
    // FIX: dataSrc:"data" para que DataTable lea el array correcto del JSON { data: [...] }
    tabladata = $('#tbdata').DataTable({
        ajax: { url: $.MisUrls.url._ObtenerAsignaciones, type: "GET", datatype: "json", dataSrc: "data" },
        columns: [
            { data: "oTienda", render: function (data) { return data ? data.Nombre : ""; } },
            { data: "oTienda", render: function (data) { return data ? data.RUC : ""; } },
            { data: "oProducto", render: function (data) { return data ? data.Codigo : ""; } },
            { data: "oProducto", render: function (data) { return data ? data.Nombre : ""; } },
            { data: "Stock" },
            {
                data: "IdProductoTienda", render: function (data) {
                    return "<button class='btn btn-danger btn-sm' onclick='eliminar(" + data + ")'><i class='fa fa-trash'></i></button>";
                }, orderable: false, searchable: false, width: "80px"
            },
            {
                data: null, render: function (data, type, row) {
                    return "<button class='btn btn-warning btn-sm' onclick='abrirModalBaja(" +
                        row.IdProductoTienda + ", " +
                        row.Stock + ", " +
                        row.oProducto.IdProducto + ", \"" +
                        row.oProducto.Nombre.replace(/"/g, '&quot;') + "\"" +
                        ")'><i class='fas fa-arrow-down'></i> Baja</button>";
                }, orderable: false, searchable: false, width: "100px"
            }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true
    });

    // Confirmar baja
    $("#btnConfirmarBaja").click(function () {
        registrarBaja();
    });
});

// ==================== MOTIVOS DE BAJA ====================
function cargarMotivosBaja() {
    $.ajax({
        url: '/Producto/ObtenerMotivosBaja',
        type: 'GET',
        dataType: 'json',
        success: function (data) {
            var $select = $("#bajaIdMotivo");
            $select.find("option:not(:first)").remove();
            if (data && data.length > 0) {
                $.each(data, function (i, item) {
                    $select.append($('<option>').val(item.IdMotivoBaja).text(item.Descripcion));
                });
            }
        },
        error: function () {
            console.error("No se pudieron cargar los motivos de baja.");
        }
    });
}

// ==================== ABRIR MODAL BAJA ====================
function abrirModalBaja(idProductoTienda, stockActual, idProducto, nombreProducto) {
    $("#bajaCantidad").val(1).attr("max", stockActual);
    $("#bajaIdMotivo").val("0");
    $("#bajaObservaciones").val("");
    $("#bajaIdProductoTienda").val(idProductoTienda);
    $("#bajaIdProducto").val(idProducto);
    $("#bajaStockActual").val(stockActual);
    $("#bajaNombreProducto").val(nombreProducto);
    $("#bajaStockMostrar").val(stockActual);
    $("#modalBajaStock").modal("show");
}

// ==================== REGISTRAR BAJA ====================
function registrarBaja() {
    var cantidad = parseInt($("#bajaCantidad").val());
    var idMotivo = parseInt($("#bajaIdMotivo").val());
    var observaciones = $("#bajaObservaciones").val().trim();
    var stockActual = parseInt($("#bajaStockActual").val());

    if (isNaN(cantidad) || cantidad <= 0) {
        Swal.fire("Atención", "Ingrese una cantidad válida mayor a cero.", "warning");
        return;
    }
    if (cantidad > stockActual) {
        Swal.fire("Atención", "La cantidad no puede superar el stock actual (" + stockActual + ").", "warning");
        return;
    }
    if (idMotivo === 0) {
        Swal.fire("Atención", "Seleccione un motivo de baja.", "warning");
        return;
    }

    $.ajax({
        url: '/Producto/BajaStockProductoTienda',
        type: 'POST',
        data: {
            idProductoTienda: $("#bajaIdProductoTienda").val(),
            idProducto: $("#bajaIdProducto").val(),
            idMotivoBaja: idMotivo,
            cantidad: cantidad,
            observaciones: observaciones
        },
        dataType: 'json',
        success: function (data) {
            if (data.resultado) {
                $("#modalBajaStock").modal("hide");
                tabladata.ajax.reload();
                Swal.fire("Éxito", "Baja registrada correctamente.", "success");
            } else {
                Swal.fire("Error", data.mensaje || "No se pudo registrar la baja.", "error");
            }
        },
        error: function () {
            Swal.fire("Error", "Error al procesar la solicitud.", "error");
        }
    });
}

// ==================== TIENDA / PRODUCTO ====================
function buscarTienda() {
    tablatienda.ajax.reload();
    $('#modalTienda').modal('show');
}

function buscarProducto() {
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

// Buscar producto por código (Enter)
// FIX: usa BuscarProductoPorCodigo en lugar de traer todos los productos y filtrar en JS
$("#txtCodigo").on('keypress', function (e) {
    if (e.which == 13) {
        var codigo = $(this).val().trim();
        if (!codigo) return;

        $.ajax({
            url: $.MisUrls.url._BuscarProductoPorCodigo,
            type: "GET",
            data: { codigo: codigo },
            dataType: "json",
            success: function (resp) {
                if (resp.resultado && resp.data) {
                    $("#txtIdProducto").val(resp.data.IdProducto);
                    $("#txtNombre").val(resp.data.Nombre);
                    $("#txtDescripcion").val(resp.data.Descripcion);
                } else {
                    $("#txtIdProducto").val("0");
                    $("#txtNombre").val("");
                    $("#txtDescripcion").val("");
                    Swal.fire("Atención", "Producto no encontrado.", "warning");
                }
            },
            error: function () {
                Swal.fire("Error", "No se pudo buscar el producto.", "error");
            }
        });
    }
});

// ==================== ASIGNAR PRODUCTO ====================
// FIX: unificado a Swal.fire + mensaje de éxito + manejo de error AJAX
function asignarProducto() {
    if ($("#txtIdTienda").val() == "0" || $("#txtIdProducto").val() == "0") {
        Swal.fire("Atención", "Debe seleccionar una tienda y un producto.", "warning");
        return;
    }

    var stockMinimo = parseInt($("#txtStockMinimo").val()) || 0;
    var stockMaximo = parseInt($("#txtStockMaximo").val()) || 0;

    if (stockMinimo === 0 || stockMaximo === 0) {
        Swal.fire("Atención", "El Stock Mínimo y Stock Máximo no pueden ser cero.", "warning");
        return;
    }

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

    $.ajax({
        url: $.MisUrls.url._RegistrarProductoTienda,
        type: "POST",
        data: JSON.stringify(request),
        dataType: "json",
        contentType: "application/json; charset=utf-8",
        success: function (data) {
            if (data.resultado) {
                tabladata.ajax.reload();
                $("#txtIdProducto").val("0");
                $("#txtCodigo, #txtNombre, #txtDescripcion").val("");
                $("#txtStockMinimo, #txtStockMaximo").val("0");
                Swal.fire("Éxito", "Asignación registrada correctamente.", "success");
            } else {
                Swal.fire("Error", data.mensaje || "No se pudo registrar la asignación.", "error");
            }
        },
        error: function () {
            Swal.fire("Error", "Error al procesar la solicitud.", "error");
        }
    });
}

// ==================== ELIMINAR ASIGNACIÓN ====================
// FIX: migrado a Swal.fire (SweetAlert 2) con .then()
function eliminar($id) {
    Swal.fire({
        title: "¿Eliminar asignación?",
        text: "Esta acción no se puede deshacer.",
        icon: "warning",
        showCancelButton: true,
        confirmButtonColor: "#DD6B55",
        confirmButtonText: "Sí, eliminar",
        cancelButtonText: "Cancelar"
    }).then(function (result) {
        if (!result.isConfirmed) return;

        $.ajax({
            url: $.MisUrls.url._EliminarProductoTienda,
            type: "POST",
            data: { id: $id },
            dataType: "json",
            success: function (data) {
                if (data.resultado) {
                    tabladata.ajax.reload();
                    Swal.fire("Eliminado", "La asignación fue eliminada correctamente.", "success");
                } else {
                    Swal.fire("Error", data.mensaje || "No se pudo eliminar.", "error");
                }
            },
            error: function () {
                Swal.fire("Error", "Error al procesar la solicitud.", "error");
            }
        });
    });
}