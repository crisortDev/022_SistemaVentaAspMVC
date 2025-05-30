// Formato para mostrar moneda (con separador de miles)
function formatearMoneda(valor) {
    if (isNaN(valor)) return "0";
    return valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

// Formatear fecha en formato local (ej. es-PY)
function formatearFecha(fechaStr) {
    if (!fechaStr) return '';

    // Detectar si viene en formato dd/MM/yyyy
    const ddmmyyyy = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
    const match = fechaStr.match(ddmmyyyy);

    if (match) {
        const [_, d, m, y] = match;
        return `${d.padStart(2, '0')}/${m.padStart(2, '0')}/${y}`;
    }

    const fecha = new Date(fechaStr);
    return isNaN(fecha.getTime()) ? 'Fecha inválida' : fecha.toLocaleDateString('es-PY');
}

// Inicializar DataTable para lista de productos con paginación
$(document).ready(function () {
    inicializarTablaProductos();
});

function inicializarTablaProductos() {
    $('#tbProductos').DataTable({
        "ajax": {
            "url": "/Producto/Obtener",
            "type": "GET",
            "dataSrc": "data"
        },
        "columns": [
            { "data": "Codigo" },
            { "data": "Nombre" },
            {
                "data": null,
                "render": function (data, type, row) {
                    return `<button class="btn btn-sm btn-primary btnSeleccionarProducto" data-id="${row.IdProducto}" data-codigo="${row.Codigo}" data-nombre="${row.Nombre}">Seleccionar</button>`;
                },
                "orderable": false,
                "searchable": false,
                "width": "100px"
            }
        ],
        "pageLength": 10,
        "language": {
            "url": "/content/plugins/datatables/js/datatable_spanish.json"
        },
        "responsive": true,
        "destroy": true
    });
}

// Evento para seleccionar producto de la tabla
$(document).on("click", ".btnSeleccionarProducto", function () {
    const idProducto = $(this).data("id");
    const codigo = $(this).data("codigo");
    const nombre = $(this).data("nombre");

    // Asignamos los valores al formulario de selección
    $("#txtIdProducto").val(idProducto);
    $("#txtCodigo").val(codigo);
    $("#txtNombre").val(nombre);

    // Llamamos para cargar el historial de precios
    cargarHistorialPrecios(idProducto);
});

// Función para cargar historial de precios para un producto
function cargarHistorialPrecios(idProducto) {
    console.log("Cargando historial precios para producto:", idProducto);

    if (!idProducto || idProducto === "0") {
        $("#tbHistorialPrecios tbody").html('<tr><td colspan="4" class="text-center">Seleccione un producto primero.</td></tr>');
        return;
    }

    $.ajax({
        url: '/Producto/ObtenerHistorialPrecios',
        type: 'GET',
        data: { idProducto: idProducto },
        success: function (response) {
            console.log("Respuesta AJAX:", response);

            if ($.fn.DataTable.isDataTable('#tbHistorialPrecios')) {
                console.log("Destruyendo DataTable previo");
                $('#tbHistorialPrecios').DataTable().clear().destroy();
            }

            let filas = '';
            if (response.data && response.data.length > 0) {
                response.data.forEach(function (item) {
                    filas += `<tr data-id="${item.IdPrecioVenta}">
                        <td>${formatearMoneda(item.PrecioUnidadVenta)}</td>
                        <td>${formatearFecha(item.FechaInicioVigencia)}</td>
                        <td>${item.FechaFinVigencia ? formatearFecha(item.FechaFinVigencia) : ''}</td>
                        <td>
                            <button type="button" class="btn btn-sm btn-warning btnEditar" title="Editar"><i class="fas fa-edit"></i></button>
                            <button class="btn btn-sm btn-danger btnEliminar" title="Eliminar"><i class="fas fa-trash-alt"></i></button>
                        </td>
                    </tr>`;
                });
            } else {
                filas = `<tr><td colspan="4" class="text-center">No hay precios registrados para este producto.</td></tr>`;
            }

            $("#tbHistorialPrecios tbody").html(filas);

            $('#tbHistorialPrecios').DataTable({
                pageLength: 10,
                responsive: true,
                destroy: true,
                language: {
                    url: '/content/plugins/datatables/js/datatable_spanish.json'
                }
            });
        },
        error: function (xhr, status, error) {
            console.error("Error en AJAX historial precios:", status, error);
            $("#tbHistorialPrecios tbody").html('<tr><td colspan="4" class="text-center text-danger">Error al cargar los datos.</td></tr>');
        }
    });
}


// Buscar producto por código y cargar historial al hacer clic en el botón Buscar
$("#btnBuscarProducto").on("click", function () {
    const codigo = $("#txtCodigo").val().trim();
    if (!codigo) {
        alert("Ingrese un código de producto");
        return;
    }
    $.ajax({
        url: '/Producto/BuscarProductoPorCodigo',
        type: 'GET',
        data: { codigo: codigo },
        success: function (resp) {
            if (resp.resultado && resp.data) {
                $("#txtIdProducto").val(resp.data.IdProducto);
                $("#txtNombre").val(resp.data.Nombre);
                // Hacer llamada separada para cargar historial con el IdProducto
                cargarHistorialPrecios(resp.data.IdProducto);
            } else {
                alert(resp.message || "Producto no encontrado");
                $("#txtIdProducto").val("0");
                $("#txtNombre").val("");
                $("#tbHistorialPrecios tbody").html('');
            }
        },
        error: function () {
            alert("Error al buscar producto");
        }
    });
});

// Evento delegado para eliminar precio
$(document).on("click", ".btnEliminar", function () {
    const fila = $(this).closest("tr");
    const idPrecio = fila.data("id");
    if (confirm("¿Está seguro que desea eliminar este precio?")) {
        $.ajax({
            url: '/Producto/EliminarPrecioVenta',
            type: 'POST',
            data: { id: idPrecio },
            success: function (resp) {
                if (resp.resultado) {
                    alert("Precio eliminado correctamente");
                    fila.remove();
                } else {
                    alert("Error al eliminar: " + resp.message);
                }
            },
            error: function () {
                alert("Error en la solicitud de eliminación");
            }
        });
    }
});

// Función para convertir fecha dd/mm/yyyy a yyyy-mm-dd para input date
function convertirFechaParaInput(fecha) {
    if (!fecha) return '';
    const partes = fecha.split('/');
    if (partes.length !== 3) return '';
    return `${partes[2]}-${partes[1].padStart(2, '0')}-${partes[0].padStart(2, '0')}`;
}

// Evento para abrir modal de edición de precio
$(document).on("click", ".btnEditar", function () {
    const fila = $(this).closest("tr");
    const idPrecio = fila.data("id");
    const precioText = fila.find("td:eq(0)").text().replace(/\./g, '');
    const fechaInicioText = fila.find("td:eq(1)").text();
    const fechaFinText = fila.find("td:eq(2)").text();

    // Cargar datos en modal
    $("#editIdPrecioVenta").val(idPrecio);
    $("#editPrecioVenta").val(precioText);
    $("#editFechaInicio").val(convertirFechaParaInput(fechaInicioText));
    $("#editFechaFin").val(fechaFinText ? convertirFechaParaInput(fechaFinText) : '');

    $("#modalEditarPrecio").modal("show");
});

// Evento para enviar formulario de edición
$("#formEditarPrecio").on("submit", function (e) {
    e.preventDefault();

    const datos = {
        IdPrecioVenta: $("#editIdPrecioVenta").val(),
        PrecioVenta: $("#editPrecioVenta").val(),          // Cambiado a PrecioVenta
        FechaInicio: $("#editFechaInicio").val(),
        FechaFin: $("#editFechaFin").val() || null
    };



    $.ajax({
        url: '/Producto/ActualizarPrecioVenta',
        type: 'POST',
        data: datos,
        success: function (resp) {
            if (resp.resultado) {
                alert("Precio actualizado correctamente");
                $("#modalEditarPrecio").modal("hide");
                // Recargar el historial para reflejar cambios
                const idProducto = $("#txtIdProducto").val();
                cargarHistorialPrecios(idProducto);
            } else {
                alert("Error al actualizar: " + resp.message);
            }
        },
        error: function () {
            alert("Error en la solicitud de actualización");
        }
    });
});

// Al hacer click en agregar fila nueva
$("#btnAgregarPrecio").click(function () {
    let nuevaFila = `<tr data-id="0">
        <td><input type="number" min="0" step="0.01" name="PrecioUnidadVenta" class="form-control" required></td>
        <td><input type="date" name="FechaInicio" class="form-control" required></td>
        <td><input type="date" name="FechaFin" class="form-control"></td>
        <td><button type="button" class="btn btn-danger btn-sm btnEliminarFila">Eliminar</button></td>
    </tr>`;
    $("#tbHistorialPrecios tbody").append(nuevaFila);
});

// Eliminar fila nueva
$(document).on("click", ".btnEliminarFila", function () {
    $(this).closest("tr").remove();
});

// Al enviar formulario principal para guardar múltiples precios
$("#formPrecios").submit(function (e) {
    e.preventDefault();

    const idProducto = $("#txtIdProducto").val();
    if (!idProducto || idProducto === "0") {
        alert("Seleccione un producto primero");
        return;
    }

    let precios = [];

    $("#tbHistorialPrecios tbody tr").each(function () {
        let idPrecioVenta = $(this).data("id") || 0;

        let precio = $(this).find('input[name="PrecioUnidadVenta"]').val();
        if (!precio) precio = $(this).find("td:eq(0)").text().replace(/\./g, '').trim();

        let fechaInicio = $(this).find('input[name="FechaInicio"]').val();
        if (!fechaInicio) {
            fechaInicio = convertirFechaParaInput($(this).find("td:eq(1)").text());
        }

        let fechaFin = $(this).find('input[name="FechaFin"]').val();
        if (!fechaFin) {
            fechaFin = convertirFechaParaInput($(this).find("td:eq(2)").text());
        }

        if (precio && fechaInicio) {
            precios.push({
                IdPrecioVenta: idPrecioVenta,
                IdProducto: idProducto,
                PrecioUnidadVenta: parseFloat(precio),
                FechaInicioVigencia: fechaInicio,
                FechaFinVigencia: fechaFin || null
            });
        }
    });


    $.ajax({
        url: '/Producto/GuardarMultiplesPrecios',
        type: 'POST',
        contentType: 'application/json',
        data: JSON.stringify(precios),
        success: function (resp) {
            if (resp.resultado) {
                alert("Precios guardados correctamente");
                cargarHistorialPrecios(idProducto);
            } else {
                alert("Error al guardar: " + resp.message);
            }
        },
        error: function () {
            alert("Error en la solicitud");
        }
    });
});
