var tablaTraslados;

$(document).ready(function () {
    activarMenu("Traslado entre Tiendas");

    $.datepicker.setDefaults($.datepicker.regional['es'] || {});
    $("#txtFechaInicio").datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());
    $("#txtFechaFin").datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());

    cargarTiendas();
    inicializarTablaHistorial();

    // Al cambiar tienda origen, cargar productos
    $("#cboTiendaOrigen").on("change", function () {
        var idTienda = $(this).val();
        $("#cboProducto").html('<option value="">-- Seleccione producto --</option>').prop("disabled", true);
        $("#lblStockDisponible").text("-");
        if (!idTienda) return;
        cargarProductosPorTienda(idTienda);
        $("#cboProducto").prop("disabled", false);
    });

    // Al cambiar producto, mostrar stock disponible
    $("#cboProducto").on("change", function () {
        var stock = $(this).find(":selected").attr("data-stock") || 0;
        $("#lblStockDisponible").text(parseInt(stock) || 0);
    });

    // Registrar traslado
    $("#btnRegistrarTraslado").on("click", function () {
        var $opcionProducto = $("#cboProducto option:selected");
        var idProducto = $("#cboProducto").val();
        var idTiendaOrigen = $("#cboTiendaOrigen").val();
        var idTiendaDestino = $("#cboTiendaDestino").val();
        var cantidad = parseInt($("#txtCantidad").val()) || 0;
        var observaciones = $("#txtObservaciones").val().trim();
        var stockDisponible = parseInt($opcionProducto.attr("data-stock")) || 0;

        if (!idTiendaOrigen) { swal("Atencion", "Seleccione la tienda origen.", "warning"); return; }
        if (!idProducto) { swal("Atencion", "Seleccione un producto.", "warning"); return; }
        if (!idTiendaDestino) { swal("Atencion", "Seleccione la tienda destino.", "warning"); return; }
        if (String(idTiendaOrigen) === String(idTiendaDestino)) { swal("Atencion", "La tienda origen y destino no pueden ser la misma.", "warning"); return; }
        if (cantidad <= 0) { swal("Atencion", "La cantidad debe ser mayor a cero.", "warning"); return; }
        if (cantidad > stockDisponible) { swal("Atencion", "Stock insuficiente. Disponible: " + stockDisponible, "warning"); return; }

        swal({
            title: "Confirmar traslado",
            text: cantidad + " unidad(es) de " + $opcionProducto.text() +
                " | De: " + $("#cboTiendaOrigen option:selected").text() +
                " | A: " + $("#cboTiendaDestino option:selected").text(),
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, trasladar",
            cancelButtonText: "Cancelar"
        }, function (confirmado) {
            if (confirmado) {
                $.post("/Inventario/RegistrarTraslado", {
                    idProducto: idProducto,
                    idTiendaOrigen: idTiendaOrigen,
                    idTiendaDestino: idTiendaDestino,
                    cantidad: cantidad,
                    observaciones: observaciones
                }, function (resp) {
                    if (resp.resultado) {
                        swal("Exito", resp.mensaje, "success");
                        limpiarFormulario();
                        buscarHistorial();
                    } else {
                        swal("Error", resp.mensaje, "error");
                    }
                });
            }
        });
    });
});

function cargarTiendas() {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var tiendas = data.data || [];
        var optsTienda = '<option value="">-- Seleccione --</option>';
        var optsFiltro = '<option value="0">-- Todas --</option>';
        tiendas.forEach(function (t) {
            if (t.Activo) {
                optsTienda += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
                optsFiltro += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            }
        });
        $("#cboTiendaOrigen, #cboTiendaDestino").html(optsTienda);
        $("#cboFiltroTienda").html(optsFiltro);
    });
}

function cargarProductosPorTienda(idTienda) {
    $.get("/Inventario/ObtenerProductosPorTienda", { idTienda: idTienda }, function (resp) {
        var opts = '<option value="">-- Seleccione producto --</option>';
        (resp.data || []).forEach(function (p) {
            opts += '<option value="' + p.IdProducto + '" data-idproductotienda="' + p.IdProductoTienda + '" data-stock="' + p.Stock + '">' + p.Codigo + ' - ' + p.Nombre + ' (Stock: ' + p.Stock + ')</option>';
        });
        $("#cboProducto").html(opts);
    });
}

function inicializarTablaHistorial() {
    tablaTraslados = $('#tbTraslados').DataTable({
        ajax: {
            url: "/Inventario/ObtenerHistorialTraslados",
            type: "GET",
            data: function () {
                return {
                    fechainicio: $("#txtFechaInicio").val() || obtenerFechaHoy(),
                    fechafin: $("#txtFechaFin").val() || obtenerFechaHoy(),
                    idtienda: $("#cboFiltroTienda").val() || 0
                };
            },
            dataSrc: "data"
        },
        columns: [
            { data: "FechaTraslado" },
            { data: "NombreProducto" },
            { data: "CodigoProducto" },
            { data: "TiendaOrigen" },
            { data: "TiendaDestino" },
            { data: "Cantidad", className: "text-center" },
            { data: "Usuario" },
            { data: "Observaciones" }
        ],
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true,
        order: [[0, "desc"]]
    });
}

function buscarHistorial() {
    if (!$("#txtFechaInicio").val() || !$("#txtFechaFin").val()) {
        swal("Atencion", "Debe ingresar fechas para buscar.", "warning");
        return;
    }
    tablaTraslados.ajax.reload();
}

function limpiarFormulario() {
    $("#cboTiendaOrigen, #cboTiendaDestino").val("");
    $("#cboProducto").html('<option value="">-- Seleccione producto --</option>').prop("disabled", true);
    $("#txtCantidad").val(1);
    $("#txtObservaciones").val("");
    $("#lblStockDisponible").text("-");
}

function obtenerFechaHoy() {
    var d = new Date();
    var day = ("0" + d.getDate()).slice(-2);
    var month = ("0" + (d.getMonth() + 1)).slice(-2);
    return day + "/" + month + "/" + d.getFullYear();
}
