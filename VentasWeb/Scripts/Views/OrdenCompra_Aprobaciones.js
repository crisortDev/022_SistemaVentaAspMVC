var tabladata;

// ═══════════════════════════════════════════════════════
//  UTILIDADES
// ═══════════════════════════════════════════════════════

function lenguajeDataTable() {
    return { "url": $.MisUrls.url.Url_datatable_spanish };
}

$(document).ready(function () {
    activarMenu("Compras");

    // ── Datepicker ─────────────────────────────────────
    $.datepicker.setDefaults($.datepicker.regional['es']);
    $("#txtFechaInicio").datepicker();
    $("#txtFechaFin").datepicker();

    var hoy = ObtenerFechaHoy();
    // Por defecto buscar del 1er día del mes hasta hoy para que aparezcan las pendientes
    var primerDia = ObtenerPrimerDiaMes();
    $("#txtFechaInicio").val(primerDia);
    $("#txtFechaFin").val(hoy);

    if (!AppSession.esSuperAdmin) $("#divFiltroTienda").hide();

    // ── Cargar proveedores ─────────────────────────────
    $.ajax({
        url: $.MisUrls.url._OC_ObtenerProveedores,
        type: "GET",
        success: function (data) {
            $("#cboProveedor").html("");
            $("<option>").attr({ value: 0 }).text("-- Todos --").appendTo("#cboProveedor");
            if (data.data) {
                $.each(data.data, function (i, p) {
                    if (p.Activo) $("<option>").attr({ value: p.IdProveedor }).text(p.RazonSocial).appendTo("#cboProveedor");
                });
            }
        }
    });

    if (AppSession.esSuperAdmin) {
        $.ajax({
            url: $.MisUrls.url._ObtenerTiendas,
            type: "GET",
            success: function (data) {
                $("#cboTienda").html("");
                $("<option>").attr({ value: 0 }).text("-- Todas --").appendTo("#cboTienda");
                if (data.data) {
                    $.each(data.data, function (i, t) {
                        if (t.Activo) $("<option>").attr({ value: t.IdTienda }).text(t.Nombre).appendTo("#cboTienda");
                    });
                }
            }
        });
    }

    // ── DataTable (estado Pendiente fijo) ──────────────
    var idTiendaIni = AppSession.esSuperAdmin ? 0 : AppSession.idTienda;

    tabladata = $('#tbOrdenes').DataTable({
        "ajax": {
            "url": $.MisUrls.url._OC_Obtener
                 + "?fechainicio=" + primerDia
                 + "&fechafin=" + hoy
                 + "&idproveedor=0&idtienda=" + idTiendaIni
                 + "&estado=Pendiente",
            "type": "GET", "datatype": "json"
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class='btn btn-info btn-sm' onclick='verDocumento(${row.IdOrdenCompra})'><i class='far fa-clipboard'></i></button>
                            <button class='btn btn-success btn-sm' onclick='aprobarOrden(${row.IdOrdenCompra})'><i class='fas fa-check'></i></button>
                            <button class='btn btn-danger btn-sm'  onclick='rechazarOrden(${row.IdOrdenCompra})'><i class='fas fa-times'></i></button>`;
                },
                "orderable": false, "searchable": false
            },
            { "data": "NumeroOrden" },
            { "data": "oProveedor", render: d => d ? d.RazonSocial : "" },
            { "data": "oTienda",    render: d => d ? d.Nombre : "" },
            { "data": "FechaOrden" },
            { "data": "FechaEntregaEstimada" },
            {
                "data": "TotalEstimado",
                "render": d => "G./ " + (d || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,")
            },
            { "data": "oUsuarioRegistro", render: d => d ? d.Nombres : "" }
        ],
        "language": lenguajeDataTable(),
        responsive: true
    });
});

function buscar() {
    if (!$("#txtFechaInicio").val().trim() || !$("#txtFechaFin").val().trim()) {
        Swal.fire({title: "Mensaje", text: "Debe ingresar fechas", icon: "warning"});
        return;
    }
    var idTienda = AppSession.esSuperAdmin ? $("#cboTienda").val() : AppSession.idTienda;

    tabladata.ajax.url(
        $.MisUrls.url._OC_Obtener
        + "?fechainicio=" + $("#txtFechaInicio").val().trim()
        + "&fechafin="    + $("#txtFechaFin").val().trim()
        + "&idproveedor=" + $("#cboProveedor").val()
        + "&idtienda="    + idTienda
        + "&estado=Pendiente"
    ).load();
}

function verDocumento(id) {
    window.open($.MisUrls.url._OC_Documento + "?idordencompra=" + id);
}

function aprobarOrden(id) {
    Swal.fire({
        title: "¿Aprobar esta Orden de Compra?",
        text: "Después de aprobarla podrá ser facturada.",
        icon: "info",
        showCancelButton: true,
        confirmButtonText: "Aprobar",
        cancelButtonText: "Cancelar"
    }).then(function (result) {
        if (!result.isConfirmed) return;
        $.ajax({
            url: $.MisUrls.url._OC_Aprobar,
            type: "POST",
            data: { idordencompra: id },
            success: function (resp) {
                if (resp.resultado) {
                    Swal.fire({title: "Éxito", text: resp.mensaje || "Orden aprobada", icon: "success"})
                        .then(() => tabladata.ajax.reload());
                } else {
                    Swal.fire({title: "Error", text: resp.mensaje || "No se pudo aprobar", icon: "error"});
                }
            },
            error: function () { Swal.fire({title: "Error", text: "Error de comunicación", icon: "error"}); }
        });
    });
}

function rechazarOrden(id) {
    $("#hdnIdRechazo").val(id);
    $("#cboMotivoRechazo").val("0");
    $("#txtMotivoRechazo").val("");
    $("#modalRechazo").modal("show");
}

function confirmarRechazo() {
    var id            = parseInt($("#hdnIdRechazo").val()) || 0;
    var idMotivo      = parseInt($("#cboMotivoRechazo").val()) || 0;
    var observacion   = $("#txtMotivoRechazo").val().trim();
    if (id <= 0) return;
    if (idMotivo <= 0) {
        Swal.fire({title: "Mensaje", text: "Debe seleccionar un motivo de rechazo", icon: "warning"});
        return;
    }

    $.ajax({
        url: $.MisUrls.url._OC_Rechazar,
        type: "POST",
        data: { idordencompra: id, idmotivorechazo: idMotivo, motivo: observacion },
        success: function (resp) {
            if (resp.resultado) {
                $("#modalRechazo").modal("hide");
                Swal.fire({title: "Éxito", text: resp.mensaje || "Orden rechazada", icon: "success"})
                    .then(() => tabladata.ajax.reload());
            } else {
                Swal.fire({title: "Error", text: resp.mensaje || "No se pudo rechazar", icon: "error"});
            }
        },
        error: function () { Swal.fire({title: "Error", text: "Error de comunicación", icon: "error"}); }
    });
}

function ObtenerFechaHoy() {
    var d = new Date();
    var m = d.getMonth() + 1;
    var day = d.getDate();
    return (day < 10 ? "0" : "") + day + "/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}

function ObtenerPrimerDiaMes() {
    var d = new Date();
    var m = d.getMonth() + 1;
    return "01/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}
