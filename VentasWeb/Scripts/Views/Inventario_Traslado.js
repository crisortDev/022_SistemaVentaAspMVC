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
        var tiendas  = (data.data || []).filter(function (t) { return t.Activo; });
        var esSA     = AppSession.esSuperAdmin;
        var miTienda = AppSession.tiendaOperativa;

        // ── Combo origen ─────────────────────────────────────────────────────
        if (esSA) {
            var optsOrigen = '<option value="">-- Seleccione --</option>';
            tiendas.forEach(function (t) {
                optsOrigen += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            });
            $("#cboTiendaOrigen").html(optsOrigen).prop("disabled", false);
        } else {
            // No-SuperAdmin: origen fijo a su sucursal
            var miNombre = (tiendas.find(function (t) { return t.IdTienda == miTienda; }) || {}).Nombre || 'Mi sucursal';
            $("#cboTiendaOrigen")
                .html('<option value="' + miTienda + '">' + miNombre + '</option>')
                .val(miTienda)
                .prop("disabled", true);
            // Cargar productos de su sucursal automáticamente
            cargarProductosPorTienda(miTienda);
            $("#cboProducto").prop("disabled", false);
        }

        // ── Combo destino: todas las sucursales excepto la propia ────────────
        var optsDest = '<option value="">-- Seleccione --</option>';
        tiendas.forEach(function (t) {
            if (t.IdTienda == miTienda && !esSA) return; // excluir origen = destino para no-SA
            optsDest += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $("#cboTiendaDestino").html(optsDest);

        // ── Filtro historial ─────────────────────────────────────────────────
        var optsFiltro = esSA ? '<option value="0">-- Todas --</option>' : '';
        tiendas.forEach(function (t) {
            if (!esSA && t.IdTienda != miTienda) return; // no-SA solo ve su sucursal
            optsFiltro += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $("#cboFiltroTienda").html(optsFiltro);
        if (!esSA) $("#cboFiltroTienda").val(miTienda);
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
            { data: "Observaciones" },
            {
                data: "EstadoAprobacion",
                className: "text-center",
                render: function (d) {
                    if (d === "Pendiente") return '<span class="badge badge-warning">Pendiente</span>';
                    if (d === "Aprobado")  return '<span class="badge badge-success">Aprobado</span>';
                    if (d === "Rechazado") return '<span class="badge badge-danger">Rechazado</span>';
                    return '<span class="badge badge-secondary">' + (d || '') + '</span>';
                }
            }
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
    // Solo resetear origen si es SuperAdmin (no-SA tiene el campo bloqueado)
    if (AppSession.esSuperAdmin) $("#cboTiendaOrigen").val("");
    $("#cboTiendaDestino").val("");
    $("#cboProducto").html('<option value="">-- Seleccione producto --</option>').prop("disabled", AppSession.esSuperAdmin);
    $("#txtCantidad").val(1);
    $("#txtObservaciones").val("");
    $("#lblStockDisponible").text("-");
    // Para no-SA recargar productos de su sucursal
    if (!AppSession.esSuperAdmin) cargarProductosPorTienda(AppSession.tiendaOperativa);
}

function obtenerFechaHoy() {
    var d = new Date();
    var day = ("0" + d.getDate()).slice(-2);
    var month = ("0" + (d.getMonth() + 1)).slice(-2);
    return day + "/" + month + "/" + d.getFullYear();
}
