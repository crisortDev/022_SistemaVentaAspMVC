// ══════════════════════════════════════════════════════════════════════
//  Compra_Revision.js
//  Segregación O&M — Revisión (Confirmación / Anulación) de Facturas
// ══════════════════════════════════════════════════════════════════════

var tablaRevision;

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

// ── Colores de badge por estado ───────────────────────────────────────
function badgeEstado(estado) {
    var clases = {
        'Pendiente':  'badge badge-warning',
        'Confirmada': 'badge badge-success',
        'Anulada':    'badge badge-danger'
    };
    return '<span class="' + (clases[estado] || 'badge badge-secondary') + '">'
         + (estado || '—') + '</span>';
}

function formatGs(valor) {
    return (valor || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1.');
}

// ── Inicialización ────────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Compras");

    // Datepicker
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $("#txtFechaInicio").datepicker();
    $("#txtFechaFin").datepicker();

    var hoy        = ObtenerFechaHoy();
    var primerDia  = ObtenerPrimerDiaMes();
    $("#txtFechaInicio").val(primerDia);
    $("#txtFechaFin").val(hoy);

    // Ocultar filtro tienda si no es SuperAdmin
    if (!AppSession.esSuperAdmin) $("#divFiltroTienda").hide();

    // Cargar proveedores
    $.ajax({
        url:     $.MisUrls.url._OC_ObtenerProveedores,
        type:    "GET",
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

    // Cargar tiendas (solo SuperAdmin)
    if (AppSession.esSuperAdmin) {
        $.ajax({
            url:     $.MisUrls.url._ObtenerTiendas,
            type:    "GET",
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

    // DataTable inicial — compras Pendientes del mes actual
    var idTiendaIni = AppSession.esSuperAdmin ? 0 : AppSession.idTienda;

    tablaRevision = $('#tbCompras').DataTable({
        "ajax": {
            "url":      construirUrl(primerDia, hoy, 0, idTiendaIni, ""),
            "type":     "GET",
            "datatype": "json"
        },
        "columns": [
            {
                // Columna acciones
                "data":       null,
                "orderable":  false,
                "searchable": false,
                "render": function (data, type, row) {
                    // Ver Documento: deshabilitado si NC está Pendiente (esperando al proveedor)
                    var btnDoc;
                    if (row.EstadoNC === "Pendiente") {
                        btnDoc = "<button class='btn btn-info btn-sm mr-1' disabled "
                               + "title='NC Pendiente — Ver documento disponible una vez recibida la NC del proveedor' "
                               + "style='opacity:0.45;cursor:not-allowed'>"
                               + "<i class='fas fa-file-alt'></i></button>";
                    } else {
                        btnDoc = "<button class='btn btn-info btn-sm mr-1' title='Ver documento' "
                               + "onclick='verDocumento(" + row.IdCompra + ")'>"
                               + "<i class='fas fa-file-alt'></i></button>";
                    }

                    var btnConf = "";
                    var btnAnul = "";
                    var btnNC   = "";

                    if (row.Estado === "Pendiente") {
                        // Confirmar: bloqueado hasta que NC sea generada (si corresponde)
                        if (row.NecesitaNC) {
                            btnConf = "<button class='btn btn-success btn-sm mr-1' disabled "
                                    + "title='Genere primero la Nota de Crédito (diferencia de cantidades pendiente)' "
                                    + "style='opacity:0.45;cursor:not-allowed'>"
                                    + "<i class='fas fa-check'></i></button>";
                        } else {
                            btnConf = "<button class='btn btn-success btn-sm mr-1' title='Confirmar Compra' "
                                    + "onclick='confirmarCompra(" + row.IdCompra + ")'>"
                                    + "<i class='fas fa-check'></i></button>";
                        }

                        btnAnul = "<button class='btn btn-danger btn-sm mr-1' title='Anular' "
                                + "onclick='abrirModalAnular(" + row.IdCompra + ")'>"
                                + "<i class='fas fa-ban'></i></button>";
                    }

                    // Botón NC: solo si hay diferencia de cantidades sin NC generada
                    if (row.NecesitaNC) {
                        btnNC = "<button class='btn btn-warning btn-sm mr-1' "
                              + "title='Generar Nota de Crédito — Diferencia en cantidades' "
                              + "onclick='abrirModalNC(" + row.IdCompra + ")'>"
                              + "<i class='fas fa-file-invoice-dollar'></i> NC</button>";
                    }

                    // Botón OP: solo Encargado (6) y SuperAdmin pueden generar
                    // Bloqueado además si la NC de compra está Pendiente (aún no fue recibida del proveedor)
                    var btnOP = "";
                    var puedeGenerarOP = AppSession.esSuperAdmin || AppSession.idRol === 6;
                    var ncPendiente = row.EstadoNC === "Pendiente";
                    if (puedeGenerarOP && row.Estado === "Confirmada" && (!row.IdOrdenPago || row.IdOrdenPago === 0) && (row.TotalCosto > 0 || row.MontoNotaCredito > 0)) {
                        if (ncPendiente) {
                            btnOP = "<button class='btn btn-primary btn-sm mr-1' disabled "
                                  + "title='Espere la NC del proveedor (NC Pendiente) antes de generar la Orden de Pago' "
                                  + "style='opacity:0.45;cursor:not-allowed'>"
                                  + "<i class='fas fa-money-check-alt'></i></button>";
                        } else {
                            btnOP = "<button class='btn btn-primary btn-sm mr-1' title='Generar Orden de Pago' "
                                  + "onclick='generarOrdenPago(" + row.IdCompra + ")'>"
                                  + "<i class='fas fa-money-check-alt'></i></button>";
                        }
                    }

                    return btnDoc + btnConf + btnAnul + btnNC + btnOP;
                }
            },
            { "data": "NumeroCompra" },
            { "data": "NumeroFactura", "defaultContent": "—" },
            { "data": "oProveedor",   "render": function (d) { return d ? d.RazonSocial : "—"; } },
            { "data": "oTienda",      "render": function (d) { return d ? d.Nombre      : "—"; } },
            { "data": "FechaFactura",  "defaultContent": "—" },
            { "data": "FechaEntrega",  "defaultContent": "—" },
            { "data": "NumeroOrden",   "defaultContent": "—" },
            {
                "data": "TotalCosto",
                "render": function (d, t, row) {
                    if (row.MontoNotaCredito && row.MontoNotaCredito > 0) {
                        if (d > 0) {
                            var neto = d - row.MontoNotaCredito;
                            return "<span title='Bruto: Gs. " + formatGs(d) + "'>Gs. " + formatGs(neto) + "</span>"
                                 + " <small class='text-warning'>(NC - Gs. " + formatGs(row.MontoNotaCredito) + ")</small>";
                        }
                        // TotalCosto=0: dato previo sin total almacenado; muestra solo la NC
                        return "<span class='text-muted'>—</span>"
                             + " <small class='text-warning'>(NC: Gs. " + formatGs(row.MontoNotaCredito) + ")</small>";
                    }
                    return "Gs. " + formatGs(d);
                },
                "className": "text-right"
            },
            {
                "data": "Estado",
                "render": function (d) { return badgeEstado(d); }
            },
            { "data": "UsuarioRegistro", "defaultContent": "—" }
        ],
        "language":   lenguajeDataTable(),
        "responsive": true,
        "order":      [[1, "desc"]]
    });
});

// ── Construir URL de búsqueda ─────────────────────────────────────────
function construirUrl(fi, ff, prov, tienda, estado) {
    return $.MisUrls.url._Compra_ObtenerRevision
         + "?fechainicio=" + fi
         + "&fechafin="    + ff
         + "&idproveedor=" + prov
         + "&idtienda="    + tienda
         + "&estado="      + estado;
}

// ── Buscar ────────────────────────────────────────────────────────────
function buscarTodos() {
    $("#cboEstado").val("");
    buscar();
}

function buscar() {
    var fi     = $("#txtFechaInicio").val().trim();
    var ff     = $("#txtFechaFin").val().trim();
    var prov   = parseInt($("#cboProveedor").val()) || 0;
    var tienda = AppSession.esSuperAdmin ? (parseInt($("#cboTienda").val()) || 0) : AppSession.idTienda;
    var estado = $("#cboEstado").val();

    if (!fi || !ff) {
        Swal.fire({ title: "Atención", text: "Debe ingresar fechas.", icon: "warning" });
        return;
    }

    tablaRevision.ajax.url(construirUrl(fi, ff, prov, tienda, estado)).load();
}

// ── Ver documento ─────────────────────────────────────────────────────
function verDocumento(id) {
    window.open($.MisUrls.url._Compra_Documento + "?idcompra=" + id, "_blank");
}

// ── Confirmar compra ──────────────────────────────────────────────────
function confirmarCompra(id) {
    Swal.fire({
        title:              "¿Confirmar esta Factura?",
        html:               "Se impactará el stock y no podrá revertirse.<br>"
                          + "<small class='text-muted'>Solo puede confirmar facturas que <strong>usted no registró</strong>.</small>",
        icon:               "question",
        showCancelButton:   true,
        confirmButtonColor: "#28a745",
        cancelButtonColor:  "#6c757d",
        confirmButtonText:  "Sí, confirmar",
        cancelButtonText:   "Cancelar"
    }).then(function (result) {
        if (result.isConfirmed) {
            $.ajax({
                url:  $.MisUrls.url._Compra_Confirmar,
                type: "POST",
                data: { idcompra: id },
                success: function (res) {
                    if (res.resultado) {
                        Swal.fire({
                            title: "¡Confirmado!",
                            text:  res.mensaje || "Factura confirmada y stock actualizado.",
                            icon:  "success"
                        }).then(function () { buscarTodos(); });
                    } else {
                        Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
                    }
                },
                error: function () {
                    Swal.fire({ title: "Error", text: "Error de comunicación con el servidor.", icon: "error" });
                }
            });
        }
    });
}

// ── Modal anular ──────────────────────────────────────────────────────
function abrirModalAnular(id) {
    $("#hdnIdAnular").val(id);
    $("#txtMotivoAnular").val("");
    $("#modalAnular").modal("show");
}

function confirmarAnulacion() {
    var id     = parseInt($("#hdnIdAnular").val());
    var motivo = $("#txtMotivoAnular").val().trim();

    if (!motivo) {
        Swal.fire({ title: "Atención", text: "Debe ingresar un motivo.", icon: "warning" });
        return;
    }

    $.ajax({
        url:  $.MisUrls.url._Compra_Anular,
        type: "POST",
        data: { idcompra: id, motivo: motivo },
        success: function (res) {
            $("#modalAnular").modal("hide");
            if (res.resultado) {
                Swal.fire({
                    title: "Anulada",
                    text:  res.mensaje || "Compra anulada correctamente.",
                    icon:  "success"
                }).then(function () { buscarTodos(); });
            } else {
                Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
            }
        },
        error: function () {
            Swal.fire({ title: "Error", text: "Error de comunicación con el servidor.", icon: "error" });
        }
    });
}

// ── Modal Nota de Crédito ─────────────────────────────────────────────
function abrirModalNC(id) {
    $("#hdnIdNC").val(id);
    $("#cboMotivoNC").val(0);
    $("#modalNC").modal("show");
}

function confirmarGenerarNC() {
    var id      = parseInt($("#hdnIdNC").val());
    var idMotivo = parseInt($("#cboMotivoNC").val()) || 0;

    if (idMotivo <= 0) {
        Swal.fire({ title: "Atención", text: "Debe seleccionar un motivo de NC.", icon: "warning" });
        return;
    }

    $.ajax({
        url:  $.MisUrls.url._Compra_NotaCredito,
        type: "POST",
        data: { idcompra: id, idmotivoNC: idMotivo },
        success: function (res) {
            $("#modalNC").modal("hide");
            if (res.resultado) {
                Swal.fire({
                    title: "NC Generada",
                    text:  res.mensaje || "Nota de Crédito generada correctamente.",
                    icon:  "success"
                }).then(function () { buscarTodos(); });
            } else {
                Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
            }
        },
        error: function () {
            Swal.fire({ title: "Error", text: "Error de comunicación con el servidor.", icon: "error" });
        }
    });
}

// ── Generar Orden de Pago ─────────────────────────────────────────────
function generarOrdenPago(id) {
    $("#hdnIdOP").val(id);
    $("#cboModalidadOP").val("Contado");
    $("#divCuotas").hide();
    $("#txtNumeroCuotas").val("");
    $("#modalGenerarOP").modal("show");
}

function _cambioModalidadOP() {
    if ($("#cboModalidadOP").val() === "Credito") {
        $("#divCuotas").show();
        $("#txtNumeroCuotas").focus();
    } else {
        $("#divCuotas").hide();
        $("#txtNumeroCuotas").val("");
    }
}

function _confirmarGenerarOP() {
    var id        = parseInt($("#hdnIdOP").val());
    var modalidad = $("#cboModalidadOP").val();
    var cuotas    = parseInt($("#txtNumeroCuotas").val()) || 0;

    if (modalidad === "Credito") {
        if (isNaN(cuotas) || cuotas < 2 || cuotas !== Math.floor(cuotas)) {
            Swal.fire({ title: "Atención", text: "Ingrese un número entero de cuotas mínimo 2.", icon: "warning" });
            return;
        }
    }

    $("#modalGenerarOP").modal("hide");

    $.ajax({
        url:  $.MisUrls.url._Compra_GenerarOP,
        type: "POST",
        data: {
            idcompra:      id,
            modalidadPago: modalidad,
            numeroCuotas:  modalidad === "Credito" ? cuotas : null
        },
        success: function (res) {
            if (res.resultado) {
                Swal.fire({
                    title:             "¡Orden de Pago Generada!",
                    html:              (res.mensaje || "Orden de Pago creada correctamente.")
                                     + "<br><small class='text-muted'>Queda pendiente de aprobación del supervisor.</small>",
                    icon:              "success",
                    showCancelButton:  true,
                    confirmButtonText: "Ver Documento",
                    cancelButtonText:  "Cerrar"
                }).then(function (r) {
                    if (r.isConfirmed && res.idgenerado) {
                        window.open($.MisUrls.url._OP_Documento + "?idordenpago=" + res.idgenerado, "_blank");
                    }
                    buscarTodos();
                });
            } else {
                Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
            }
        },
        error: function () {
            Swal.fire({ title: "Error", text: "Error de comunicación con el servidor.", icon: "error" });
        }
    });
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
