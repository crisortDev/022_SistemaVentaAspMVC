// ══════════════════════════════════════════════════════════════════════
//  OrdenPago_CuentasPorPagar.js
//  Listado de pagos a proveedores (Contado y Crédito)
// ══════════════════════════════════════════════════════════════════════

var tablaCXP;

function formatGs(valor) {
    return "Gs. " + (valor || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1.");
}

function badgeEstadoCXP(estado) {
    var map = {
        "Pendiente": "badge badge-warning",
        "Vencida":   "badge badge-danger",
        "Pagada":    "badge badge-success"
    };
    return '<span class="' + (map[estado] || "badge badge-secondary") + '">' + (estado || "—") + "</span>";
}

$(document).ready(function () {
    activarMenu("Compras");

    // Cargar proveedores
    $.ajax({
        url:     $.MisUrls.url._OC_ObtenerProveedores,
        type:    "GET",
        success: function (data) {
            if (data.data) {
                $.each(data.data, function (i, p) {
                    if (p.Activo) {
                        $("<option>").attr({ value: p.IdProveedor }).text(p.RazonSocial)
                                    .appendTo("#cboProveedor");
                    }
                });
            }
        }
    });

    tablaCXP = $("#tbCXP").DataTable({
        ajax: {
            url:      construirUrl(0, "Pendiente"),
            type:     "GET",
            datatype: "json"
        },
        columns: [
            {
                data:       null,
                orderable:  false,
                searchable: false,
                render: function (data, type, row) {
                    if (row.Estado === "Pagada") {
                        return '<span class="text-success"><i class="fas fa-check-circle"></i></span>';
                    }
                    var esContado = (row.ModalidadPago === "Contado");
                    var titulo = esContado ? "Registrar Pago" : ("Registrar Pago Cuota " + row.NumeroCuota + "/" + row.TotalCuotas);
                    return '<button class="btn btn-primary btn-sm" title="' + titulo + '" '
                         + 'onclick="registrarPagoCuota(' + row.IdCuentaPorPagar
                         + ', ' + row.NumeroCuota + ', ' + row.TotalCuotas
                         + ', \'' + (row.ModalidadPago || "Credito") + '\')">'
                         + '<i class="fas fa-hand-holding-usd"></i> Pagar</button>';
                }
            },
            { data: "NumeroOP",              defaultContent: "—" },
            { data: "NumeroFactura",         defaultContent: "—" },
            { data: "oProveedor", render: function (d) { return d ? d.RazonSocial : "—"; } },
            {
                // Columna Modalidad
                data: "ModalidadPago",
                render: function (d) {
                    if (d === "Contado") {
                        return '<span class="badge badge-info">Contado</span>';
                    }
                    return '<span class="badge badge-secondary">Crédito</span>';
                }
            },
            {
                // Cuota / Pago único
                data: null,
                render: function (d) {
                    if (d.ModalidadPago === "Contado") {
                        return '<span class="text-muted small">Pago único</span>';
                    }
                    return "Cuota " + d.NumeroCuota + " / " + d.TotalCuotas;
                }
            },
            { data: "FechaVencimientoTexto", defaultContent: "—" },
            { data: "Monto", render: function (d) { return formatGs(d); }, className: "text-right" },
            { data: "Estado", render: function (d) { return badgeEstadoCXP(d); } },
            {
                data: "FechaPago",
                render: function (d) {
                    if (!d) return '<span class="text-muted">—</span>';
                    var fecha = new Date(parseInt(d.replace(/\/Date\((\d+)\)\//, "$1")));
                    return fecha.toLocaleDateString("es-PY");
                }
            }
        ],
        language:   { url: $.MisUrls.url.Url_datatable_spanish },
        responsive: true,
        order:      [[6, "asc"]]  // ordenar por vencimiento ascendente (col 6 ahora)
    });
});

function construirUrl(idProveedor, estado) {
    return $.MisUrls.url._OP_ObtenerCXP
         + "?idproveedor=" + (idProveedor || 0)
         + "&estado="      + (estado || "Pendiente");
}

function buscar() {
    var prov   = parseInt($("#cboProveedor").val()) || 0;
    var estado = $("#cboEstadoCXP").val();
    tablaCXP.ajax.url(construirUrl(prov, estado)).load();
}

function registrarPagoCuota(idCXP, numeroCuota, totalCuotas, modalidad) {
    var esContado = (modalidad === "Contado");
    var titulo    = esContado
        ? "¿Registrar pago al contado?"
        : "¿Registrar pago de Cuota " + numeroCuota + "/" + totalCuotas + "?";
    var html = esContado
        ? "Se marcará la Orden de Pago como <strong>Pagada</strong>."
        : "Se marcará esta cuota como <strong>Pagada</strong>."
          + (numeroCuota === totalCuotas
              ? "<br><small class='text-success'>Es la última cuota — la OP quedará cerrada.</small>"
              : "");

    Swal.fire({
        title:              titulo,
        html:               html,
        icon:               "question",
        showCancelButton:   true,
        confirmButtonColor: "#007bff",
        cancelButtonColor:  "#6c757d",
        confirmButtonText:  "Sí, registrar pago",
        cancelButtonText:   "Cancelar"
    }).then(function (r) {
        if (!r.isConfirmed) return;
        $.ajax({
            url:  $.MisUrls.url._OP_RegistrarPagoCuota,
            type: "POST",
            data: { idcuentaporpagar: idCXP },
            success: function (res) {
                if (res.resultado) {
                    Swal.fire({ title: "Pagado", text: res.mensaje, icon: "success" })
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
