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
    $("#txtFechaInicio").val(ObtenerFechaHoy());
    $("#txtFechaFin").val(ObtenerFechaHoy());

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

    // ── DataTable ──────────────────────────────────────
    var idTiendaIni = AppSession.esSuperAdmin ? 0 : AppSession.idTienda;

    tabladata = $('#tbOrdenes').DataTable({
        "ajax": {
            "url": $.MisUrls.url._OC_Obtener
                 + "?fechainicio=" + ObtenerFechaHoy()
                 + "&fechafin="    + ObtenerFechaHoy()
                 + "&idproveedor=0&idtienda=" + idTiendaIni
                 + "&estado=",
            "type": "GET", "datatype": "json"
        },
        "columns": [
            {
                "data": null,
                "render": function (data, type, row) {
                    var btns = `<button class='btn btn-info btn-sm' onclick='verDocumento(${row.IdOrdenCompra})'>
                                    <i class='far fa-clipboard'></i> Ver
                                </button>`;
                    if ((row.Estado === "Pendiente" || row.Estado === "Rechazada") && AppSession.idRol !== 7) {
                        btns += ` <button class='btn btn-dark btn-sm' onclick='anularOrden(${row.IdOrdenCompra})'>
                                    <i class='fas fa-ban'></i> Anular
                                  </button>`;
                    }
                    return btns;
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
                "render": function (d) {
                    return "G./ " + (d || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, "$1,");
                }
            },
            {
                "data": "Estado",
                "render": function (d) {
                    var cls = "secondary";
                    switch (d) {
                        case "Pendiente":  cls = "warning"; break;
                        case "Aprobada":   cls = "success"; break;
                        case "Rechazada":  cls = "danger"; break;
                        case "Facturada":  cls = "info"; break;
                        case "Cerrada":    cls = "secondary"; break;
                        case "Anulada":    cls = "dark"; break;
                    }
                    return `<span class='badge badge-${cls}'>${d}</span>`;
                }
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
        + "&estado="      + $("#cboEstado").val()
    ).load();
}

function verDocumento(id) {
    window.open($.MisUrls.url._OC_Documento + "?idordencompra=" + id);
}

function anularOrden(id) {
    Swal.fire({
        title: "¿Anular la Orden?",
        text: "No podrá deshacerse. Solo órdenes sin facturas vinculadas.",
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: "Sí, anular",
        cancelButtonText: "Cancelar",
        confirmButtonColor: "#dc3545"
    }).then(function (result) {
        if (!result.isConfirmed) return;
        $.ajax({
            url: $.MisUrls.url._OC_Anular,
            type: "POST",
            data: { idordencompra: id },
            success: function (resp) {
                if (resp.resultado) {
                    Swal.fire({title: "Éxito", text: resp.mensaje || "Orden anulada", icon: "success"})
                        .then(() => tabladata.ajax.reload());
                } else {
                    Swal.fire({title: "Error", text: resp.mensaje || "No se pudo anular", icon: "error"});
                }
            },
            error: function () { swal("Error", "Error de comunicación", "error"); }
        });
    });
}

function ObtenerFechaHoy() {
    var d = new Date();
    var m = d.getMonth() + 1;
    var day = d.getDate();
    return (day < 10 ? "0" : "") + day + "/" + (m < 10 ? "0" : "") + m + "/" + d.getFullYear();
}
