// CuentasPorCobrar_Index.js  — Cuentas por Cobrar (cuotas + crédito clásico)
'use strict';

var dtCXC       = null;
var _montoTotal = 0;
var _datosCompletos = [];   // cache completo para los resúmenes

$(function () {
    dtCXC = $('#tbCXC').DataTable({
        data: [],
        autoWidth: false,
        dom: '<"row"<"col-sm-6"l><"col-sm-6">>rt<"row"<"col-sm-6"i><"col-sm-6"p>>',
        language: { url: $.MisUrls.url.Url_datatable_spanish },
        order: [[4, 'asc']],   // ordenar por vencimiento ascendente
        columns: [
            // 0 — Factura + cuota
            {
                data: null,
                render: function (d) {
                    var esNueva  = d.IdComprobanteCobro < 0;
                    var condicion = d.Condicion || '';
                    var badge = '';
                    if (esNueva) {
                        // "Cuota 1/6" → badge azul con número de cuota
                        badge = '<br><span class="badge badge-primary" style="font-size:11px;">'
                              + '<i class="fas fa-layer-group mr-1"></i>' + condicion + '</span>';
                    } else {
                        // Sistema antiguo — mostrar plazo si existe
                        var plazo = d.PlazoCredito ? d.PlazoCredito + ' días' : 'Crédito';
                        badge = '<br><span class="badge badge-secondary" style="font-size:11px;">'
                              + '<i class="fas fa-clock mr-1"></i>' + plazo + '</span>';
                    }
                    return '<code style="font-size:12px;">' + (d.NumeroFactura || '—') + '</code>' + badge;
                }
            },
            // 1 — Cliente (nombre + documento)
            {
                data: null,
                render: function (d) {
                    return '<div class="font-weight-bold" style="font-size:13px;">' + escapar2(d.NombreCliente || '—') + '</div>'
                         + '<div class="text-muted" style="font-size:11px;"><i class="fas fa-id-card mr-1"></i>'
                         + (d.NumeroDocumento || '—') + '</div>';
                }
            },
            // 2 — Teléfono
            { data: 'TelefonoCliente', defaultContent: '—', className: 'text-center' },
            // 3 — Monto
            {
                data: 'MontoTotal',
                className: 'text-right font-weight-bold',
                render: function (v) { return 'Gs. ' + formatGs(v); }
            },
            // 4 — Vencimiento (con badge de estado urgencia)
            {
                data: null,
                render: function (d) {
                    var v    = d.FechaVencimiento || '—';
                    var dias = d.DiasParaVencer;
                    var badge = '';
                    if (dias === null || dias === undefined) {
                        badge = '';
                    } else if (dias < 0) {
                        badge = '<br><span class="badge badge-danger" style="font-size:10px;">'
                              + '<i class="fas fa-exclamation-circle mr-1"></i>Vencida hace '
                              + Math.abs(dias) + 'd</span>';
                    } else if (dias === 0) {
                        badge = '<br><span class="badge badge-danger" style="font-size:10px;">'
                              + '<i class="fas fa-exclamation-triangle mr-1"></i>Vence HOY</span>';
                    } else if (dias <= 3) {
                        badge = '<br><span class="badge badge-danger" style="font-size:10px;">'
                              + '<i class="fas fa-exclamation-triangle mr-1"></i>En ' + dias + 'd</span>';
                    } else if (dias <= 7) {
                        badge = '<br><span class="badge badge-warning text-dark" style="font-size:10px;">'
                              + '<i class="fas fa-clock mr-1"></i>En ' + dias + 'd</span>';
                    } else {
                        badge = '<br><span class="badge badge-success" style="font-size:10px;">'
                              + dias + ' días</span>';
                    }
                    return '<span style="font-size:13px;">' + v + '</span>' + badge;
                }
            },
            // 5 — Estado
            {
                data: 'Estado',
                className: 'text-center',
                render: function (v) {
                    if (v === 'Vencida')
                        return '<span class="badge badge-danger px-2 py-1">'
                             + '<i class="fas fa-times-circle mr-1"></i>Vencida</span>';
                    return '<span class="badge badge-warning text-dark px-2 py-1">'
                         + '<i class="fas fa-hourglass-half mr-1"></i>Pendiente</span>';
                }
            },
            // 6 — Tienda
            { data: 'NombreTienda', defaultContent: '—', className: 'text-center small' },
            // 7 — Emisión
            { data: 'FechaEmision', defaultContent: '—', className: 'small text-center' },
            // 8 — columna oculta: cliente para búsqueda
            {
                data: null,
                visible: false,
                searchable: true,
                render: function (d) {
                    return (d.NombreCliente || '') + ' ' + (d.NumeroDocumento || '');
                }
            },
            // 9 — columna oculta: factura para búsqueda
            { data: 'NumeroFactura', visible: false, searchable: true },
            // 10 — columna oculta: estado para búsqueda
            { data: 'Estado', visible: false, searchable: true },
            // 11 — Acción
            {
                data: null,
                orderable: false,
                className: 'text-center',
                render: function (d) {
                    // Solo Supervisor(11), Encargado(6), Admin(1), SuperAdmin(14) pueden cobrar
                    var rolesPermitidos = [1, 6, 11, 14];
                    if (!AppSession.esSuperAdmin && rolesPermitidos.indexOf(AppSession.idRol) === -1) {
                        return '<span class="text-muted small">—</span>';
                    }
                    return '<button class="btn btn-success btn-sm px-2" '
                         + 'onclick="abrirModalCobrar(' + d.IdComprobanteCobro
                         + ',\'' + escapar(d.NumeroFactura) + '\''
                         + ',\'' + escapar(d.NombreCliente) + '\''
                         + ',' + d.MontoTotal
                         + ',\'' + (d.FechaVencimiento || '—') + '\''
                         + ',\'' + escapar(d.Condicion) + '\')">'
                         + '<i class="fas fa-dollar-sign mr-1"></i>Cobrar</button>';
                }
            }
        ]
    });

    buscarCXC();
});

// ─── Cargar datos desde servidor ──────────────────────────────────────────────
function buscarCXC() {
    $.get($.MisUrls.url._CC_ObtenerPendientes, { soloVencidas: false }, function (r) {
        _datosCompletos = r.data || [];
        dtCXC.clear().rows.add(_datosCompletos).draw();
        actualizarResumen(_datosCompletos);
        filtrarTabla();   // aplicar filtros activos si los hay
    });
}

// ─── Filtrado en cliente / factura / estado ───────────────────────────────────
function filtrarTabla() {
    var cliente = $('#txtFiltroCliente').val().trim();
    var factura = $('#txtFiltroFactura').val().trim();
    var estado  = $('#cboFiltroEstado').val();

    // Columnas ocultas: 8=cliente, 9=factura, 10=estado
    dtCXC.column(8).search(cliente, false, true)
         .column(9).search(factura, false, true)
         .column(10).search(estado, false, false)
         .draw();

    // Recalcular resumen sobre los datos filtrados (visible rows)
    var filas = [];
    dtCXC.rows({ search: 'applied' }).data().each(function (d) { filas.push(d); });
    actualizarResumen(filas);
}

function limpiarFiltros() {
    $('#txtFiltroCliente').val('');
    $('#txtFiltroFactura').val('');
    $('#cboFiltroEstado').val('');
    filtrarTabla();
}

// ─── Tarjetas resumen ─────────────────────────────────────────────────────────
function actualizarResumen(lista) {
    var totPend = 0, cantPend = 0;
    var totVenc = 0, cantVenc = 0;
    var totProx = 0, cantProx = 0;
    var totDia  = 0, cantDia  = 0;

    lista.forEach(function (r) {
        var monto = r.MontoTotal || 0;
        var dias  = r.DiasParaVencer;

        totPend  += monto;
        cantPend += 1;

        if (dias !== null && dias !== undefined) {
            if (dias < 0)       { totVenc += monto; cantVenc++; }
            else if (dias <= 7) { totProx += monto; cantProx++; }
            else                { totDia  += monto; cantDia++;  }
        }
    });

    $('#lblTotalPendiente').text('Gs. ' + formatGs(totPend));
    $('#lblCantPendiente').text(cantPend + (cantPend === 1 ? ' cuota' : ' cuotas'));

    $('#lblTotalVencidas').text('Gs. ' + formatGs(totVenc));
    $('#lblCantVencidas').text(cantVenc + (cantVenc === 1 ? ' cuota' : ' cuotas'));

    $('#lblTotalPorVencer').text('Gs. ' + formatGs(totProx));
    $('#lblCantPorVencer').text(cantProx + (cantProx === 1 ? ' cuota' : ' cuotas'));

    $('#lblTotalAlDia').text('Gs. ' + formatGs(totDia));
    $('#lblCantAlDia').text(cantDia + (cantDia === 1 ? ' cuota' : ' cuotas'));
}

// ─── Abrir modal de cobro ─────────────────────────────────────────────────────
function abrirModalCobrar(idCompCobro, factura, cliente, montoTotal, vencimiento, condicion) {
    _montoTotal = montoTotal;
    $('#hdnIdCompCobro').val(idCompCobro);
    $('#infoNumeroFactura').text(factura);
    $('#infoCliente').text(cliente);
    $('#infoMontoTotal').text('Gs. ' + formatGs(montoTotal));
    $('#infoVencimiento').text(vencimiento);

    // Mostrar cuota con badge
    var esNueva = idCompCobro < 0;
    if (esNueva) {
        $('#infoCuota').html('<span class="badge badge-primary px-2 py-1" style="font-size:13px;">'
            + '<i class="fas fa-layer-group mr-1"></i>' + condicion + '</span>');
    } else {
        $('#infoCuota').html('<span class="badge badge-secondary px-2 py-1" style="font-size:13px;">'
            + condicion + '</span>');
    }

    $('#ddlFormaCobro').val(0);
    $('#txtMontoRecibido').val('');
    $('#txtObservacion').val('');
    $('#alertCambio').hide();
    $('#alertaFormasCobro').remove();

    // Filtrar formas de pago según apertura de caja
    var apertura = parseFloat($('#hdnMontoAperturaFondo').val()) || 0;
    var $select  = $('#ddlFormaCobro');
    $select.find('option').show().prop('disabled', false);

    if (apertura === 0) {
        $select.find('option').filter(function () {
            return $(this).text().trim().toLowerCase() === 'efectivo';
        }).hide().prop('disabled', true);

        $select.closest('.form-group').prepend(
            '<div class="alert alert-warning py-1 px-2 mb-2" id="alertaFormasCobro" style="font-size:12px;">'
            + '<i class="fas fa-info-circle mr-1"></i>'
            + 'Caja sin fondo — solo formas de pago sin efectivo (Transferencia, etc.).'
            + '</div>'
        );
    }

    $('#modalCobrar').modal('show');
    setTimeout(function () { $('#txtMontoRecibido').focus(); }, 400);
}

// ─── Calcular cambio ──────────────────────────────────────────────────────────
function calcularCambio() {
    var recibido = parseFloat($('#txtMontoRecibido').val()) || 0;
    var cambio   = recibido - _montoTotal;
    var $alert   = $('#alertCambio');
    if (recibido > 0) {
        $alert.show();
        if (cambio >= 0) {
            $alert.removeClass('alert-danger').addClass('alert-info');
            $('#lblCambio').text('Gs. ' + formatGs(cambio));
        } else {
            $alert.removeClass('alert-info').addClass('alert-danger');
            $('#lblCambio').text('Monto insuficiente — faltan Gs. ' + formatGs(Math.abs(cambio)));
        }
    } else {
        $alert.hide();
    }
}

// ─── Confirmar cobro ──────────────────────────────────────────────────────────
function confirmarCobro() {
    var idCompCobro  = parseInt($('#hdnIdCompCobro').val()) || 0;
    var idFormaCobro = parseInt($('#ddlFormaCobro').val()) || 0;
    var montoRec     = parseFloat($('#txtMontoRecibido').val()) || 0;
    var obs          = $('#txtObservacion').val();

    if (!idCompCobro) { toastr.error('No se identificó el registro a cobrar.'); return; }
    if (!idFormaCobro) { toastr.warning('Seleccioná una forma de cobro.'); return; }
    if (montoRec <= 0) { toastr.warning('Ingresá el monto recibido.'); return; }
    if (montoRec < _montoTotal) {
        toastr.warning('El monto recibido (Gs. ' + formatGs(montoRec) + ') es menor al total (Gs. ' + formatGs(_montoTotal) + ').');
        return;
    }
    if (!obs.trim()) { toastr.warning('La Observación es obligatoria.'); $('#txtObservacion').focus(); return; }

    Swal.fire({
        title: '¿Confirmar cobro?',
        html:  'Total: <strong>Gs. ' + formatGs(_montoTotal) + '</strong><br>'
             + 'Recibido: <strong>Gs. ' + formatGs(montoRec) + '</strong><br>'
             + 'Cambio: <strong>Gs. ' + formatGs(montoRec - _montoTotal) + '</strong>',
        icon:  'question',
        showCancelButton:  true,
        confirmButtonText: 'Sí, registrar',
        confirmButtonColor: '#28a745',
        cancelButtonText:  'Cancelar'
    }).then(function (res) {
        if (!res.isConfirmed) return;

        $('#btnConfirmarCobro').prop('disabled', true)
            .html('<i class="fas fa-spinner fa-spin mr-1"></i>Registrando...');

        $.ajax({
            url:    $.MisUrls.url._CC_Cobrar,
            method: 'POST',
            data:   { idCompCobro: idCompCobro, idFormaCobro: idFormaCobro,
                      montoRecibido: montoRec, observacion: obs },
            success: function (r) {
                if (r.resultado) {
                    $('#modalCobrar').modal('hide');
                    toastr.success(r.mensaje || 'Cobro registrado.');
                    buscarCXC();
                    if (r.idCompCobro) {
                        window.open($.MisUrls.url._CC_Documento + '?idCompCobro=' + r.idCompCobro, '_blank');
                    }
                } else {
                    toastr.error(r.mensaje || 'Error al registrar cobro.');
                }
            },
            error: function () { toastr.error('Error de conexión.'); },
            complete: function () {
                $('#btnConfirmarCobro').prop('disabled', false)
                    .html('<i class="fas fa-check mr-1"></i>Confirmar Cobro');
            }
        });
    });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function formatGs(n) { return Math.round(n || 0).toLocaleString('es-PY'); }
function escapar(s)  { return (s || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'"); }
function escapar2(s) { return (s || '').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
