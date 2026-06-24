$(document).ready(function () {
    activarMenu("Baja de Productos");

    cargarTiendas();
    cargarMotivosBaja();

    // Al cambiar tienda, cargar productos con stock
    $("#cboTienda").on("change", function () {
        var idTienda = $(this).val();
        $("#cboProducto").html('<option value="">-- Seleccione producto --</option>').prop("disabled", true);
        $("#lblStockActual").text("-");
        if (!idTienda) return;

        $.get("/Inventario/ObtenerProductosPorTiendaBaja", { idTienda: idTienda }, function (resp) {
            var opts = '<option value="">-- Seleccione producto --</option>';
            (resp.data || []).forEach(function (p) {
                opts += '<option value="' + p.IdProductoTienda + '"'
                    + ' data-idproducto="' + p.IdProducto + '"'
                    + ' data-stock="' + p.Stock + '">'
                    + p.Codigo + ' - ' + p.Nombre + ' (Stock: ' + p.Stock + ')'
                    + '</option>';
            });
            $("#cboProducto").html(opts).prop("disabled", false);
        });
    });

    // Al cambiar producto, mostrar stock actual
    $("#cboProducto").on("change", function () {
        var stock = parseInt($(this).find(":selected").attr("data-stock")) || 0;
        $("#lblStockActual").text(stock);
        $("#txtCantidad").attr("max", stock);
    });

    // Confirmar baja
    $("#btnBajarStock").on("click", function () {
        var $productoSeleccionado = $("#cboProducto option:selected");
        var idProductoTienda = $("#cboProducto").val();
        var idProducto = $productoSeleccionado.attr("data-idproducto");
        var stockActual = parseInt($productoSeleccionado.attr("data-stock")) || 0;
        var cantidad = parseInt($("#txtCantidad").val()) || 0;
        var motivoDescripcion = $("#cboMotivoBaja option:selected").text();
        var idMotivo = $("#cboMotivoBaja").val();
        var observaciones = $("#txtObservaciones").val().trim();
        var nombreProducto = $productoSeleccionado.text();
        // Solo se envía el texto libre de observaciones; la descripción del motivo
        // ya queda registrada por IdMotivoBaja y se recupera via JOIN en los reportes.

        // Validaciones
        if (!$("#cboTienda").val()) { swal("Atencion", "Seleccione una tienda.", "warning"); return; }
        if (!idProductoTienda) { swal("Atencion", "Seleccione un producto.", "warning"); return; }
        if (cantidad <= 0) { swal("Atencion", "La cantidad debe ser mayor a cero.", "warning"); return; }
        if (cantidad > stockActual) { swal("Atencion", "La cantidad supera el stock disponible (" + stockActual + ").", "warning"); return; }
        if (!idMotivo) { swal("Atencion", "Seleccione el motivo de la baja.", "warning"); return; }

        swal({
            title: "Confirmar baja",
            text: "Se daran de baja " + cantidad + " unidad(es) de: " + nombreProducto + " | Motivo: " + motivoDescripcion + (observaciones ? " — " + observaciones : ""),
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, dar de baja",
            cancelButtonText: "Cancelar"
        }, function (confirmado) {
            if (confirmado) {
                $.post("/Inventario/BajarStock", {
                    idProductoTienda: idProductoTienda,
                    idProducto: idProducto,
                    cantidad: cantidad,
                    motivo: observaciones,
                    idMotivoBaja: idMotivo
                }, function (resp) {
                    if (resp.resultado) {
                        $("#cboTienda").trigger("change");
                        $("#txtCantidad").val(1);
                        $("#cboMotivoBaja").val("");
                        $("#txtObservaciones").val("");
                        $("#lblStockActual").text("-");
                        setTimeout(function () {
                            swal({
                                title: "Baja registrada",
                                text: "Se dio de baja " + cantidad + " unidad(es) de " + nombreProducto + " correctamente.",
                                type: "success",
                                confirmButtonText: "Aceptar"
                            });
                        }, 300);
                    } else {
                        setTimeout(function () {
                            swal("Error", resp.mensaje, "error");
                        }, 300);
                    }
                });
            }
        });
    });
});

function cargarTiendas() {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var tiendas  = (data.data || []).filter(function (t) { return t.Activo; });
        var esSA     = AppSession.esSuperAdmin;
        var miTienda = AppSession.tiendaOperativa;

        if (esSA) {
            // SuperAdmin: elige cualquier sucursal
            var opts = '<option value="">-- Seleccione tienda --</option>';
            tiendas.forEach(function (t) {
                opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            });
            $("#cboTienda").html(opts).prop("disabled", false);
        } else {
            // No-SuperAdmin: tienda fija a la propia, se carga automáticamente
            var miNombre = (tiendas.find(function (t) { return t.IdTienda == miTienda; }) || {}).Nombre || 'Mi sucursal';
            $("#cboTienda")
                .html('<option value="' + miTienda + '">' + miNombre + '</option>')
                .val(miTienda)
                .prop("disabled", true)
                .trigger("change"); // disparar carga de productos
        }
    });
}

function cargarMotivosBaja() {
    $.get($.MisUrls.url._ObtenerMotivosBaja, function (data) {
        var opts = '<option value="">-- Seleccione motivo --</option>';
        (data.data || []).forEach(function (m) {
            if (m.Activo)
                opts += '<option value="' + m.IdMotivoBaja + '">' + m.Descripcion + '</option>';
        });
        $("#cboMotivoBaja").html(opts);
    });
}
