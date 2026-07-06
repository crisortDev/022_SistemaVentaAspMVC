$(document).ready(function () {
    activarMenu("Baja de Productos");

    var dtProductos = null;

    cargarTiendas();
    cargarMotivosBaja();

    // ── Cambio de tienda: recargar DataTable ──────────────────
    $("#cboTienda").on("change", function () {
        var idTienda = $(this).val();
        if (!idTienda) {
            if (dtProductos) { dtProductos.clear().draw(); }
            $("#divTabla").hide();
            $("#divSinTienda").show();
            $("#lblTotalProductos").text("");
            return;
        }
        cargarProductos(idTienda);
    });

    // ── Confirmar baja desde el modal ─────────────────────────
    $("#btnConfirmarBaja").on("click", function () {
        var idProductoTienda = $("#hIdProductoTienda").val();
        var idProducto       = $("#hIdProducto").val();
        var stockActual      = parseInt($("#hStockActual").val()) || 0;
        var cantidad         = parseInt($("#txtCantidad").val()) || 0;
        var idMotivo         = $("#cboMotivoBaja").val();
        var observaciones    = $("#txtObservaciones").val().trim();
        var nombreProducto   = $("#lblProductoBaja").text();
        var motivoDesc       = $("#cboMotivoBaja option:selected").text();

        // Validaciones
        if (cantidad <= 0)
            { toastr.warning("La cantidad debe ser mayor a cero."); $("#txtCantidad").focus(); return; }
        if (cantidad > stockActual)
            { toastr.warning("La cantidad (" + cantidad + ") supera el stock disponible (" + stockActual + ")."); return; }
        if (!idMotivo)
            { toastr.warning("Seleccioná el motivo de la baja."); return; }
        if (observaciones.length < 3)
            { toastr.warning("La observación es obligatoria (mínimo 3 caracteres)."); $("#txtObservaciones").focus(); return; }

        Swal.fire({
            title: "¿Confirmar baja?",
            text: cantidad + " unidad(es) de «" + nombreProducto + "» — " + motivoDesc,
            icon: "warning",
            showCancelButton: true,
            confirmButtonText: "Sí, dar de baja",
            cancelButtonText: "Cancelar",
            confirmButtonColor: "#dc3545"
        }).then(function (result) {
            if (!result.isConfirmed) return;

            $.post($.MisUrls.url._BajarStock, {
                idProductoTienda : idProductoTienda,
                idProducto       : idProducto,
                cantidad         : cantidad,
                motivo           : observaciones,
                idMotivoBaja     : idMotivo
            }, function (resp) {
                if (resp.resultado) {
                    $("#modalBaja").modal("hide");
                    toastr.success("Baja registrada correctamente.");
                    cargarProductos($("#cboTienda").val());
                } else {
                    Swal.fire({ icon: "error", title: "Error", text: resp.mensaje });
                }
            }).fail(function () {
                Swal.fire({ icon: "error", title: "Error", text: "Error de conexión al registrar la baja." });
            });
        });
    });

    // Limpiar modal al cerrarlo
    $("#modalBaja").on("hidden.bs.modal", function () {
        $("#txtCantidad").val(1);
        $("#cboMotivoBaja").val("");
        $("#txtObservaciones").val("");
    });
});

// ── Abrir modal de baja (llamado desde botón de la tabla) ─────
window.abrirModalBaja = function (idProductoTienda, idProducto, nombre, stock) {
    $("#hIdProductoTienda").val(idProductoTienda);
    $("#hIdProducto").val(idProducto);
    $("#hStockActual").val(stock);
    $("#lblProductoBaja").text(nombre);
    $("#txtCantidad").val(1).attr("max", stock);
    $("#cboMotivoBaja").val("");
    $("#txtObservaciones").val("");
    $("#modalBaja").modal("show");
};

// ── Cargar productos en DataTable ─────────────────────────────
function cargarProductos(idTienda) {
    $.get($.MisUrls.url._ObtenerProductosPorTiendaBaja, { idTienda: idTienda }, function (resp) {
        var productos = resp.data || [];

        $("#divSinTienda").hide();
        $("#divTabla").show();

        if ($.fn.DataTable.isDataTable("#tblProductos")) {
            $("#tblProductos").DataTable().destroy();
        }

        var filas = productos.map(function (p) {
            var btnBaja = '<button class="btn btn-sm btn-danger" '
                + 'onclick="abrirModalBaja('
                + p.IdProductoTienda + ','
                + p.IdProducto + ',\''
                + (p.Nombre || '').replace(/'/g, "\\'") + '\','
                + (p.Stock || 0) + ')">'
                + '<i class="fas fa-arrow-down mr-1"></i>Dar de baja'
                + '</button>';
            return [
                p.Codigo || '',
                p.Nombre || '',
                p.Categoria || '',
                btnBaja
            ];
        });

        $("#tblProductos").DataTable({
            data      : filas,
            columns   : [
                { title: 'Código',    width: '120px' },
                { title: 'Producto'  },
                { title: 'Categoría' },
                { title: 'Acciones', orderable: false, className: 'text-center', width: '130px' }
            ],
            language  : {
                url: "//cdn.datatables.net/plug-ins/1.13.5/i18n/es-ES.json"
            },
            pageLength : 15,
            order      : [[1, 'asc']],
            responsive : true
        });

        $("#lblTotalProductos").text(productos.length + " producto(s) en esta sucursal");
    }).fail(function () {
        toastr.error("No se pudieron cargar los productos.");
    });
}

// ── Cargar sucursales ─────────────────────────────────────────
function cargarTiendas() {
    $.get($.MisUrls.url._ObtenerTiendas, function (data) {
        var tiendas  = (data.data || []).filter(function (t) { return t.Activo; });
        var esSA     = AppSession.esSuperAdmin;
        var miTienda = AppSession.tiendaOperativa;

        if (esSA) {
            var opts = '<option value="">-- Seleccione sucursal --</option>';
            tiendas.forEach(function (t) {
                opts += '<option value="' + t.IdTienda + '">' + t.Nombre + '</option>';
            });
            $("#cboTienda").html(opts).prop("disabled", false);
        } else {
            var miNombre = (tiendas.find(function (t) { return t.IdTienda == miTienda; }) || {}).Nombre || 'Mi sucursal';
            $("#cboTienda")
                .html('<option value="' + miTienda + '">' + miNombre + '</option>')
                .val(miTienda)
                .prop("disabled", true)
                .trigger("change");
        }
    });
}

// ── Cargar motivos de baja ────────────────────────────────────
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
