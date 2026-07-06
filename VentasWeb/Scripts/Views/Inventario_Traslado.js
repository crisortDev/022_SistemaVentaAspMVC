// ── Variables globales ────────────────────────────────────────
var dtProductos    = null;
var tablaTraslados = null;
var _tiendas       = [];   // lista completa de tiendas activas (para poblar destino)

$(document).ready(function () {
    activarMenu("Traslado entre Tiendas");

    // Datepickers
    $.datepicker.setDefaults($.datepicker.regional['es'] || {});
    $("#txtFechaInicio").datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());
    $("#txtFechaFin").datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());

    cargarTiendas();
    inicializarTablaHistorial();

    // ── Cambio de tienda origen: recargar DataTable ───────────
    $("#cboTiendaOrigen").on("change", function () {
        var idTienda = $(this).val();
        if (dtProductos) { dtProductos.clear().draw(); }
        $("#divTabla").hide();
        $("#divSinTienda").show();
        $("#lblTotalProductos").text("");
        if (!idTienda) return;
        cargarProductos(idTienda);
    });

    // ── Confirmar traslado desde el modal ─────────────────────
    $("#btnConfirmarTraslado").on("click", function () {
        var idProducto       = $("#hIdProducto").val();
        var idTiendaOrigen   = $("#hIdTiendaOrigen").val();
        var stockActual      = parseInt($("#hStockActual").val()) || 0;
        var idTiendaDestino  = $("#cboTiendaDestino").val();
        var cantidad         = parseInt($("#txtCantidad").val()) || 0;
        var observaciones    = $("#txtObservaciones").val().trim();
        var nombreProducto   = $("#lblProductoTraslado").text();
        var nombreDestino    = $("#cboTiendaDestino option:selected").text();

        // Validaciones cliente
        if (!idTiendaDestino)
            { toastr.warning("Seleccioná la sucursal destino."); return; }
        if (String(idTiendaOrigen) === String(idTiendaDestino))
            { toastr.warning("La sucursal destino no puede ser la misma que el origen."); return; }
        if (cantidad <= 0)
            { toastr.warning("La cantidad debe ser mayor a cero."); $("#txtCantidad").focus(); return; }
        if (cantidad > stockActual)
            { toastr.warning("La cantidad (" + cantidad + ") supera el stock disponible (" + stockActual + ")."); return; }
        if (observaciones.length < 3)
            { toastr.warning("La observación es obligatoria (mínimo 3 caracteres)."); $("#txtObservaciones").focus(); return; }

        Swal.fire({
            title: "¿Confirmar traslado?",
            html: "<b>" + cantidad + "</b> unidad(es) de <b>" + nombreProducto + "</b><br>"
                + "A: <b>" + nombreDestino + "</b>",
            icon: "warning",
            showCancelButton: true,
            confirmButtonText: "Sí, trasladar",
            cancelButtonText: "Cancelar",
            confirmButtonColor: "#ffc107"
        }).then(function (result) {
            if (!result.isConfirmed) return;

            $.post($.MisUrls.url._RegistrarTraslado, {
                idProducto      : idProducto,
                idTiendaOrigen  : idTiendaOrigen,
                idTiendaDestino : idTiendaDestino,
                cantidad        : cantidad,
                observaciones   : observaciones
            }, function (resp) {
                if (resp.resultado) {
                    $("#modalTraslado").modal("hide");
                    toastr.success(resp.mensaje || "Traslado registrado correctamente.");
                    cargarProductos(idTiendaOrigen);
                    tablaTraslados.ajax.reload(null, false);
                } else {
                    Swal.fire({ icon: "error", title: "Error", text: resp.mensaje });
                }
            }).fail(function () {
                Swal.fire({ icon: "error", title: "Error", text: "Error de conexión al registrar el traslado." });
            });
        });
    });

    // Limpiar modal al cerrarlo
    $("#modalTraslado").on("hidden.bs.modal", function () {
        $("#cboTiendaDestino").val("");
        $("#txtCantidad").val(1);
        $("#txtObservaciones").val("");
    });
});

// ── Abrir modal de traslado (llamado desde botón de la tabla) ─
window.abrirModalTraslado = function (idProducto, idProductoTienda, nombre, stock) {
    var idOrigen = $("#cboTiendaOrigen").val();

    // Poblar destinos: todas las tiendas activas excepto el origen
    var opts = '<option value="">-- Seleccione --</option>';
    _tiendas.forEach(function (t) {
        if (String(t.IdTienda) !== String(idOrigen)) {
            opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        }
    });
    $("#cboTiendaDestino").html(opts);

    $("#hIdProducto").val(idProducto);
    $("#hIdProductoTienda").val(idProductoTienda);
    $("#hStockActual").val(stock);
    $("#hIdTiendaOrigen").val(idOrigen);
    $("#lblProductoTraslado").text(nombre);
    $("#txtCantidad").val(1).attr("max", stock);
    $("#txtObservaciones").val("");
    $("#modalTraslado").modal("show");
};

// ── Cargar productos en DataTable ─────────────────────────────
function cargarProductos(idTienda) {
    $.get($.MisUrls.url._ObtenerProductosPorTiendaTraslado, { idTienda: idTienda }, function (resp) {
        var productos = resp.data || [];

        $("#divSinTienda").hide();
        $("#divTabla").show();

        if ($.fn.DataTable.isDataTable("#tblProductos")) {
            $("#tblProductos").DataTable().destroy();
        }

        var filas = productos.map(function (p) {
            var btnTraslado = '<button class="btn btn-sm btn-warning" '
                + 'onclick="abrirModalTraslado('
                + p.IdProducto + ','
                + p.IdProductoTienda + ',\''
                + (p.Nombre || '').replace(/'/g, "\\'") + '\','
                + (p.Stock || 0) + ')">'
                + '<i class="fas fa-exchange-alt mr-1"></i>Trasladar'
                + '</button>';
            return [
                p.Codigo    || '',
                p.Nombre    || '',
                p.Categoria || '',
                btnTraslado
            ];
        });

        dtProductos = $("#tblProductos").DataTable({
            data      : filas,
            columns   : [
                { title: 'Código',    width: '110px' },
                { title: 'Producto'  },
                { title: 'Categoría' },
                { title: 'Acciones', orderable: false, className: 'text-center', width: '130px' }
            ],
            language  : {
                url: "//cdn.datatables.net/plug-ins/1.13.5/i18n/es-ES.json"
            },
            pageLength : 15,
            order      : [[1, 'asc']],
            responsive : true
        });

        $("#lblTotalProductos").text(productos.length + " producto(s) disponible(s)");
    }).fail(function () {
        toastr.error("No se pudieron cargar los productos.");
    });
}

// ── Cargar tiendas ────────────────────────────────────────────
function cargarTiendas() {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        _tiendas = (data.data || []).filter(function (t) { return t.Activo; });
        var esSA     = AppSession.esSuperAdmin;
        var miTienda = AppSession.tiendaOperativa;

        // ── Combo origen ─────────────────────────────────────
        if (esSA) {
            var optsOrigen = '<option value="">-- Seleccione sucursal --</option>';
            _tiendas.forEach(function (t) {
                optsOrigen += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            });
            $("#cboTiendaOrigen").html(optsOrigen).prop("disabled", false);
        } else {
            var miNombre = (_tiendas.find(function (t) { return t.IdTienda == miTienda; }) || {}).Nombre || 'Mi sucursal';
            $("#cboTiendaOrigen")
                .html('<option value="' + miTienda + '">' + miNombre + '</option>')
                .val(miTienda)
                .prop("disabled", true)
                .trigger("change");   // carga productos automáticamente
        }

        // ── Filtro historial ─────────────────────────────────
        var optsFiltro = esSA ? '<option value="0">-- Todas --</option>' : '';
        _tiendas.forEach(function (t) {
            if (!esSA && t.IdTienda != miTienda) return;
            optsFiltro += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $("#cboFiltroTienda").html(optsFiltro);
        if (!esSA) $("#cboFiltroTienda").val(miTienda);
    });
}

// ── Historial ─────────────────────────────────────────────────
function inicializarTablaHistorial() {
    tablaTraslados = $("#tbTraslados").DataTable({
        ajax: {
            url  : $.MisUrls.url._ObtenerHistorialTraslados,
            type : "GET",
            data : function () {
                return {
                    fechainicio : $("#txtFechaInicio").val() || obtenerFechaHoy(),
                    fechafin    : $("#txtFechaFin").val()    || obtenerFechaHoy(),
                    idtienda    : $("#cboFiltroTienda").val() || 0
                };
            },
            dataSrc: "data"
        },
        columns: [
            {
                data: "Numero",
                render: function (d) {
                    return '<span class="badge badge-light border">' + (d || '') + '</span>';
                }
            },
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
        language : { url: "//cdn.datatables.net/plug-ins/1.13.5/i18n/es-ES.json" },
        responsive: true,
        order    : [[0, "desc"]],
        pageLength: 10
    });
}

function buscarHistorial() {
    if (!$("#txtFechaInicio").val() || !$("#txtFechaFin").val()) {
        toastr.warning("Ingresá las fechas para buscar.");
        return;
    }
    tablaTraslados.ajax.reload();
}

function obtenerFechaHoy() {
    var d = new Date();
    return ("0" + d.getDate()).slice(-2) + "/"
         + ("0" + (d.getMonth() + 1)).slice(-2) + "/"
         + d.getFullYear();
}
