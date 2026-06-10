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

        if (!idTiendaOrigen) { toastr.warning("Seleccione la tienda origen."); return; }
        if (!idProducto) { toastr.warning("Seleccione un producto."); return; }
        if (!idTiendaDestino) { toastr.warning("Seleccione la tienda destino."); return; }
        if (String(idTiendaOrigen) === String(idTiendaDestino)) { toastr.warning("La tienda origen y destino no pueden ser la misma."); return; }
        if (cantidad <= 0) { toastr.warning("La cantidad debe ser mayor a cero."); return; }
        if (cantidad > stockDisponible) { toastr.warning("Stock insuficiente. Disponible: " + stockDisponible); return; }

        Swal.fire({
            title: "Confirmar traslado",
            html: "<b>" + cantidad + "</b> unidad(es) de <b>" + $opcionProducto.text() + "</b><br>" +
                  "De: <b>" + $("#cboTiendaOrigen option:selected").text() + "</b><br>" +
                  "A: <b>" + $("#cboTiendaDestino option:selected").text() + "</b>",
            icon: "warning",
            showCancelButton: true,
            confirmButtonText: "Sí, trasladar",
            cancelButtonText: "Cancelar",
            confirmButtonColor: "#28a745"
        }).then(function (result) {
            if (!result.isConfirmed) return;
            $.post($.MisUrls.url._RegistrarTraslado, {
                idProducto: idProducto,
                idTiendaOrigen: idTiendaOrigen,
                idTiendaDestino: idTiendaDestino,
                cantidad: cantidad,
                observaciones: observaciones
            }, function (resp) {
                if (resp.resultado) {
                    toastr.success(resp.mensaje);
                    limpiarFormulario();
                    buscarHistorial();
                } else {
                    toastr.error(resp.mensaje);
                }
            });
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
    $.get($.MisUrls.url._ObtenerProductosPorTiendaTraslado, { idTienda: idTienda }, function (resp) {
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
            url: $.MisUrls.url._ObtenerHistorialTraslados,
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
        toastr.warning("Debe ingresar fechas para buscar.");
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
