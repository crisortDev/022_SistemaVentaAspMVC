const tablaElement = $('#tbCompras');
let tabla; // Variable global para DataTable

$(document).ready(() => {
    inicializarDataTable();

    $('#btnBuscar').on('click', () => {
        buscar();
    });
});

function inicializarDataTable() {
    tabla = tablaElement.DataTable({
        serverSide: true,
        processing: true,
        ajax: {
            url: $.MisUrls.url._BuscarMovimientosCaja,
            type: 'POST',
            data: d => {
                d.FechaInicio = $('#txtFechaInicio').val();
                d.FechaFin = $('#txtFechaFin').val();
            },
            dataSrc: json => {
                console.log("Respuesta del servidor:", json);
                return json.data;
            },
            error: (xhr, error, thrown) => {
                console.error("Error en la solicitud Ajax:", xhr.responseText);
            }
        },
        columns: [
            { data: null, defaultContent: '', orderable: false },
            { data: 'NumeroFactura' },
            { data: 'NumeroTimbrado' },
            {
                data: 'FechaTransaccion',
                render: data => parseNetDate(data)
            },
            {
                data: 'MontoOperacion',
                render: $.fn.dataTable.render.number(',', '.', 2, '')
            },
            {
                data: 'EstadoPago',
                render: function (data) {
                    if (data && data.toLowerCase() === 'pagado') {
                        return `<span style="color: green; font-weight: bold;">
                            &#10003; ${data}
                        </span>`;
                    }
                    return data;
                }
            },
            {
                data: null,
                orderable: false,
                render: (data, type, row) => renderAcciones(row)
            }
        ],

        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json'
        }
    });
}

// Recarga la tabla con los filtros actuales
function buscar() {
    if (tabla) {
        tabla.ajax.reload(null, false);
    }
}

// Convierte fecha .NET JSON /Date(...) a formato legible
function parseNetDate(netDate) {
    if (!netDate) return '';
    const timestamp = parseInt(netDate.replace(/\/Date\((\d+)\)\//, '$1'));
    const date = new Date(timestamp);

    // Opciones para toLocaleDateString (dd/MM/yyyy hh:mm)
    const options = {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    };
    return date.toLocaleDateString('es-ES', options);
}

// Genera botones "Pagar" y "Cancelar"
function renderAcciones(row) {
    return `
        <button class="btn btn-success btn-sm me-1" onclick="pagar(${row.IdMovimiento}, this)">Pagar</button>
        <button class="btn btn-danger btn-sm" onclick="cancelar(${row.IdMovimiento}, this)">Cancelar</button>
    `;
}

// Función para marcar como pagado el movimiento
function pagar(idMovimiento, btn) {
    const fila = tabla.row($(btn).closest('tr')).data();
    if (fila.EstadoPago && fila.EstadoPago.toLowerCase() === 'pagado') {
        Swal.fire({
            icon: 'info',
            title: 'Aviso',
            text: 'Esta compra ya está marcada como pagada.',
            confirmButtonText: 'Aceptar'
        });
        return;
    }

    // Reemplazamos confirm() por SweetAlert2
    Swal.fire({
        title: '¿Seguro que deseas marcar esta compra como pagada?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Aceptar',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            ejecutarPago(idMovimiento, btn);
        }
    });
}

// Extraemos la llamada AJAX a otra función para separar la lógica
function ejecutarPago(idMovimiento, btn) {
    const boton = $(btn);
    boton.prop('disabled', true).text('Procesando...');

    $.ajax({
        url: $.MisUrls.url._PagarMovimiento,
        type: 'POST',
        data: { idMovimiento },
        success: function (response) {
            if (response.resultado) {
                Swal.fire({
                    icon: 'success',
                    title: 'Éxito',
                    text: 'Compra marcada como pagada correctamente.',
                    confirmButtonText: 'Aceptar'
                });
                tabla.ajax.reload(null, false);
            } else {
                Swal.fire({
                    icon: 'error',
                    title: 'Error',
                    text: 'No se pudo actualizar el estado.',
                    confirmButtonText: 'Aceptar'
                });
            }
        },
        error: function (xhr, status, error) {
            Swal.fire({
                icon: 'error',
                title: 'Error',
                text: 'Error en la solicitud: ' + error,
                confirmButtonText: 'Aceptar'
            });
        },
        complete: function () {
            boton.prop('disabled', false).html('Pagar');
        }
    });
}

// Función para cancelar el movimiento con SweetAlert2
function cancelar(idMovimiento, btn) {
    Swal.fire({
        title: '¿Seguro que deseas cancelar esta compra?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Aceptar',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            ejecutarCancelar(idMovimiento, btn);
        }
    });
}

function ejecutarCancelar(idMovimiento, btn) {
    const boton = $(btn);
    boton.prop('disabled', true).text('Procesando...');

    $.ajax({
        url: $.MisUrls.url._CancelarMovimiento,
        type: 'POST',
        data: { idMovimiento },
        success: function (response) {
            if (response.resultado) {
                Swal.fire({
                    icon: 'success',
                    title: 'Éxito',
                    text: 'Compra cancelada correctamente.',
                    confirmButtonText: 'Aceptar'
                });
                tabla.ajax.reload(null, false);
            } else {
                Swal.fire({
                    icon: 'error',
                    title: 'Error',
                    text: 'No se pudo cancelar la compra.',
                    confirmButtonText: 'Aceptar'
                });
            }
        },
        error: function (xhr, status, error) {
            Swal.fire({
                icon: 'error',
                title: 'Error',
                text: 'Error en la solicitud: ' + error,
                confirmButtonText: 'Aceptar'
            });
        },
        complete: function () {
            boton.prop('disabled', false).html('Cancelar');
        }
    });
}
