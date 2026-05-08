// ══════════════════════════════════════════════════════════════════════
//  Compra_Consultar.js
//  Vista informativa de facturas de compra con detalle expandible y NC
// ══════════════════════════════════════════════════════════════════════

var tablaConsulta;

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

function formatGs(valor) {
    return (valor || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1.');
}

function badgeEstado(estado) {
    var clases = {
        'Pendiente':  'badge badge-warning',
        'Confirmada': 'badge badge-success',
        'Anulada':    'badge badge-danger'
    };
    return '<span class="' + (clases[estado] || 'badge badge-secondary') + '">'
         + (estado || '—') + '</span>';
}

function badgeLineaEstado(estado) {
    var clases = {
        'Aceptada':  'badge badge-success',
        'NC':        'badge badge-warning',
        'Rechazada': 'badge badge-danger',
        'Pendiente': 'badge badge-secondary'
    };
    return '<span class="' + (clases[estado] || 'badge badge-secondary') + '">'
         + (estado || '—') + '</span>';
}

// ── Genera el HTML del child row con las líneas de la factura ─────────
function construirDetalleHTML(lineas) {
    if (!lineas || lineas.length === 0) {
        return '<div class="p-2 text-muted"><em>Sin líneas de detalle.</em></div>';
    }

    var html = '<div class="p-2">'
             + '<table class="table table-sm table-bordered mb-0" style="background:#f9fafb">'
             + '<thead class="thead-light"><tr>'
             + '<th>Producto</th>'
             + '<th class="text-center">Cant. Pedida</th>'
             + '<th class="text-center">Cant. Recibida</th>'
             + '<th class="text-center">Diferencia</th>'
             + '<th class="text-right">Precio Unit.</th>'
             + '<th class="text-right">Total Línea</th>'
             + '<th class="text-center">Estado Línea</th>'
             + '</tr></thead><tbody>';

    $.each(lineas, function (i, l) {
        var pedida   = l.Cantidad        || 0;
        var recibida = l.CantidadRecibida != null ? l.CantidadRecibida : pedida;
        var diff     = pedida - recibida;
        var diffCell = diff > 0
            ? '<span class="text-danger font-weight-bold">-' + diff + '</span>'
            : '<span class="text-success">0</span>';

        html += '<tr>'
             + '<td>' + (l.oProducto ? l.oProducto.Nombre : '—') + '</td>'
             + '<td class="text-center">' + pedida + '</td>'
             + '<td class="text-center">' + recibida + '</td>'
             + '<td class="text-center">' + diffCell + '</td>'
             + '<td class="text-right">Gs. ' + formatGs(l.PrecioUnitarioCompra) + '</td>'
             + '<td class="text-right">Gs. ' + formatGs(l.TotalCosto) + '</td>'
             + '<td class="text-center">' + badgeLineaEstado(l.EstadoLinea) + '</td>'
             + '</tr>';
    });

    html += '</tbody></table></div>';
    return html;
}

// ── Inicialización ────────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Compras");

    $.datepicker.setDefaults($.datepicker.regional['es']);
    $("#txtFechaInicio").datepicker();
    $("#txtFechaFin").datepicker();

    var hoy       = ObtenerFechaHoy();
    var primerDia = ObtenerPrimerDiaMes();
    $("#txtFechaInicio").val(primerDia);
    $("#txtFechaFin").val(hoy);

    if (!AppSession.esSuperAdmin) $("#divFiltroTienda").hide();

    // Proveedores
    $.ajax({
        url: $.MisUrls.url._ObtenerProveedores,
        type: "GET",
        success: function (data) {
            $("#cboProveedor").html("");
            $("<option>").attr({ value: 0 }).text("-- Todos --").appendTo("#cboProveedor");
            if (data.data) {
                $.each(data.data, function (i, p) {
                    if (p.Activo) {
                        $("<option>").attr({ value: p.IdProveedor })
                                     .text(p.RazonSocial)
                                     .appendTo("#cboProveedor");
                    }
                });
            }
        }
    });

    // Tiendas (SuperAdmin)
    if (AppSession.esSuperAdmin) {
        $.ajax({
            url: $.MisUrls.url._ObtenerTiendas,
            type: "GET",
            success: function (data) {
                $("#cboTienda").html("");
                $("<option>").attr({ value: 0 }).text("-- Todas --").appendTo("#cboTienda");
                if (data.data) {
                    $.each(data.data, function (i, t) {
                        if (t.Activo) {
                            $("<option>").attr({ value: t.IdTienda })
                                         .text(t.Nombre)
                                         .appendTo("#cboTienda");
                        }
                    });
                }
            }
        });
    }

    var idTiendaIni = AppSession.esSuperAdmin ? 0 : AppSession.idTienda;

    tablaConsulta = $('#tbCompras').DataTable({
        "ajax": {
            "url":      construirUrl(primerDia, hoy, 0, idTiendaIni, "Todos"),
            "type":     "GET",
            "datatype": "json"
        },
        "columns": [
            {
                // Columna expand/collapse
                "className":  "details-control",
                "orderable":  false,
                "searchable": false,
                "data":       null,
                "defaultContent": "<i class='fas fa-plus-circle text-secondary' style='cursor:pointer'></i>"
            },
            { "data": "NumeroCompra" },
            { "data": "NumeroFactura", "defaultContent": "—" },
            { "data": "oProveedor",    "render": function (d) { return d ? d.RazonSocial : "—"; } },
            { "data": "oTienda",       "render": function (d) { return d ? d.Nombre      : "—"; } },
            { "data": "FechaFactura",  "defaultContent": "—" },
            { "data": "NumeroOrden",   "defaultContent": "—" },
            {
                "data": "TotalCosto",
                "render": function (d) { return "Gs. " + formatGs(d); },
                "className": "text-right"
            },
            {
                // Nota de Crédito
                "data": null,
                "orderable": false,
                "render": function (data, type, row) {
                    if (row.MontoNotaCredito && row.MontoNotaCredito > 0) {
                        return "<span class='badge badge-warning'>"
                             + "<i class='fas fa-file-invoice-dollar'></i> "
                             + "Gs. " + formatGs(row.MontoNotaCredito) + "</span>";
                    }
                    return "<span class='text-muted small'>Sin NC</span>";
                }
            },
            {
                "data": "Estado",
                "render": function (d) { return badgeEstado(d); }
            },
            { "data": "UsuarioRegistro", "defaultContent": "—" },
            {
                // Botón documento PDF
                "data": "IdCompra",
                "orderable": false,
                "render": function (d) {
                    return "<button class='btn btn-info btn-sm' title='Ver documento PDF' "
                         + "onclick='verDocumento(" + d + ")'>"
                         + "<i class='fas fa-file-alt'></i></button>";
                }
            }
        ],
        "language":   lenguajeDataTable(),
        "responsive": true,
        "order":      [[1, "desc"]]
    });

    // ── Click en la columna "+" para expandir child row ───────────────
    $('#tbCompras tbody').on('click', 'td.details-control', function () {
        var tr  = $(this).closest('tr');
        var row = tablaConsulta.row(tr);

        if (row.child.isShown()) {
            // Cerrar
            row.child.hide();
            tr.removeClass('shown');
            $(this).find('i').removeClass('fa-minus-circle text-primary')
                              .addClass('fa-plus-circle text-secondary');
        } else {
            // Abrir — cargar detalle por AJAX
            var idCompra = row.data().IdCompra;
            row.child('<div class="p-2 text-muted"><i class="fas fa-spinner fa-spin"></i> Cargando líneas...</div>').show();
            tr.addClass('shown');
            $(this).find('i').removeClass('fa-plus-circle text-secondary')
                              .addClass('fa-minus-circle text-primary');

            $.ajax({
                url:  $.MisUrls.url._Compra_DetalleJson + "?idcompra=" + idCompra,
                type: "GET",
                success: function (res) {
                    row.child(construirDetalleHTML(res.data)).show();
                },
                error: function () {
                    row.child('<div class="p-2 text-danger">Error al cargar el detalle.</div>').show();
                }
            });
        }
    });
});

// ── Construir URL ─────────────────────────────────────────────────────
function construirUrl(fi, ff, prov, tienda, estado) {
    return $.MisUrls.url._Compra_ObtenerConsulta
         + "?fechainicio=" + fi
         + "&fechafin="    + ff
         + "&idproveedor=" + prov
         + "&idtienda="    + tienda
         + "&estado="      + (estado || "Todos");
}

// ── Buscar ────────────────────────────────────────────────────────────
function buscar() {
    var fi     = $("#txtFechaInicio").val().trim();
    var ff     = $("#txtFechaFin").val().trim();
    var prov   = parseInt($("#cboProveedor").val()) || 0;
    var tienda = AppSession.esSuperAdmin ? (parseInt($("#cboTienda").val()) || 0) : AppSession.idTienda;
    var estado = $("#cboEstado").val() || "Todos";

    if (!fi || !ff) {
        Swal.fire({ title: "Atención", text: "Debe ingresar fechas.", icon: "warning" });
        return;
    }

    tablaConsulta.ajax.url(construirUrl(fi, ff, prov, tienda, estado)).load();
}

// ── Ver documento PDF ─────────────────────────────────────────────────
function verDocumento(id) {
    window.open($.MisUrls.url._Compra_Documento + "?idcompra=" + id, "_blank");
}

// ── Utilidades de fecha ───────────────────────────────────────────────
function ObtenerFechaHoy() {
    var d   = new Date();
    var m   = d.getMonth() + 1;
    var day = d.getDate();
    return (day < 10 ? "0" : "") + day + "/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}

function ObtenerPrimerDiaMes() {
    var d = new Date();
    var m = d.getMonth() + 1;
    return "01/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}
