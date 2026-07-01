# Checklist — Cantidades decimales (capa C# y vistas)

Acompaña a los scripts **92** (columnas) y **93** (procedimientos). Orden de aplicación:

1. Backup de la base.
2. Ejecutar `92_Cantidades_Decimales.sql`.
3. Ejecutar `93_SPs_Cantidad_Decimal.sql`.
4. Aplicar los cambios C# de abajo en Visual Studio y **compilar** (el compilador te marca lo que falte).
5. Ajustar las vistas (inputs decimales).
6. Probar los casos de la sección final.

---

## 1. CapaModelo — YA APLICADO por mí ✅

Cambié `int` → `decimal` en las propiedades de cantidad/stock de estos modelos:

- `DetalleVenta.cs` → `Cantidad`
- `DetalleOrdenCompra.cs` → `Cantidad`, `CantidadFacturada`
- `DetalleCompra.cs` → `Cantidad`, `CantidadFacturada`, `CantidadRecibida`
- `LineaRecepcionOC.cs` → `CantidadRecibida`
- `OrdenVenta.cs` (clase `DetalleOrdenVenta`) → `Cantidad`, `StockDisponible`
- `ProductoTienda.cs` → `Stock`, `StockMinimo`, `StockMaximo`
- `StockTienda.cs` → `Stock`, `StockMinimo`, `StockMaximo`
- `ValidaStockMaximo.cs` → `Stock`, `Cantidad` (interno)
- `Traslado.cs` → todos los `Cantidad*`/`Stock*`

> Revisá si `NotaCredito.cs` / `NotaCreditoVenta.cs` necesitan `Cantidad` decimal: en la versión actual esos modelos NO exponen `Cantidad` por línea (trabajan con `Monto`), así que no requieren cambio. Si más adelante agregás detalle por línea a la NC, usá `decimal`.

---

## 2. CapaDatos — APLICAR MANUALMENTE (compila en VS)

Lista EXACTA de líneas detectadas (auditadas el 2026-05-29). Cambiar `Convert.ToInt32` → `Convert.ToDecimal` y `int.Parse` → `Convert.ToDecimal(..., CultureInfo.InvariantCulture)`. Los números de línea son orientativos (pueden moverse al editar).

**Importante:** las columnas `CantidadVentas` (conteo de ventas en Caja/PuntoCaja) y los `Id...` son conteos enteros legítimos → **NO** tocarlos. Sólo cantidades de producto y stock.

### `CD_Compra.cs`
- L272: `Cantidad = int.Parse(producto.Element("Cantidad")?.Value ?? "0")`
  → `Convert.ToDecimal(producto.Element("Cantidad")?.Value ?? "0", CultureInfo.InvariantCulture)`
- L273: `CantidadRecibida = ... int.Parse(...)` → `Convert.ToDecimal(..., CultureInfo.InvariantCulture)`
- L355: `cmd.Parameters.Add("Cantidad", SqlDbType.Int).Value = Cantidad;` → `SqlDbType.Decimal` (Precision 18, Scale 3). También la **firma** del método `ValidaStockMaximo(int IdProducto, int Cantidad, int Tienda)` → `decimal Cantidad`.

### `CD_Compra.Revision.cs`
- L178: `Cantidad = Convert.ToInt32(dr["Cantidad"])` → `Convert.ToDecimal(...)`
- L180: `CantidadFacturada = Convert.ToInt32(dr["CantidadFacturada"])` → `Convert.ToDecimal(...)`
- L182: `CantidadRecibida = Convert.ToInt32(dr["CantidadRecibida"])` → `Convert.ToDecimal(...)`

### `CD_Inventario.cs`
- L87: `Cantidad = Convert.ToInt32(dr["Cantidad"])` → `Convert.ToDecimal(...)`
- L154: `Stock = Convert.ToInt32(dr["Stock"])` → `Convert.ToDecimal(...)`
- L192-194: `Stock`, `StockMinimo`, `StockMaximo = Convert.ToInt32(...)` → `Convert.ToDecimal(...)`
- Parámetros de SP de traslado/baja que usen `SqlDbType.Int` para cantidad → `SqlDbType.Decimal`.

### `CD_OrdenCompra.cs`
- L253: `Cantidad = int.Parse(p.Element("Cantidad")?.Value ?? "0")` → `Convert.ToDecimal(..., CultureInfo.InvariantCulture)`
- L254: `CantidadFacturada = int.Parse(...)` → `Convert.ToDecimal(..., CultureInfo.InvariantCulture)`

### `CD_OrdenVenta.cs`
- L182: `Cantidad = Convert.ToInt32(dr["Cantidad"])` → `Convert.ToDecimal(...)`
- L187: `StockDisponible = Convert.ToInt32(dr["StockDisponible"])` → `Convert.ToDecimal(...)`

### `CD_Venta.cs`
- L281: `Cantidad = Convert.ToInt32(dr["Cantidad"])` → `Convert.ToDecimal(...)`

### `CD_ProductoTienda.cs`
- L76: `Stock = ... Convert.ToInt32(dr["Stock"])` → `Convert.ToDecimal(dr["Stock"])`
- L211: `cmd.Parameters.AddWithValue("Cantidad", Cantidad)` → pasar un `decimal` (la firma `ControlarStock(..., int Cantidad, ...)` y `BajaStock...(int cantidad)` → `decimal`).
- L282: `int stockActual = Convert.ToInt32(stockObj);` → `decimal stockActual = Convert.ToDecimal(stockObj);` (y el mensaje y comparación siguen igual).
- L114-115: `AddWithValue("StockMinimo"/"StockMaximo", ...)` → ahora reciben decimal (ok con AddWithValue si el modelo ya es decimal).

### `CD_Producto.cs`
- L51: `StockMaximo = ... Convert.ToInt32(dr["StockMaximo"])` → `Convert.ToDecimal(...)`

### `CD_Reportes.cs`
- L163: `Cantidad = Convert.ToInt32(dr["Cantidad"])` → `Convert.ToDecimal(...)` (sólo si el modelo de ese reporte usa cantidad de producto; si es un conteo, dejar).

### `CD_ReporteGerencia.cs`
- L73, L87: `Cantidad = L<int>(dr,"Cantidad")` → `L<decimal>(dr,"Cantidad")` (verificar que el helper `L<T>` soporte decimal).

> **NO tocar:** `CD_CajaVenta.cs` L82/L150/L242/L278 y `CD_PuntoCaja.cs` L86 → son `CantidadVentas`/conteos enteros de operaciones, no cantidades de producto.

**Helper recomendado** para parámetros decimales:
```csharp
using System.Globalization;
...
var p = cmd.Parameters.Add("Cantidad", SqlDbType.Decimal);
p.Precision = 18; p.Scale = 3; p.Value = cantidad;
```

---

## 3. Capa Web (Controllers / armado de XML)

Donde se construye el XML de detalle (ventas, OC, recepción) revisar que la cantidad se serialice con **punto decimal** y cultura invariante, no con coma:
```csharp
cantidad.ToString(System.Globalization.CultureInfo.InvariantCulture)
```
Esto evita que "1,5" rompa el `value(...,'DECIMAL(18,3)')` del SP.

---

## 4. Vistas (.cshtml + JS)

En los inputs de cantidad de estas vistas, permitir decimales:

- `Venta/Crear.cshtml`, `Venta/Facturar.cshtml`
- `Compra/Crear.cshtml`, `Compra/Recepcion.cshtml`
- `OrdenCompra/Crear.cshtml`
- `OrdenVenta/Crear.cshtml`
- `Inventario/Traslado.cshtml`, `Inventario/Baja.cshtml`

Cambios:
- `<input type="number" step="0.001" min="0" ... />` (antes probablemente `step="1"` o sin step).
- En el JS que arma el total de línea, usar `parseFloat()` en vez de `parseInt()`.
- Al mostrar, formatear con la unidad: `15,5 m`, `0,250 Kg`, `2 Un.` (usá el campo `UnidadMedida` que ya viene del SP).

---

## 5. Comprobantes — completar unidad donde falta (etapa 2)

Estos comprobantes aún NO muestran la unidad de medida; ampliarlos:

- **Compra** (`Compra/Documento.cshtml`): `usp_ObtenerDetalleCompra` (script 22) no devuelve `UnidadMedida`. Agregar `ISNULL(p.UnidadMedida,'Unidad') AS UnidadMedida` al SELECT del detalle y mostrarlo.
- **Nota de Crédito (compra)** y **Nota de Crédito Venta**: agregar la unidad junto a la cantidad en su vista/SP de detalle, para que el comprobante sea consistente con la factura origen.

No aplican (no listan productos): Orden de Pago, Comprobante de Cobro, Caja/Arqueo. Ahí sólo verificar redondeo (sección 6).

---

## 6. Pruebas de verificación (mínimas para la tesis)

1. Crear producto en categoría con unidad "Metro". Comprar **2,5 m** vía OC → recepción → confirmar. Verificar que el stock quede **2,500** y no 2.
2. Vender **1,250 m** de ese producto. Verificar:
   - Total de la factura correcto.
   - El comprobante de cobro cuadra con el total (sin diferencia de ±1 Gs).
   - El arqueo de caja del día cierra sin diferencia.
3. Generar Nota de Crédito sobre una compra con diferencia decimal y verificar el monto.
4. Confirmar que ningún SP quedó parseando INT: correr la consulta de verificación al final del script 93 (debe volver vacío salvo SP que no manejen cantidad de producto).
