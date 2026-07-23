// Inventario_Traslado.js
// Flujo 5 pasos — Operador DESTINO:
//   Paso 1: Crear solicitud de traslado (este archivo)
//   Paso 4: Registrar llegada física de mercadería despachada (este archivo)
//   Pasos 2, 3, 5 → AprobarTraslados.js (supervisores)
'use strict';

var dtProductos    = null;
var tablaHistorial = null;
var _tiendas       = [];
var _miTienda      = AppSession.tiendaOperativa;
var _miNombre      = '';

$(function () {
    activarMenu("Traslado entre Tiendas");

    $.datepicker.setDefaults($.datepicker.regional['es'] || {});
    $("#txtFechaInicio").datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());
    $("#txtFechaFin"   ).datepicker({ dateFormat: 'dd/mm/yy' }).val(obtenerFechaHoy());

    cargarTiendas();
    inicializarTablaHistorial();
    cargarDespachados();

    // Cambio de sucursal origen → recargar productos
    $("#cboTiendaOrigen").on("change", function () {
        var id = $(this).val();
        if (dtProductos) dtProductos.clear().draw();
        $("#divTabla").hide();
        $("#divSinTienda").show();
        $("#lblTotalProductos").text("");
        if (!id) return;
        cargarProductos(id);
    });

    // Botón enviar solicitud
    $("#btnEnviarSolicitud").on("click", function () {
        var idProducto    = $("#hIdProducto").val();
        var idOrigen      = $("#hIdTiendaOrigen").val();
        var cantidad      = parseInt($("#txtCantidad").val()) || 0;
        var observaciones = $("#txtObservaciones").val().trim();

        if (!idOrigen)                { toastr.warning("Seleccioná la sucursal origen."); return; }
        if (cantidad <= 0)            { toastr.warning("La cantidad debe ser mayor a cero."); return; }
        if (observaciones.length < 3) { toastr.warning("La observación es obligatoria (mínimo 3 caracteres)."); return; }

        Swal.fire({
            title: '¿Enviar solicitud?',
            html: 'Se solicitará <b>' + cantidad + '</b> unidad(es) de <b>' + $("#lblProductoSolicitud").text() + '</b>'
                + '<br>a <b>' + $("#lblOrigenModal").text() + '</b>.',
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'Sí, enviar solicitud',
            confirmButtonColor: '#ffc107',
            cancelButtonText: 'Cancelar'
        }).then(function (result) {
            if (!result.isConfirmed) return;
            $.post($.MisUrls.url._Inv_RegistrarSolicitudTraslado, {
                idProducto    : idProducto,
                idTiendaOrigen: idOrigen,
                cantidad      : cantidad,
                observaciones : observaciones
            }, function (resp) {
                if (resp.resultado) {
                    $("#modalSolicitud").modal("hide");
                    toastr.success(resp.mensaje || "Solicitud registrada.");
                    cargarProductos(idOrigen);
                    tablaHistorial.ajax.reload(null, false);
                } else {
                    Swal.fire({ icon: 'error', title: 'Error', text: resp.mensaje });
                }
            }).fail(function () {
                Swal.fire({ icon: 'error', title: 'Error de conexión', text: 'No se pudo enviar la solicitud.' });
            });
        });
    });

    $("#modalSolicitud").on("hidden.bs.modal", function () {
        $("#txtCantidad").val(1);
        $("#txtObservaciones").val("");
    });
});

// ── Cargar tiendas ────────────────────────────────────────────────────────────
function cargarTiendas() {
    $.get($.MisUrls.url._Inv_ObtenerTiendas, function (data) {
        _tiendas = (data.data || []).filter(function (t) { return t.Activo; });

        var miObj = _tiendas.find(function (t) { return t.IdTienda == _miTienda; });
        _miNombre = miObj ? miObj.Nombre : 'Mi sucursal';
        $("#lblDestinoModal").text(_miNombre);

        // Combo origen: todas las tiendas excepto la mía
        var opts = '<option value="">-- Seleccione sucursal --</option>';
        _tiendas.forEach(function (t) {
            if (!AppSession.esSuperAdmin && t.IdTienda == _miTienda) return;
            opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
        });
        $("#cboTiendaOrigen").html(opts);
    });
}

// ── Abrir modal de solicitud ──────────────────────────────────────────────────
window.abrirModalSolicitud = function (idProducto, nombre, stock) {
    var idOrigen     = $("#cboTiendaOrigen").val();
    var nombreOrigen = $("#cboTiendaOrigen option:selected").text();

    $("#hIdProducto").val(idProducto);
    $("#hIdTiendaOrigen").val(idOrigen);
    $("#lblProductoSolicitud").text(nombre);
    $("#lblOrigenModal").text(nombreOrigen);
    $("#lblDestinoModal").text(_miNombre || 'Mi sucursal');
    $("#lblStockDisponible").text('Stock disponible en origen: ' + stock + ' uds.');
    $("#txtCantidad").val(1).attr("max", stock);
    $("#txtObservaciones").val("");
    $("#modalSolicitud").modal("show");
};

// ── Cargar productos de la sucursal origen ────────────────────────────────────
function cargarProductos(idTienda) {
    $.get($.MisUrls.url._ObtenerProductosPorTiendaTraslado, { idTienda: idTienda }, function (resp) {
        var productos = resp.data || [];

        $("#divSinTienda").hide();
        $("#divTabla").show();

        if ($.fn.DataTable.isDataTable("#tblProductos")) {
            $("#tblProductos").DataTable().destroy();
        }

        var filas = productos.map(function (p) {
            var btn = p.Stock > 0
                ? '<button class="btn btn-sm btn-warning" onclick="abrirModalSolicitud('
                  + p.IdProducto + ',\'' + (p.Nombre || '').replace(/'/g, "\\'") + '\',' + (p.Stock || 0) + ')">'
                  + '<i class="fas fa-paper-plane mr-1"></i>Solicitar</button>'
                : '<span class="text-muted small">Sin stock</span>';
            return [
                p.Codigo    || '',
                p.Nombre    || '',
                p.Categoria || '',
                '<span class="badge badge-' + (p.Stock > 0 ? 'success' : 'secondary') + '">' + (p.Stock || 0) + '</span>',
                btn
            ];
        });

        dtProductos = $("#tblProductos").DataTable({
            data      : filas,
            columns   : [
                { title: 'Código',   width: '100px' },
                { title: 'Producto' },
                { title: 'Categoría' },
                { title: 'Stock', className: 'text-center', width: '90px' },
                { title: 'Acción',  orderable: false, className: 'text-center', width: '110px' }
            ],
            language  : { url: "//cdn.datatables.net/plug-ins/1.13.5/i18n/es-ES.json" },
            pageLength : 15,
            order      : [[1, 'asc']],
            responsive : true
        });
        $("#lblTotalProductos").text(productos.length + " producto(s)");
    }).fail(function () {
        toastr.error("No se pudieron cargar los productos.");
    });
}

// ── Paso 4: Mercadería despachada ─────────────────────────────────────────────
window.cargarDespachados = function () {
    $.get($.MisUrls.url._Inv_ObtenerTrasladosPorEstado, { estado: 'Despachado' }, function (resp) {
        var lista = (resp.data || []).filter(function (t) {
            return AppSession.esSuperAdmin || t.IdTiendaDestino == _miTienda;
        });

        var tbody = $("#tbodyDespachados").empty();

        if (lista.length === 0) {
            $("#tblDespachados").hide();
            $("#divSinDespachados").show();
            return;
        }
        $("#divSinDespachados").hide();
        $("#tblDespachados").show();

        lista.forEach(function (t) {
            tbody.append('<tr>' +
                '<td><span class="badge badge-light border">' + (t.Numero || '') + '</span></td>' +
                '<td>' + (t.FechaTraslado || '') + '</td>' +
                '<td>' + (t.CodigoProducto || '') + ' — ' + (t.NombreProducto || '') + '</td>' +
                '<td class="text-center font-weight-bold">' + t.Cantidad + '</td>' +
                '<td>' + (t.TiendaOrigen || '') + '</td>' +
                '<td><small>' + (t.UsuarioAprueba || '—') + '</small></td>' +
                '<td class="text-center">' +
                    '<button class="btn btn-sm btn-outline-primary" onclick="registrarLlegada(' + t.IdTraslado + ',\'' + (t.Numero || '') + '\')">' +
                        '<i class="fas fa-box-open mr-1"></i>Registrar Llegada' +
                    '</button>' +
                '</td>' +
                '</tr>');
        });
    });
};

// ── Registrar llegada (Paso 4) ────────────────────────────────────────────────
window.registrarLlegada = function (id, numero) {
    Swal.fire({
        title: '¿Confirmar llegada?',
        html: 'Confirmá que los productos del traslado <b>' + numero + '</b> llegaron a tu sucursal.<br>'
            + '<small class="text-muted">El supervisor aprobará la recepción para que el stock se actualice.</small>',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: '<i class="fas fa-box-open mr-1"></i> Registrar llegada',
        confirmButtonColor: '#007bff',
        cancelButtonText: 'Cancelar'
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.post($.MisUrls.url._Inv_RegistrarRecepcionTraslado, { idTraslado: id }, function (res) {
            if (res.resultado) {
                toastr.success(res.mensaje);
                cargarDespachados();
                tablaHistorial.ajax.reload(null, false);
            } else {
                Swal.fire({ icon: 'error', title: 'Error', text: res.mensaje });
            }
        });
    });
};

// ── Historial ─────────────────────────────────────────────────────────────────
function inicializarTablaHistorial() {
    tablaHistorial = $("#tbTraslados").DataTable({
        ajax: {
            url    : $.MisUrls.url._Inv_ObtenerHistorialTraslados,
            type   : "GET",
            data   : function () {
                return {
                    fechainicio : $("#txtFechaInicio").val() || obtenerFechaHoy(),
                    fechafin    : $("#txtFechaFin").val()    || obtenerFechaHoy(),
                    idtienda    : 0
                };
            },
            dataSrc: "data"
        },
        columns: [
            { data: "Numero", render: function (d) {
                return '<span class="badge badge-light border">' + (d || '') + '</span>'; }},
            { data: "FechaTraslado" },
            { data: null, render: function (r) {
                return (r.CodigoProducto || '') + ' — ' + (r.NombreProducto || ''); }},
            { data: "TiendaOrigen" },
            { data: "TiendaDestino" },
            { data: "Cantidad", className: "text-center" },
            { data: "Usuario" },
            { data: "EstadoAprobacion", className: "text-center", render: badgeEstado }
        ],
        language  : { url: "//cdn.datatables.net/plug-ins/1.13.5/i18n/es-ES.json" },
        responsive: true,
        order     : [[0, "desc"]],
        pageLength: 10
    });
}

window.buscarHistorial = function () {
    if (!$("#txtFechaInicio").val() || !$("#txtFechaFin").val()) {
        toastr.warning("Ingresá las fechas para buscar."); return;
    }
    tablaHistorial.ajax.reload();
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function badgeEstado(estado) {
    var map = {
        'Solicitado'        : ['warning', 'Solicitado'],
        'AprobadoSolicitud' : ['info',    'Aprobado por destino'],
        'Despachado'        : ['primary', 'Despachado'],
        'EnRecepcion'       : ['warning', 'En recepción'],
        'Completado'        : ['success', 'Completado'],
        'RechazadoDestino'  : ['danger',  'Rechazado (destino)'],
        'RechazadoOrigen'   : ['danger',  'Rechazado (origen)']
    };
    var v = map[estado] || ['secondary', estado || ''];
    return '<span class="badge badge-' + v[0] + '">' + v[1] + '</span>';
}

function obtenerFechaHoy() {
    var d = new Date();
    return ('0' + d.getDate()).slice(-2) + '/'
         + ('0' + (d.getMonth() + 1)).slice(-2) + '/'
         + d.getFullYear();
}
