// ══════════════════════════════════════════════════════════════════════
//  OrdenPago_Aprobar.js
//  Aprobación / Rechazo de Órdenes de Pago — vista Supervisor
// ══════════════════════════════════════════════════════════════════════

var tablaOP;

function formatGs(valor) {
    return "Gs. " + (valor || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1.");
}

function badgeAprob(estado) {
    var map = {
        "Pendiente":  "badge badge-warning",
        "Aprobada":   "badge badge-success",
        "Rechazada":  "badge badge-danger"
    };
    return '<span class="' + (map[estado] || "badge badge-secondary") + '">' + (estado || "—") + "</span>";
}

$(document).ready(function () {
    activarMenu("Compras");

    $.datepicker.setDefaults($.datepicker.regional["es"]);
    $("#txtFechaInicio").datepicker();
    $("#txtFechaFin").datepicker();

    var hoy       = ObtenerFechaHoy();
    var primerDia = ObtenerPrimerDiaMes();
    $("#txtFechaInicio").val(primerDia);
    $("#txtFechaFin").val(hoy);

    tablaOP = $("#tbOrdenesPago").DataTable({
        ajax: {
            url:      construirUrl(primerDia, hoy, "Pendiente"),
            type:     "GET",
            datatype: "json"
        },
        columns: [
            {
                data:       null,
                orderable:  false,
                searchable: false,
                render: function (data, type, row) {
                    var btns = '<button class="btn btn-info btn-sm mr-1" title="Ver documento" '
                             + 'onclick="verDocumento(' + row.IdOrdenPago + ')">'
                             + '<i class="fas fa-file-alt"></i></button>';

                    if (row.EstadoAprobacion === "Pendiente" && row.Estado !== "Anulada") {
                        btns += '<button class="btn btn-success btn-sm mr-1" title="Aprobar" '
                              + 'onclick="aprobar(' + row.IdOrdenPago + ', \'' + row.NumeroOP + '\')">'
                              + '<i class="fas fa-check"></i></button>';
                        btns += '<button class="btn btn-danger btn-sm" title="Rechazar" '
                              + 'onclick="abrirRechazo(' + row.IdOrdenPago + ')">'
                              + '<i class="fas fa-times"></i></button>';
                    }

                    // Botón Pagar: solo para Contado + Aprobada + no Pagada/Anulada
                    if (row.EstadoAprobacion === "Aprobada"
                            && row.ModalidadPago === "Contado"
                            && row.Estado !== "Pagada"
                            && row.Estado !== "Anulada") {
                        btns += '<button class="btn btn-primary btn-sm ml-1" title="Registrar Pago" '
                              + 'onclick="registrarPago(' + row.IdOrdenPago + ', \'' + row.NumeroOP + '\')">'
                              + '<i class="fas fa-hand-holding-usd"></i> Pagar</button>';
                    }
                    return btns;
                }
            },
            { data: "NumeroOP" },
            { data: "oCompra",    render: function (d) { return d ? d.NumeroFactura : "—"; } },
            { data: "oProveedor", render: function (d) { return d ? d.RazonSocial  : "—"; } },
            { data: "Monto",      render: function (d) { return formatGs(d); }, className: "text-right" },
            { data: "ModalidadPago" },
            { data: "NumeroCuotas", render: function (d) { return d || "—"; } },
            { data: "EstadoAprobacion", render: function (d) { return badgeAprob(d); } },
            { data: "FechaEmisionTexto", defaultContent: "—" },
            { data: "oUsuarioEmite", render: function (d) { return d ? d.Nombres : "—"; } }
        ],
        language:   { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true,
        order:      [[1, "desc"]]
    });
});

function construirUrl(fi, ff, estado) {
    return $.MisUrls.url._OP_ObtenerAprobacion
         + "?fechainicio=" + fi
         + "&fechafin="    + ff
         + "&estadoaprobacion=" + (estado || "Pendiente");
}

function buscar() {
    var fi     = $("#txtFechaInicio").val().trim();
    var ff     = $("#txtFechaFin").val().trim();
    var estado = $("#cboEstadoAprob").val();

    if (!fi || !ff) {
        Swal.fire({ title: "Atención", text: "Ingrese las fechas.", icon: "warning" });
        return;
    }
    tablaOP.ajax.url(construirUrl(fi, ff, estado)).load();
}

function verDocumento(idOP) {
    window.open($.MisUrls.url._OP_Documento + "?idordenpago=" + idOP, "_blank");
}

function aprobar(idOP, numeroOP) {
    Swal.fire({
        title:              "¿Aprobar " + numeroOP + "?",
        html:               "La Orden de Pago quedará vigente.<br>"
                          + "<small class='text-muted'>Si es Crédito, se generará el cronograma de cuotas automáticamente.</small>",
        icon:               "question",
        showCancelButton:   true,
        confirmButtonColor: "#28a745",
        cancelButtonColor:  "#6c757d",
        confirmButtonText:  "Sí, aprobar",
        cancelButtonText:   "Cancelar"
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:  $.MisUrls.url._OP_Aprobar,
            type: "POST",
            data: { idordenpago: idOP },
            success: function (res) {
                if (res.resultado) {
                    Swal.fire({ title: "Aprobada", text: res.mensaje, icon: "success" })
                        .then(function () { buscar(); });
                } else {
                    Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
                }
            },
            error: function () {
                Swal.fire({ title: "Error", text: "Error de comunicación.", icon: "error" });
            }
        });
    });
}

function abrirRechazo(idOP) {
    $("#hdnIdOPRechazo").val(idOP);
    $("#txtMotivoRechazo").val("");
    $("#modalRechazo").modal("show");
}

function confirmarRechazo() {
    var idOP   = parseInt($("#hdnIdOPRechazo").val());
    var motivo = $("#txtMotivoRechazo").val().trim();

    if (!motivo) {
        Swal.fire({ title: "Atención", text: "Debe ingresar un motivo de rechazo.", icon: "warning" });
        return;
    }

    $.ajax({
        url:  $.MisUrls.url._OP_Rechazar,
        type: "POST",
        data: { idordenpago: idOP, motivo: motivo },
        success: function (res) {
            $("#modalRechazo").modal("hide");
            if (res.resultado) {
                Swal.fire({ title: "Rechazada", text: res.mensaje, icon: "info" })
                    .then(function () { buscar(); });
            } else {
                Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
            }
        },
        error: function () {
            Swal.fire({ title: "Error", text: "Error de comunicación.", icon: "error" });
        }
    });
}

function registrarPago(idOP, numeroOP) {
    Swal.fire({
        title:              "¿Registrar pago de " + numeroOP + "?",
        html:               "Esto marcará la Orden de Pago como <strong>Pagada</strong>.<br>"
                          + "<small class='text-muted'>Esta acción no se puede deshacer.</small>",
        icon:               "question",
        showCancelButton:   true,
        confirmButtonColor: "#007bff",
        cancelButtonColor:  "#6c757d",
        confirmButtonText:  "Sí, registrar pago",
        cancelButtonText:   "Cancelar"
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:  $.MisUrls.url._OP_RegistrarPago,
            type: "POST",
            data: { idordenpago: idOP },
            success: function (res) {
                if (res.resultado) {
                    Swal.fire({ title: "Pagada", text: res.mensaje, icon: "success" })
                        .then(function () { buscar(); });
                } else {
                    Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
                }
            },
            error: function () {
                Swal.fire({ title: "Error", text: "Error de comunicación.", icon: "error" });
            }
        });
    });
}

function ObtenerFechaHoy() {
    var d = new Date(), m = d.getMonth() + 1, day = d.getDate();
    return (day < 10 ? "0" : "") + day + "/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}
function ObtenerPrimerDiaMes() {
    var d = new Date(), m = d.getMonth() + 1;
    return "01/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}
