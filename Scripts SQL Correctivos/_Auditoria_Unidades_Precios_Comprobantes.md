# Auditoría: Precios por categoría, Unidades de medida y Comprobantes

**Proyecto:** Sistema de Ventas ASP.NET MVC (tesis)
**Fecha:** 2026-05-29
**Alcance:** precios por categoría, unidad de medida en compras/ventas/cajas, notas de crédito y todos los comprobantes que se emiten (OC, OP, Venta, Comprobante de Cobro, Caja).

---

## 1. Resumen ejecutivo

El sistema **ya tiene implementada** la mayor parte de lo que se pidió. Lo construido funciona y es coherente; lo que falta son ajustes puntuales de **coherencia y completitud**, no una reconstrucción.

Lo que **ya está hecho** (no rehacer):

- `CATEGORIA.UnidadMedida` y `CATEGORIA.PorcentajeGanancia` y `CATEGORIA.DescuentoMaxPermitido` (scripts 89, 39, 57).
- Sincronización de la unidad de medida desde la categoría hacia el producto (`usp_ModificarCategoria`, script 89).
- Precio de venta sugerido por margen de categoría sobre el costo con IVA (`usp_ObtenerProductoTienda`, scripts 39 y 89).
- Unidad de medida ya viaja al **detalle de Venta** y al **detalle de Orden de Compra** (script 91 / 91b).
- Descuento por línea con tope por categoría aplicado al facturar (`usp_FacturarDesdeOrdenVenta`, script 89).

El **hueco más importante** es que la **cantidad sigue siendo entera (`INT`)** en toda la cadena, mientras que las unidades de medida (Metro, Kilo, Litro) **exigen decimales**. Hoy se puede marcar un cable como "Metro" pero no se puede comprar ni vender 1,5 m.

---

## 2. Matriz de coherencia por comprobante

| Comprobante | Muestra Unidad de medida | Soporta cantidad decimal | Precio/IVA correcto | Acción recomendada |
|---|---|---|---|---|
| **Orden de Compra (OC)** – `OrdenCompra/Documento` | ✅ (script 91b) | ❌ cantidad INT | ✅ | Pasar cantidad a decimal |
| **Compra / Recepción** – `Compra/Recepcion` | ✅ | ❌ INT | ✅ | Decimal + mostrar unidad en `Compra/Crear` |
| **Detalle de Compra** – `usp_ObtenerDetalleCompra` (script 22) | ❌ no trae UnidadMedida | ❌ INT | ✅ | Agregar `UnidadMedida` al SELECT |
| **Venta / Factura** – `Venta/Documento` | ✅ (script 91) | ❌ INT | ✅ | Pasar cantidad a decimal |
| **Orden de Venta (pre-venta)** – `OrdenVenta/Documento` | ❌ | ❌ INT | ✅ | Mostrar unidad + decimal |
| **Orden de Pago (OP)** – `OrdenPago/Documento` | N/A (documento de pago, sin líneas de producto) | N/A | ✅ verificar redondeo | Sólo verificar montos |
| **Comprobante de Cobro** – `ComprobanteCobro/Documento` | N/A (cobro, sin líneas) | N/A | ✅ verificar redondeo | Sólo verificar montos |
| **Caja / Arqueo** – `CajaVenta/*` | N/A (totales) | N/A | ✅ | Verificar cuadre con decimales |
| **Nota de Crédito Venta** – `NotaCreditoVenta/Consultar` | ❌ | ❌ INT | ✅ | Agregar unidad + decimal |
| **Nota de Crédito Compra** – `NotaCreditoCompra/Detalle` | ❌ | ❌ INT | ✅ | Agregar unidad + decimal |

Leyenda: ✅ correcto · ❌ falta · N/A no aplica (el documento no lista productos).

---

## 3. Hallazgos detallados

### 3.1 Cantidad entera vs. unidad de medida (PRIORIDAD ALTA)
Las columnas `Cantidad` (en `DETALLE_VENTA`, `DETALLE_ORDEN_VENTA`, `DetalleOrdenCompra`, `DETALLE_COMPRA`, notas de crédito) y `PRODUCTO_TIENDA.Stock` son enteras. Los procedimientos leen el XML con `value('(Cantidad)[1]','INT')`. Esto contradice tener unidades como Metro/Kilo/Litro.

**Impacto en tesis:** es la observación que un tribunal detectaría enseguida ("definieron unidad por metro pero no venden 2,5 m"). Resolverlo demuestra coherencia de diseño.

**Qué tocar:**
1. SQL: `ALTER COLUMN Cantidad DECIMAL(18,3)` en los detalles y `Stock DECIMAL(18,3)` (script provisto: `92_Cantidades_Decimales.sql`).
2. SQL: cambiar en los SPs `value(... ,'INT')` → `DECIMAL(18,3)`.
3. C#: en los modelos de `CapaModelo` cambiar `public int Cantidad` → `decimal Cantidad` (y `Stock`).
4. Vistas: inputs de cantidad con `type="number" step="0.001"` y formato de salida con la abreviatura de la unidad.

### 3.2 Unidad de medida ausente en comprobantes de Compra y Notas de Crédito (PRIORIDAD MEDIA)
- `usp_ObtenerDetalleCompra` (script 22) no devuelve `UnidadMedida`; la factura/consulta de compra no la muestra.
- Las dos notas de crédito (venta y compra) no muestran la unidad. Como la NC referencia las mismas líneas, conviene mostrarla para que el comprobante sea consistente con la factura origen.

### 3.3 Unidad de medida a nivel de catálogo (PRIORIDAD BAJA — mejora de normalización)
Hoy `UnidadMedida` es un `VARCHAR(20)` libre en Categoría y Producto. Funciona, pero para la tesis es más prolijo una **tabla catálogo `UnidadMedida`** (Descripcion, Abreviatura, PermiteDecimal) con FK desde Categoría. Beneficios: evita "Metro"/"metros"/"Mts" inconsistentes, y el flag `PermiteDecimal` automatiza si el input acepta decimales. Es opcional y se puede dejar como "trabajo futuro" si el tiempo aprieta.

### 3.4 Precio por categoría (YA RESUELTO — sólo sugerencias)
El margen por categoría funciona. Posibles mejoras para discutir con tutoría:
- Registrar el **margen efectivo real** por venta (precio venta vs. costo promedio) para el reporte de rentabilidad (ya existe `ReporteRentabilidad`, validar que use CPP).
- Permitir margen diferenciado por unidad (ej. venta por metro vs. por rollo) — sólo si el negocio lo requiere.

### 3.5 Comprobantes de pago/cobro y caja (VERIFICACIÓN)
OP, Comprobante de Cobro y Caja no listan productos, así que la unidad de medida no aplica. Lo único a verificar es el **redondeo de montos** una vez que las cantidades sean decimales, para que el total de la factura siga cuadrando con el cobro y con el arqueo de caja (evitar diferencias de ±1 Gs por redondeo).

---

## 4. Plan recomendado (incremental, para tutorías)

1. **Etapa 1 – Coherencia de cantidades decimales** (alto impacto): script `92_Cantidades_Decimales.sql` + cambios C#/vistas. *Empezar por acá.*
2. **Etapa 2 – Unidad en Compra y Notas de Crédito**: ampliar `usp_ObtenerDetalleCompra` y los SP/vistas de las dos NC.
3. **Etapa 3 – Verificación de redondeo** en OP, Cobro y Caja con cantidades decimales (casos de prueba).
4. **Etapa 4 (opcional) – Tabla catálogo `UnidadMedida`** con FK y `PermiteDecimal`.

---

## 5. Archivos entregados junto a esta auditoría
- `92_Cantidades_Decimales.sql` — migración de `Cantidad`/`Stock` a `DECIMAL(18,3)` y actualización de los SP afectados (idempotente, transaccional, con rollback comentado).

> Nota: el script altera **sólo** tipos de columnas y procedimientos; no borra datos. Hacer **backup** antes de ejecutar en la base real.
