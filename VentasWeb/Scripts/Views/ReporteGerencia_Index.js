// ============================================================
//  Reporte de Gerencia — Módulo Compras
//  Depende de: Chart.js 3.9.1, jQuery UI datepicker
// ============================================================

(function ($) {
    'use strict';

    // ── Chart instances ──────────────────────────────────────
    var chartMensual    = null;
    var chartOCEstado   = null;
    var chartProveedores= null;

    // ── Colors ───────────────────────────────────────────────
    var COLORS = {
        blue:    'rgba(37,  99, 235, 0.85)',
        green:   'rgba(16, 185, 129, 0.85)',
        cyan:    'rgba( 6, 182, 212, 0.85)',
        amber:   'rgba(245,158, 11, 0.85)',
        red:     'rgba(239, 68, 68, 0.85)',
        purple:  'rgba(124, 58,237, 0.85)',
        gray:    'rgba(107,114,128, 0.85)',
        indigo:  'rgba( 99,102,241, 0.85)',
        pink:    'rgba(236, 72,153, 0.85)',
        teal:    'rgba(20, 184,166, 0.85)'
    };
    var PALETTE = Object.values(COLORS);

    // ── Init ─────────────────────────────────────────────────
    $(document).ready(function () {
        initDatepickers();
        // Defaults: año en curso
        var hoy = new Date();
        var ini = '01/01/' + hoy.getFullYear();
        var fin = ('0' + (hoy.getDate())).slice(-2) + '/'
                + ('0' + (hoy.getMonth() + 1)).slice(-2) + '/'
                + hoy.getFullYear();
        $('#txtFechaInicio').val(ini);
        $('#txtFechaFin').val(fin);
    });

    function initDatepickers() {
        $('.datepicker-rg').datepicker({
            dateFormat:    'dd/mm/yy',
            changeMonth:   true,
            changeYear:    true,
            yearRange:     '-5:+0',
            maxDate:       0,
            firstDay:      1
        });
    }

    // ── Helpers ──────────────────────────────────────────────
    function formatearGS(valor) {
        if (valor === null || valor === undefined || isNaN(valor)) return '0';
        return Math.round(valor).toLocaleString('es-PY');
    }

    function mostrarSpinner(visible) {
        $('#spinner').css('display', visible ? 'inline-block' : 'none');
    }

    // ════════════════════════════════════════════════════════
    //  GENERAR REPORTE
    // ════════════════════════════════════════════════════════
    window.generarReporte = function () {
        var fi = $('#txtFechaInicio').val();
        var ff = $('#txtFechaFin').val();

        if (!fi || !ff) {
            Swal.fire('Atención', 'Ingrese las fechas de inicio y fin.', 'warning');
            return;
        }

        mostrarSpinner(true);
        $('#divReporte').hide();
        $('#btnPDF').prop('disabled', true);

        $.ajax({
            url:      $.MisUrls.url._RG_ObtenerDatos,
            type:     'GET',
            data: {
                fechainicio: fi,
                fechafin:    ff,
                idtienda:    $('#cboTienda').val() || 0
            },
            success: function (resp) {
                mostrarSpinner(false);
                if (!resp.resultado) {
                    Swal.fire('Error', resp.mensaje, 'error');
                    return;
                }
                renderReporte(resp.data);
                $('#divReporte').show();
                $('#btnPDF').prop('disabled', false);
            },
            error: function () {
                mostrarSpinner(false);
                Swal.fire('Error', 'No se pudo obtener los datos del reporte.', 'error');
            }
        });
    };

    // ════════════════════════════════════════════════════════
    //  RENDER COMPLETO
    // ════════════════════════════════════════════════════════
    function renderReporte(d) {
        // Encabezado
        $('#lblTituloReporte').text('Reporte de Gerencia — Compras · ' + d.NombreTienda);
        $('#lblPeriodo').text('Período: ' + d.FechaInicio + ' al ' + d.FechaFin);

        // KPIs
        renderKPIs(d.KPIs);

        // Gráficos
        renderChartMensual(d.ComprasMensuales);
        renderChartOCEstado(d.OrdenesPorEstado);
        renderChartProveedores(d.TopProveedores);

        // Resumen NC
        renderResumenNC(d.NotasCredito);

        // OCs fuera de plazo
        renderOCFuera(d.OCsFueraDePlazo);
    }

    // ── KPIs ─────────────────────────────────────────────────
    function renderKPIs(k) {
        $('#kpiTotalCompras').text(k.TotalCompras);
        $('#kpiMonto').text('Gs. ' + formatearGS(k.MontoTotalCompras));
        $('#kpiOCPendientes').text(k.OCPendientes);
        $('#kpiNCPendientes').text(k.MontoTotalNC > 0 ? formatearGS(k.MontoTotalNC) : '0');
        $('#kpiOCFuera').text(k.OCFueraPlazo);
        $('#kpiMontoNC').text('Gs. ' + formatearGS(k.MontoTotalNC));
    }

    // ── Gráfico 1: Compras por Mes (barras) ──────────────────
    function renderChartMensual(data) {
        var labels = [], montos = [], cantidades = [];
        $.each(data, function (i, row) {
            labels.push(row.MesNombre + ' ' + row.Anio);
            montos.push(row.Monto);
            cantidades.push(row.Cantidad);
        });

        if (chartMensual) { chartMensual.destroy(); }

        chartMensual = new Chart(document.getElementById('chartMensual'), {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label:           'Monto (Gs.)',
                        data:            montos,
                        backgroundColor: COLORS.blue,
                        borderColor:     COLORS.blue,
                        borderWidth:     1,
                        yAxisID:         'yMonto'
                    },
                    {
                        label:           'Cantidad',
                        data:            cantidades,
                        backgroundColor: COLORS.green,
                        borderColor:     COLORS.green,
                        borderWidth:     1,
                        type:            'line',
                        yAxisID:         'yCant',
                        tension:         0.3,
                        fill:            false
                    }
                ]
            },
            options: {
                responsive: true,
                interaction: { mode: 'index', intersect: false },
                plugins: {
                    legend: { position: 'bottom' },
                    tooltip: {
                        callbacks: {
                            label: function (ctx) {
                                if (ctx.dataset.yAxisID === 'yMonto')
                                    return ' Gs. ' + formatearGS(ctx.raw);
                                return ' ' + ctx.raw + ' compras';
                            }
                        }
                    }
                },
                scales: {
                    yMonto: {
                        type:     'linear',
                        position: 'left',
                        ticks: {
                            callback: function (v) {
                                return 'Gs. ' + formatearGS(v);
                            }
                        }
                    },
                    yCant: {
                        type:     'linear',
                        position: 'right',
                        grid:     { drawOnChartArea: false },
                        ticks:    { stepSize: 1 }
                    }
                }
            }
        });
    }

    // ── Gráfico 2: OC por Estado (dona) ──────────────────────
    function renderChartOCEstado(data) {
        var labels = [], counts = [], bgs = [];
        var estadoColor = {
            'Pendiente':  COLORS.amber,
            'Aprobada':   COLORS.green,
            'Rechazada':  COLORS.red,
            'Anulada':    COLORS.gray,
            'Facturada':  COLORS.blue,
            'Cerrada':    COLORS.purple
        };

        $.each(data, function (i, row) {
            labels.push(row.Estado);
            counts.push(row.Cantidad);
            bgs.push(estadoColor[row.Estado] || PALETTE[i % PALETTE.length]);
        });

        if (chartOCEstado) { chartOCEstado.destroy(); }

        chartOCEstado = new Chart(document.getElementById('chartOCEstado'), {
            type: 'doughnut',
            data: {
                labels:   labels,
                datasets: [{
                    data:            counts,
                    backgroundColor: bgs,
                    borderWidth:     2,
                    borderColor:     '#fff'
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: { position: 'bottom' },
                    tooltip: {
                        callbacks: {
                            label: function (ctx) {
                                var total = ctx.dataset.data.reduce(function (a, b) { return a + b; }, 0);
                                var pct   = total > 0 ? Math.round(ctx.raw / total * 100) : 0;
                                return ' ' + ctx.label + ': ' + ctx.raw + ' (' + pct + '%)';
                            }
                        }
                    }
                }
            }
        });
    }

    // ── Gráfico 3: Top proveedores (barra horizontal) ────────
    function renderChartProveedores(data) {
        var labels = [], montos = [];
        $.each(data, function (i, row) {
            labels.push(row.Proveedor);
            montos.push(row.MontoTotal);
        });

        if (chartProveedores) { chartProveedores.destroy(); }

        chartProveedores = new Chart(document.getElementById('chartProveedores'), {
            type: 'bar',
            data: {
                labels:   labels,
                datasets: [{
                    label:           'Monto Total (Gs.)',
                    data:            montos,
                    backgroundColor: PALETTE.slice(0, labels.length),
                    borderWidth:     1
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function (ctx) {
                                return ' Gs. ' + formatearGS(ctx.raw);
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        ticks: {
                            callback: function (v) {
                                return 'Gs. ' + formatearGS(v);
                            }
                        }
                    }
                }
            }
        });
    }

    // ── Resumen NC ────────────────────────────────────────────
    function renderResumenNC(nc) {
        var html = '';
        var items = [
            { lbl: 'Total NC',   val: nc.TotalNC,    cls: 'text-primary' },
            { lbl: 'Pendientes', val: nc.Pendientes,  cls: 'text-warning' },
            { lbl: 'Recibidas',  val: nc.Recibidas,   cls: 'text-success' },
            { lbl: 'Rechazadas', val: nc.Rechazadas,  cls: 'text-secondary' },
            { lbl: 'Morosas',    val: nc.Morosas,     cls: 'text-danger' },
            { lbl: 'Monto Total',val: 'Gs. ' + formatearGS(nc.MontoTotal), cls: 'text-dark' }
        ];
        $.each(items, function (i, it) {
            html += '<div class="col-sm-4 mb-3">'
                  +   '<div class="' + it.cls + ' font-weight-bold" style="font-size:1.4rem;">' + it.val + '</div>'
                  +   '<small class="text-muted">' + it.lbl + '</small>'
                  + '</div>';
        });
        $('#divResumenNC').html(html);
    }

    // ── OCs fuera de plazo ────────────────────────────────────
    function renderOCFuera(lista) {
        var tbody = $('#tbodyOCFuera').empty();

        if (!lista || lista.length === 0) {
            $('#divOCFuera table').hide();
            $('#sinOCFuera').show();
            return;
        }

        $('#divOCFuera table').show();
        $('#sinOCFuera').hide();

        var estadoColor = {
            'Pendiente':  'badge-Pendiente',
            'Aprobada':   'badge-Aprobada',
            'Rechazada':  'badge-Rechazada',
            'Anulada':    'badge-Anulada',
            'Facturada':  'badge-Facturada',
            'Cerrada':    'badge-Cerrada'
        };

        $.each(lista, function (i, row) {
            var bgClass = estadoColor[row.Estado] || '';
            var diasClass = row.DiasVencida > 30 ? 'text-danger font-weight-bold' : 'text-warning font-weight-bold';
            tbody.append(
                '<tr>'
              + '<td>' + (row.NumeroOrden  || '') + '</td>'
              + '<td>' + (row.Proveedor    || '') + '</td>'
              + '<td>' + (row.Tienda       || '') + '</td>'
              + '<td>' + (row.FechaTopeEntrega || '') + '</td>'
              + '<td class="text-right">Gs. ' + formatearGS(row.MontoEstimado) + '</td>'
              + '<td><span class="badge ' + bgClass + '">' + (row.Estado || '') + '</span></td>'
              + '<td class="text-center ' + diasClass + '">' + row.DiasVencida + ' días</td>'
              + '</tr>'
            );
        });
    }

    // ════════════════════════════════════════════════════════
    //  DESCARGAR PDF
    // ════════════════════════════════════════════════════════
    window.descargarPDF = function () {
        var fi = $('#txtFechaInicio').val();
        var ff = $('#txtFechaFin').val();

        if (!fi || !ff) {
            Swal.fire('Atención', 'Ingrese las fechas antes de descargar el PDF.', 'warning');
            return;
        }

        mostrarSpinner(true);
        $('#btnPDF').prop('disabled', true);

        // Crear form temporal para POST (descarga de archivo)
        var form = $('<form>', {
            method: 'POST',
            action: $.MisUrls.url._RG_DescargarPDF
        });

        form.append($('<input>', { type: 'hidden', name: 'fechainicio', value: fi }));
        form.append($('<input>', { type: 'hidden', name: 'fechafin',    value: ff }));
        form.append($('<input>', { type: 'hidden', name: 'idtienda',    value: $('#cboTienda').val() || 0 }));

        // Token CSRF si aplica (MVC AntiForgeryToken)
        var token = $('input[name="__RequestVerificationToken"]').val();
        if (token) {
            form.append($('<input>', { type: 'hidden', name: '__RequestVerificationToken', value: token }));
        }

        $('body').append(form);
        form.submit();
        form.remove();

        // Re-habilitar botón luego de un momento
        setTimeout(function () {
            mostrarSpinner(false);
            $('#btnPDF').prop('disabled', false);
        }, 4000);
    };

})(jQuery);
