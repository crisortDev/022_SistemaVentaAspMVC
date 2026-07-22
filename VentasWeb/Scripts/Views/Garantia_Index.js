// ══════════════════════════════════════════════════════════════════════════════
//  Garantia_Index.js  —  Garantía multi-producto
// ══════════════════════════════════════════════════════════════════════════════

var _itemsDisponibles = [];

function formatGs(valor) {
    return (Math.round(valor) || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1.');
}

// ── Inicialización ─────────────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Ventas");

    $("#txtFactura, #txtDocumento").on("keypress", function (e) {
        if (e.which === 13) buscarVentas();
    });

    // Checkbox "seleccionar todos"
    $(document).on("change", "#chkTodos", function () {
        var checked = $(this).prop("checked");
        $("#tbodyItems .chkItem").each(function () {
            $(this).prop("checked", checked);
        });
        actualizarResumen();
    });

    $(document).on("change", ".chkItem", actualizarResumen);
    $(document).on("input",  ".txtCantGar", actualizarResumen);
});

// ── Buscar ventas ──────────────────────────────────────────────────────────
function buscarVentas() {
    var factura   = $("#txtFactura").val().trim();
    var documento = $("#txtDocumento").val().trim();

    if (!factura && !documento) {
        Swal.fire({ title: "Atención", text: "Ingresá un número de factura o el CI/RUC del cliente.", icon: "warning" });
        return;
    }

    $.LoadingOverlay("show");
    $.ajax({
        url:  $.MisUrls.url._Garantia_ObtenerVentas,
        type: "GET",
        data: { numerofactura: factura, documento: documento },
        success: function (res) {
            $.LoadingOverlay("hide");
            renderizarVentas(res.data || []);
        },
        error: function () {
            $.LoadingOverlay("hide");
            Swal.fire({ title: "Error", text: "Error al buscar ventas.", icon: "error" });
        }
    });
}

function limpiarBusqueda() {
    $("#txtFactura").val("");
    $("#txtDocumento").val("");
    $("#divResultados").hide();
    $("#divSinResultados").hide();
    $("#tbodyVentas").empty();
}

// ── Renderizar lista de ventas ─────────────────────────────────────────────
function renderizarVentas(lista) {
    var tbody = $("#tbodyVentas").empty();

    if (!lista || lista.length === 0) {
        $("#divResultados").hide();
        $("#divSinResultados").show();
        return;
    }

    $("#divSinResultados").hide();
    $("#divResultados").show();

    $.each(lista, function (i, v) {
        var badgeEstado;
        if      (v.Estado === "Cobrado")        badgeEstado = '<span class="badge badge-success">Cobrado</span>';
        else if (v.Estado === "CobradoParcial") badgeEstado = '<span class="badge badge-warning">Cobrado Parcial</span>';
        else                                    badgeEstado = '<span class="badge badge-secondary">' + v.Estado + '</span>';

        var cuotasInfo = v.ModalidadPago === "Crédito"
            ? (v.CuotasPagadas + " pag. / " + v.CuotasPendientes + " pend.")
            : "—";

        var btnGarantia;
        if (!v.TieneItemsActivos) {
            btnGarantia = "<span class='text-muted small'>Sin ítems activos</span>";
        } else if (!v.PuedeGarantia) {
            btnGarantia = "<span class='text-danger small' title='El cliente ya realizó pagos de cuotas'>"
                        + "<i class='fas fa-lock'></i> Garantía no disponible</span>";
        } else {
            btnGarantia = "<button class='btn btn-sm btn-warning' "
                        + "data-venta='" + JSON.stringify(v).replace(/'/g, "&#39;") + "' "
                        + "onclick='abrirModalGarantia(JSON.parse($(this).attr(\"data-venta\")))'>"
                        + "<i class='fas fa-shield-alt'></i> Gestionar</button>";
        }

        tbody.append(
            "<tr>" +
            "<td>" + btnGarantia + "</td>" +
            "<td>" + (v.NumeroFactura || "—") + "</td>" +
            "<td>" + (v.FechaRegistro || "—") + "</td>" +
            "<td>" + (v.oCliente ? v.oCliente.Nombre : "—") + "</td>" +
            "<td>" + (v.ModalidadPago || "—") + "</td>" +
            "<td class='text-center'>" + cuotasInfo + "</td>" +
            "<td class='text-right'>Gs. " + formatGs(v.TotalCosto) + "</td>" +
            "<td>" + badgeEstado + "</td>" +
            "</tr>"
        );
    });
}

// ── Abrir modal ────────────────────────────────────────────────────────────
function abrirModalGarantia(venta) {
    _itemsDisponibles = [];

    $("#hdnIdVenta").val(venta.IdVenta);
    $("#hdnModalidad").val(venta.ModalidadPago || "Efectivo");
    $("#spanFacturaModal").text(venta.NumeroFactura || "—");
    $("#infoCliente").text(venta.oCliente ? venta.oCliente.Nombre : "—");
    $("#infoModalidad").text(venta.ModalidadPago || "Efectivo");

    var cuotasText = venta.ModalidadPago === "Crédito"
        ? (venta.CuotasPagadas + " pagadas / " + venta.CuotasPendientes + " pendientes")
        : "—";
    $("#infoCuotas").text(cuotasText);

    $("#divAccion").hide();
    $("#divResumenPrevia").hide();
    $("#btnProcesar").hide();
    $("#chkTodos").prop("checked", false);
    $("#cboMotivoNC").val(0);

    $("#tbodyItems").html('<tr><td colspan="8" class="text-center text-muted">Cargando...</td></tr>');
    $("#modalGarantia").modal("show");

    $.ajax({
        url:  $.MisUrls.url._Garantia_ObtenerDetalle,
        type: "GET",
        data: { idventa: venta.IdVenta },
        success: function (res) {
            _itemsDisponibles = res.data || [];
            renderizarItems(_itemsDisponibles);
        },
        error: function () {
            $("#tbodyItems").html('<tr><td colspan="8" class="text-center text-danger">Error al cargar.</td></tr>');
        }
    });
}

// ── Renderizar ítems con checkboxes ────────────────────────────────────────
function renderizarItems(items) {
    var tbody = $("#tbodyItems").empty();

    if (!items || items.length === 0) {
        tbody.html('<tr><td colspan="8" class="text-center text-muted">Sin ítems disponibles.</td></tr>');
        return;
    }

    $.each(items, function (i, it) {
        var cantDisp = it.CantidadDisponible > 0 ? it.CantidadDisponible : it.Cantidad;

        var badgeLinea;
        if      (it.EstadoLinea === "OK")               badgeLinea = '<span class="badge badge-success">OK</span>';
        else if (it.EstadoLinea === "GARANTIA_PARCIAL") badgeLinea = '<span class="badge badge-warning">Parcial (' + it.CantidadGarantizada + '/' + it.Cantidad + ')</span>';
        else                                            badgeLinea = '<span class="badge badge-secondary">' + it.EstadoLinea + '</span>';

        var stockCell = it.StockDisponible > 0
            ? '<span class="text-success font-weight-bold">' + it.StockDisponible + '</span>'
            : '<span class="text-danger font-weight-bold">0</span>';

        // Icono indicador de acción automática
        var accionIcon = it.StockDisponible > 0
            ? ' <i class="fas fa-exchange-alt text-success" title="Con stock: se reemplazará"></i>'
            : ' <i class="fas fa-file-invoice-dollar text-warning" title="Sin stock: se generará NC"></i>';

        tbody.append(
            "<tr>" +
            "<td class='text-center'>" +
              "<input type='checkbox' class='chkItem' " +
              "data-id='" + it.IdDetalleVenta + "' " +
              "data-precio='" + it.PrecioUnidad + "' " +
              "data-stock='" + it.StockDisponible + "' " +
              "data-max='" + cantDisp + "'>" +
            "</td>" +
            "<td>" + (it.NombreProducto || "—") + accionIcon + "</td>" +
            "<td class='text-center'>" + it.Cantidad + "</td>" +
            "<td class='text-center'>" + cantDisp + "</td>" +
            "<td class='text-center'>" +
              "<input type='number' class='form-control form-control-sm txtCantGar' " +
              "min='1' max='" + cantDisp + "' value='" + cantDisp + "' " +
              "data-id='" + it.IdDetalleVenta + "' style='width:70px;display:inline-block;'>" +
            "</td>" +
            "<td class='text-right'>Gs. " + formatGs(it.PrecioUnidad) + "</td>" +
            "<td class='text-center'>" + stockCell + "</td>" +
            "<td class='text-center'>" + badgeLinea + "</td>" +
            "</tr>"
        );
    });
}

// ── Actualizar resumen previo ──────────────────────────────────────────────
function actualizarResumen() {
    var seleccionados = obtenerItemsSeleccionados();

    if (seleccionados.length === 0) {
        $("#divAccion").hide();
        $("#divResumenPrevia").hide();
        $("#btnProcesar").hide();
        return;
    }

    $("#divAccion").show();
    $("#btnProcesar").show();

    var reemplazos = 0, sinStock = 0, montoNC = 0;

    $.each(seleccionados, function (i, s) {
        var chk    = $(".chkItem[data-id='" + s.IdDetalleVenta + "']");
        var stock  = parseFloat(chk.data("stock"))  || 0;
        var precio = parseFloat(chk.data("precio")) || 0;

        if (stock >= s.CantidadGarantia) {
            reemplazos++;
        } else {
            sinStock++;
            montoNC += precio * s.CantidadGarantia;
        }
    });

    var html = '<strong><i class="fas fa-info-circle"></i> Vista previa de la operación:</strong><br>';
    if (reemplazos > 0)
        html += '<span class="text-success"><i class="fas fa-exchange-alt"></i> '
             + reemplazos + ' producto(s) se reemplazarán desde stock.</span><br>';
    if (sinStock > 0)
        html += '<span class="text-warning"><i class="fas fa-file-invoice-dollar"></i> '
             + sinStock + ' producto(s) sin stock → NC por <strong>Gs. '
             + formatGs(montoNC) + '</strong>.</span>';

    $("#divResumenPrevia").html(html).show();
}

// ── Obtener ítems seleccionados ────────────────────────────────────────────
function obtenerItemsSeleccionados() {
    var items = [];
    $("#tbodyItems .chkItem:checked").each(function () {
        var id   = parseInt($(this).data("id"));
        var max  = parseInt($(this).data("max")) || 1;
        var cant = parseInt($(".txtCantGar[data-id='" + id + "']").val()) || 1;
        if (cant < 1)   cant = 1;
        if (cant > max) cant = max;
        items.push({ IdDetalleVenta: id, CantidadGarantia: cant });
    });
    return items;
}

// ── Confirmar garantía ─────────────────────────────────────────────────────
function confirmarGarantia() {
    var items = obtenerItemsSeleccionados();
    if (items.length === 0) {
        Swal.fire({ title: "Atención", text: "Seleccioná al menos un producto.", icon: "warning" });
        return;
    }

    var idMotivo = parseInt($("#cboMotivoNC").val()) || 0;
    if (idMotivo <= 0) {
        Swal.fire({ title: "Atención", text: "Seleccioná el motivo.", icon: "warning" });
        return;
    }

    Swal.fire({
        title: "¿Procesar garantía?",
        html:  "Se procesarán <strong>" + items.length + " producto(s)</strong>.<br>"
             + "Los productos con stock serán reemplazados; los sin stock generarán una NC automática.",
        icon:  "question",
        showCancelButton:   true,
        confirmButtonColor: "#ffc107",
        confirmButtonText:  "Sí, procesar",
        cancelButtonText:   "Cancelar"
    }).then(function (r) {
        if (!r.isConfirmed) return;

        $.LoadingOverlay("show");
        $.ajax({
            url:  $.MisUrls.url._Garantia_Procesar,
            type: "POST",
            data: {
                idventa:    parseInt($("#hdnIdVenta").val()),
                idmotivonc: idMotivo,
                itemsjson:  JSON.stringify(items)
            },
            success: function (res) {
                $.LoadingOverlay("hide");
                $("#modalGarantia").modal("hide");

                if (res.resultado) {
                    var extra = "";
                    if (res.reemplazos    > 0) extra += "<br><i class='fas fa-exchange-alt text-success'></i> " + res.reemplazos + " producto(s) reemplazado(s) desde stock.";
                    if (res.montoNC       > 0) extra += "<br><i class='fas fa-file-invoice-dollar text-warning'></i> NC <strong>" + res.numeroNC + "</strong> por Gs. " + formatGs(res.montoNC) + ".";
                    if (res.saldoGenerado > 0) extra += "<br>Saldo a Favor acreditado: <strong>Gs. " + formatGs(res.saldoGenerado) + "</strong>.";

                    Swal.fire({
                        title: "¡Garantía procesada!",
                        html:  res.mensaje + extra,
                        icon:  "success"
                    }).then(function () { limpiarBusqueda(); });
                } else {
                    Swal.fire({ title: "Error", text: res.mensaje, icon: "error" });
                }
            },
            error: function () {
                $.LoadingOverlay("hide");
                Swal.fire({ title: "Error", text: "Error de comunicación.", icon: "error" });
            }
        });
    });
}
