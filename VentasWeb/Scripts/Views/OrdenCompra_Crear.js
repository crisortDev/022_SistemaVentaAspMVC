var tablaproveedor;
var tablatienda;
var tablaproducto;

// ═══════════════════════════════════════════════════════
//  UTILIDADES
// ═══════════════════════════════════════════════════════

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

$(document).ready(function () {
    activarMenu("Compras");

    // ── Datepicker ──────────────────────────────────────
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $("#txtFechaEntrega").datepicker({ dateFormat: 'dd/mm/yy' });

    inicializarDataTables();

    // ── Si no es SuperAdmin, cargar su tienda y ocultar botón ──
    if (!AppSession.esSuperAdmin) {
        $("#divBtnBuscarTienda").hide();
        cargarTiendaAutomatica(AppSession.idTienda);
    }

    // ── Agregar ítem ────────────────────────────────────
    $("#btnAgregarItem").on("click", agregarItem);

    // ── Guardar orden ───────────────────────────────────
    $("#btnGuardarOrden").on("click", guardarOrden);

    // ── Eliminar ítem del detalle ───────────────────────
    $(document).on('click', '#tbDetalle tbody button.btn-danger', function () {
        $(this).closest('tr').remove();
        recalcularTotales();
    });
});

// ═══════════════════════════════════════════════════════
//  DATA TABLES Y BÚSQUEDAS
// ═══════════════════════════════════════════════════════

function inicializarDataTables() {
    // Proveedores
    tablaproveedor = $('#tbProveedor').DataTable({
        "ajax": {
            "url": $.MisUrls.url._OC_ObtenerProveedores,
            "type": "GET",
            "datatype": "json"
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class="btn btn-sm btn-primary sel-proveedor-oc"
                                data-id="${row.IdProveedor}"
                                data-ruc="${row.Ruc}"
                                data-razon="${row.RazonSocial}">
                                <i class="fas fa-check"></i>
                            </button>`;
                },
                "orderable": false, "searchable": false, "width": "60px"
            },
            { "data": "Ruc" },
            { "data": "RazonSocial" },
            { "data": "Direccion" }
        ],
        "language": lenguajeDataTable()
    });

    $(document).on('click', '.sel-proveedor-oc', function () {
        $("#txtIdProveedor").val($(this).data('id'));
        $("#txtRucProveedor").val($(this).data('ruc'));
        $("#txtRazonSocialProveedor").val($(this).data('razon'));
        $('#modalProveedor').modal('hide');
    });

    // Tiendas (solo SuperAdmin)
    if (AppSession.esSuperAdmin) {
        tablatienda = $('#tbTienda').DataTable({
            "ajax": { "url": $.MisUrls.url._ObtenerTiendas, "type": "GET", "datatype": "json" },
            "columns": [
                {
                    "data": null,
                    "render": function (data, type, row) {
                        return `<button class="btn btn-sm btn-primary sel-tienda-oc"
                                    data-id="${row.IdTienda}"
                                    data-ruc="${row.RUC}"
                                    data-nombre="${row.Nombre}">
                                    <i class="fas fa-check"></i>
                                </button>`;
                    },
                    "orderable": false, "searchable": false, "width": "60px"
                },
                { "data": "RUC" },
                { "data": "Nombre" },
                { "data": "Direccion" }
            ],
            "language": lenguajeDataTable()
        });

        $(document).on('click', '.sel-tienda-oc', function () {
            var idTienda = $(this).data('id');
            $("#txtIdTienda").val(idTienda);
            $("#txtRucTienda").val($(this).data('ruc'));
            $("#txtNombreTienda").val($(this).data('nombre'));
            $('#modalTienda').modal('hide');
            // Recargar productos según la tienda seleccionada
            if (tablaproducto) {
                recargarProductosPorTienda(idTienda);
            }
        });
    }

    // Productos
    tablaproducto = $('#tbProducto').DataTable({
        "ajax": {
            "url": $.MisUrls.url._ObtenerProductos,
            "type": "GET",
            "datatype": "json",
            "dataSrc": function(json) {
                // Manejar respuestas en diferentes formatos
                if (json && json.data) {
                    return json.data;
                } else if (Array.isArray(json)) {
                    return json;
                } else {
                    console.warn("Formato de respuesta inesperado:", json);
                    return [];
                }
            },
            "error": function(xhr, status, error) {
                console.error("Error al cargar productos:", error, xhr);
            }
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class="btn btn-sm btn-primary sel-producto-oc"
                                data-id="${row.IdProducto}"
                                data-codigo="${row.Codigo}"
                                data-nombre="${row.Nombre}"
                                data-iva="${row.IvaPorcentaje || 10}">
                                <i class="fas fa-check"></i>
                            </button>`;
                },
                "orderable": false, "searchable": false, "width": "60px"
            },
            { "data": "Codigo" },
            { "data": "Nombre" },
            { "data": "Descripcion" },
            { "data": "oCategoria", "render": d => d ? d.Descripcion : "" }
        ],
        "language": lenguajeDataTable()
    });

    $(document).on('click', '.sel-producto-oc', function () {
        $("#txtIdProducto").val($(this).data('id'));
        $("#txtCodigoProducto").val($(this).data('codigo'));
        $("#txtNombreProducto").val($(this).data('nombre'));
        var iva = $(this).data('iva');
        if (iva !== undefined && iva !== null && iva !== "") $("#txtIvaPorcentaje").val(iva);
        $('#modalProducto').modal('hide');
    });
}

function buscarProveedor() { $('#modalProveedor').modal('show'); }
function buscarTienda()    { $('#modalTienda').modal('show'); }
function buscarProducto()  { $('#modalProducto').modal('show'); }

function recargarProductosPorTienda(idTienda) {
    try {
        if (tablaproducto) {
            var url = $.MisUrls.url._ObtenerProductosPorTienda || $.MisUrls.url._ObtenerProductos;
            tablaproducto.ajax.url(url + (idTienda > 0 ? '?IdTienda=' + idTienda : '')).load();
        }
    } catch (e) {
        console.error("Error al recargar productos:", e);
    }
}

function cargarTiendaAutomatica(idTienda) {
    $.ajax({
        url: $.MisUrls.url._ObtenerTiendas,
        type: "GET",
        dataType: "json",
        success: function (data) {
            if (data && data.data) {
                var t = data.data.find(x => x.IdTienda == idTienda);
                if (t) {
                    $("#txtIdTienda").val(t.IdTienda);
                    $("#txtRucTienda").val(t.RUC);
                    $("#txtNombreTienda").val(t.Nombre);
                }
            }
        }
    });
}

// ═══════════════════════════════════════════════════════
//  LÓGICA DE DETALLE
// ═══════════════════════════════════════════════════════

function agregarItem() {
    var idProducto = parseInt($("#txtIdProducto").val()) || 0;
    var codigo     = $("#txtCodigoProducto").val().trim();
    var nombre     = $("#txtNombreProducto").val().trim();
    var cantidad   = parseInt($("#txtCantidad").val()) || 0;
    var precio     = parseFloat(($("#txtPrecioUnitario").val() || "0").replace(",", "."));
    var iva        = parseFloat(($("#txtIvaPorcentaje").val() || "0").replace(",", "."));

    if (idProducto <= 0) { Swal.fire({title: "Mensaje", text: "Debe seleccionar un producto", icon: "warning"}); return; }
    if (cantidad <= 0)   { Swal.fire({title: "Mensaje", text: "La cantidad debe ser mayor a 0", icon: "warning"}); return; }
    if (precio <= 0)     { Swal.fire({title: "Mensaje", text: "El precio unitario debe ser mayor a 0", icon: "warning"}); return; }

    // Evitar duplicados
    var existe = false;
    $("#tbDetalle tbody tr").each(function () {
        if ($(this).data("idproducto") == idProducto) existe = true;
    });
    if (existe) { Swal.fire({title: "Mensaje", text: "El producto ya está en el detalle", icon: "warning"}); return; }

    var totalLinea = cantidad * precio;
    var totalLineaIva = totalLinea * (1 + iva / 100);

    var tr = `<tr data-idproducto="${idProducto}"
                  data-cantidad="${cantidad}"
                  data-precio="${precio}"
                  data-iva="${iva}"
                  data-totallinea="${totalLinea}"
                  data-totallineaiva="${totalLineaIva}">
            <td><button class="btn btn-danger btn-sm"><i class="fas fa-trash"></i></button></td>
            <td>${codigo}</td>
            <td>${nombre}</td>
            <td>${cantidad}</td>
            <td>${formatNum(precio)}</td>
            <td>${iva}</td>
            <td>${formatNum(totalLinea)}</td>
            <td>${formatNum(totalLineaIva)}</td>
        </tr>`;
    $("#tbDetalle tbody").append(tr);

    limpiarProducto();
    recalcularTotales();
}

function limpiarProducto() {
    $("#txtIdProducto").val(0);
    $("#txtCodigoProducto").val("");
    $("#txtNombreProducto").val("");
    $("#txtCantidad").val(0);
    $("#txtPrecioUnitario").val(0);
    $("#txtIvaPorcentaje").val(10);
}

function recalcularTotales() {
    var totalCantidad = 0, totalLinea = 0, totalLineaIva = 0;
    $("#tbDetalle tbody tr").each(function () {
        totalCantidad += parseInt($(this).data("cantidad")) || 0;
        totalLinea     += parseFloat($(this).data("totallinea")) || 0;
        totalLineaIva  += parseFloat($(this).data("totallineaiva")) || 0;
    });
    $("#tfCantidad").text(totalCantidad);
    $("#tfTotal").text(formatNum(totalLinea));
    $("#tfTotalIva").text(formatNum(totalLineaIva));
}

function formatNum(n) {
    n = Number(n || 0);
    return n.toLocaleString('es-PY', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

// ═══════════════════════════════════════════════════════
//  GUARDAR
// ═══════════════════════════════════════════════════════

function guardarOrden() {
    var idProveedor      = parseInt($("#txtIdProveedor").val()) || 0;
    var idTienda         = parseInt($("#txtIdTienda").val()) || 0;
    var fechaEntrega     = $("#txtFechaEntrega").val().trim();
    var observacion      = $("#txtObservacion").val().trim();
    var idCategoriaOC    = parseInt($("#cboCategoria").val()) || 0;
    var fechaTopeEntrega = $("#txtFechaTopeEntrega").val().trim();

    if (idProveedor <= 0) { Swal.fire({title: "Mensaje", text: "Debe seleccionar un proveedor", icon: "warning"}); return; }
    if (idTienda <= 0)    { Swal.fire({title: "Mensaje", text: "Debe seleccionar una tienda", icon: "warning"}); return; }

    var detalle = [];
    $("#tbDetalle tbody tr").each(function () {
        detalle.push({
            oProducto:    { IdProducto: parseInt($(this).data("idproducto")) },
            Cantidad:     parseInt($(this).data("cantidad")),
            PrecioUnitario: parseFloat($(this).data("precio")),
            IvaPorcentaje:  parseFloat($(this).data("iva")),
            TotalLinea:     parseFloat($(this).data("totallinea")),
            TotalLineaIva:  parseFloat($(this).data("totallineaiva"))
        });
    });

    if (detalle.length === 0) {
        Swal.fire({title: "Mensaje", text: "Debe agregar al menos un producto", icon: "warning"});
        return;
    }

    Swal.fire({
        title: "¿Guardar la Orden de Compra?",
        text: "Quedará en estado Pendiente de aprobación.",
        icon: "info",
        showCancelButton: true,
        confirmButtonText: "Confirmar",
        cancelButtonText: "Cancelar"
    }).then(function (result) {
        if (!result.isConfirmed) return;

        $.ajax({
            url: $.MisUrls.url._OC_Guardar,
            type: "POST",
            dataType: "json",
            data: {
                idproveedor:      idProveedor,
                idtienda:         idTienda,
                fechaentrega:     fechaEntrega,
                observacion:      observacion,
                idcategoriaoc:    idCategoriaOC,
                fechatopeentrega: fechaTopeEntrega,
                detalle:          detalle
            },
            traditional: false,
            beforeSend: function () { $("body").LoadingOverlay("show"); },
            complete:   function () { $("body").LoadingOverlay("hide"); },
            success: function (resp) {
                if (resp.resultado) {
                    Swal.fire({title: "Éxito", text: resp.mensaje || "Orden registrada", icon: "success"})
                        .then(() => { window.location.href = $.MisUrls.url._OC_Consultar; });
                } else {
                    Swal.fire({title: "Error", text: resp.mensaje || "No se pudo registrar la orden", icon: "error"});
                }
            },
            error: function (xhr) {
                Swal.fire({title: "Error", text: "Error de comunicación con el servidor", icon: "error"});
            }
        });
    });
}
