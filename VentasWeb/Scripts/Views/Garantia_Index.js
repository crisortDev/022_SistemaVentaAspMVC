// ══════════════════════════════════════════════════════════════════════════════
//  Garantia_Index.js
//  Gestión de Garantías — búsqueda de venta, selección de ítem, procesamiento
// ══════════════════════════════════════════════════════════════════════════════

var _idDetalleSeleccionado   = 0;
var _importeItemSeleccionado = 0;
var _precioUnitarioItem      = 0;
var _cantidadDisponible      = 0;
var _stockItemSeleccionado   = 0;
var _totalVenta              = 0;

function formatGs(valor) {
    return (Math.round(valor) || 0).toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1.');
}

// ── Inicialización ─────────────────────────────────────────────────────────
$(document).ready(function () {
    activarMenu("Ventas");

    // Permitir buscar con Enter
    $("#txtFactura, #txtDocumento").on("keypress", function (e) {
        if (e.which === 13) buscarVentas();
    });
});

// ── Buscar ventas ──────────────────────────────────────────────────────────
function buscarVentas() {
    var factura    = $("#txtFactura").val().trim();
    var documento  = $("#txtDocumento").val().trim();

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
        if (v.Estado === "Cobrado")               badgeEstado = '<span class="badge badge-success">Cobrado</span>';
        else if (v.Estado === "CobradoParcial")    badgeEstado = '<span class="badge badge-warning">Cobrado Parcial</span>';
        else                                       badgeEstado = '<span class="badge badge-secondary">' + v.Estado + '</span>';

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
            "<td>" + (v.FechaRegistro   || "—") + "</td>" +
            "<td>" + (v.oCliente ? v.oCliente.Nombre : "—") + "</td>" +
            "<td>" + (v.ModalidadPago || "—") + "</td>" +
            "<td class='text-center'>" + cuotasInfo + "</td>" +
            "<td class='text-right'>Gs. " + formatGs(v.TotalCosto) + "</td>" +
            "<td>" + badgeEstado + "</td>" +
            "</tr>"
        );
    });
}

// ── Abrir modal de garantía ────────────────────────────────────────────────
function abrirModalGarantia(venta) {
    // Reset
    _idDetalleSeleccionado   = 0;
    _importeItemSeleccionado = 0;
    _stockItemSeleccionado   = 0;
    _totalVenta              = venta.TotalCosto || 0;

    $("#hdnIdVenta").val(venta.IdVenta);
    $("#hdnModalidad").val(venta.ModalidadPago || "Efectivo");
    $("#spanFacturaModal").text(venta.NumeroFactura || "—");
    $("#infoCliente").text(venta.oCliente ? venta.oCliente.Nombre : "—");
    $("#infoModalidad").text(venta.ModalidadPago || "Efectivo");

    var cuotasText = venta.ModalidadPago === "Crédito"
        ? (venta.CuotasPagadas + " pagadas / " + venta.CuotasPendientes + " pendientes")
        : "—";
    $("#infoCuotas").text(cuotasText);

    // Reset acciones
    $("#divAccion").hide();
    $("#panelReemplazo").hide();
    $("#panelNC").hide();
    $("#btnProcesar").hide();
    $("input[name='radioStock']").prop("checked", false);
    $("#cboMotivoNC").val(0);

    // Cargar ítems
    $("#tbodyItems").html('<tr><td colspan="7" class="text-center text-muted">Cargando...</td></tr>');
    $("#modalGarantia").modal("show");

    $.ajax({
        url:  $.MisUrls.url._Garantia_ObtenerDetalle,
        type: "GET",
        data: { idventa: venta.IdVenta },
        success: function (res) { renderizarItems(res.data || []); },
        error:   function ()    {
            $("#tbodyItems").html('<tr><td colspan="7" class="text-center text-danger">Error al cargar.</td></tr>');
        }
    });
}

// ── Renderizar ítems de la venta ───────────────────────────────────────────
function renderizarItems(items) {
    var tbody = $("#tbodyItems").empty();

    if (!items || items.length === 0) {
        tbody.html('<tr><td colspan="7" class="text-center text-muted">Sin ítems.</td></tr>');
        return;
    }

    $.each(items, function (i, it) {
        var esActivo = it.EstadoLinea === "OK";

        var badgeLinea;
        if      (it.EstadoLinea === "OK")               badgeLinea = '<span class="badge badge-success">OK</span>';
        else if (it.EstadoLinea === "GARANTIA_PARCIAL") badgeLinea = '<span class="badge badge-warning">Parcial (' + it.CantidadGarantizada + '/' + it.Cantidad + ')</span>';
        else if (it.EstadoLinea === "CAMBIADO")         badgeLinea = '<span class="badge badge-info">Cambiado</span>';
        else                                            badgeLinea = '<span class="badge badge-warning">Dev. NC</span>';

        var stockCell = it.StockDisponible > 0
            ? '<span class="text-success font-weight-bold">' + it.StockDisponible + '</span>'
            : '<span class="text-danger font-weight-bold">0</span>';

        var radio = esActivo
            ? '<input type="radio" name="radioItem" value="' + it.IdDetalleVenta + '" '
              + 'data-importe="' + it.ImporteTotal + '" data-stock="' + it.StockDisponible + '" '
              + 'data-item="' + JSON.stringify(it).replace(/"/g, "&quot;") + '" '
              + 'onchange="seleccionarItem(this)">'
            : '';

        tbody.append(
            "<tr class='" + (esActivo ? "" : "table-secondary text-muted") + "'>" +
            "<td class='text-center'>" + radio + "</td>" +
            "<td>" + (it.NombreProducto || "—") + "</td>" +
            "<td class='text-center'>" + it.Cantidad + "</td>" +
            "<td class='text-right'>Gs. " + formatGs(it.PrecioUnidad) + "</td>" +
            "<td class='text-right'>Gs. " + formatGs(it.ImporteTotal) + "</td>" +
            "<td class='text-center'>" + stockCell + "</td>" +
            "<td class='text-center'>" + badgeLinea + "</td>" +
            "</tr>"
        );
    });
}

// ── Seleccionar ítem ───────────────────────────────────────────────────────
function seleccionarItem(radio) {
    var item = JSON.parse($(radio).attr("data-item"));
    _idDetalleSeleccionado   = item.IdDetalleVenta;
    _importeItemSeleccionado = item.ImporteTotal;
    _precioUnitarioItem      = item.PrecioUnidad;
    _cantidadDisponible      = item.CantidadDisponible > 0 ? item.CantidadDisponible : item.Cantidad;
    _stockItemSeleccionado   = item.StockDisponible;

    // Configurar input de cantidad
    $("#txtCantidadGarantia").val(_cantidadDisponible).attr("max", _cantidadDisponible);
    $("#spanMaxCantidad").text("/ " + _cantidadDisponible);

    // Premarcar stock según disponibilidad
    if (item.StockDisponible > 0) {
        $("#radioSiStock").prop("checked", true);
    } else {
        $("#radioNoStock").prop("checked", true);
    }
    cambioOpcionStock();

    $("#divAccion").show();
}

// ── Cambio de cantidad a garantizar ───────────────────────────────────────
function cambiarCantidad() {
    var cant = parseInt($("#txtCantidadGarantia").val()) || 1;
    if (cant < 1) cant = 1;
    if (cant > _cantidadDisponible) cant = _cantidadDisponible;
    $("#txtCantidadGarantia").val(cant);
    _importeItemSeleccionado = _precioUnitarioItem * cant;
    cambioOpcionStock();
}

// ── Cambio de opción: reemplazar vs NC ────────────────────────────────────
function cambioOpcionStock() {
    var hayStock = $("input[name='radioStock']:checked").val();
    if (!hayStock) return;

    if (hayStock === "1") {
        // Reemplazo desde stock
        $("#panelReemplazo").show();
        $("#panelNC").hide();
    } else {
        // NC + ajuste cuotas
        $("#panelReemplazo").hide();
        actualizarResumenNC();
        $("#panelNC").show();
    }
    $("#btnProcesar").show();
}

// ── Calcular y mostrar resumen de NC ──────────────────────────────────────
function actualizarResumenNC() {
    var importe  = _importeItemSeleccionado || 0;
    var total    = _totalVenta || 1;
    var porcent  = (importe / total * 100).toFixed(1);
    var modalidad = $("#hdnModalidad").val();

    var resumen = "Se emite NC por <strong>Gs. " + formatGs(importe) + "</strong> ";

    if (modalidad === "Crédito") {
        resumen += "(" + porcent + "% del total). "
                + "Las cuotas <strong>pendientes</strong> se reducirán en un " + porcent + "%. "
                + "Si hay cuotas ya pagas, el " + porcent + "% de lo pagado "
                + "se acreditará como <strong>Saldo a Favor</strong> del cliente.";
    } else {
        resumen += ". El monto completo de Gs. " + formatGs(importe)
                + " se acreditará como <strong>Saldo a Favor</strong> del cliente.";
    }

    $("#spanResumenNC").html(resumen);
}

// ── Confirmar y procesar ───────────────────────────────────────────────────
function confirmarGarantia() {
    if (_idDetalleSeleccionado <= 0) {
        Swal.fire({ title: "Atención", text: "Seleccioná el producto fallado.", icon: "warning" });
        return;
    }
    var hayStock = $("input[name='radioStock']:checked").val();
    if (!hayStock) {
        Swal.fire({ title: "Atención", text: "Indicá si hay stock disponible.", icon: "warning" });
        return;
    }
    var idMotivo = parseInt($("#cboMotivoNC").val()) || 0;
    if (idMotivo <= 0) {
        Swal.fire({ title: "Atención", text: "Seleccioná el motivo.", icon: "warning" });
        return;
    }

    var textoConfirm = hayStock === "1"
        ? "Se reemplazará el producto desde stock. ¿Confirmás?"
        : "Se emitirá una Nota de Crédito y se ajustarán las cuotas pendientes. ¿Confirmás?";

    Swal.fire({
        title: "¿Procesar garantía?",
        html:  textoConfirm,
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
                idventa:          parseInt($("#hdnIdVenta").val()),
                iddetalleventa:   _idDetalleSeleccionado,
                idmotivonc:       idMotivo,
                haystock:         hayStock === "1",
                cantidadgarantia: parseInt($("#txtCantidadGarantia").val()) || 0
            },
            success: function (res) {
                $.LoadingOverlay("hide");
                $("#modalGarantia").modal("hide");

                if (res.resultado) {
                    var extra = "";
                    if (res.montoNC       > 0) extra += "<br>NC emitida: <strong>Gs. " + formatGs(res.montoNC)      + "</strong>";
                    if (res.saldoGenerado > 0) extra += "<br>Saldo a Favor acreditado: <strong>Gs. " + formatGs(res.saldoGenerado) + "</strong>";

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
