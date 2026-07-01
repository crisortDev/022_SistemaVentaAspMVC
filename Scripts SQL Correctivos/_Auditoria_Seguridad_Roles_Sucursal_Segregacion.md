# Auditoría de seguridad: roles, sucursal y segregación O&M

**Fecha:** 2026-05-29 · **Alcance:** acceso por rol, aislamiento por sucursal, segregación de funciones O&M.

---

## 1. Veredicto general

El sistema tiene un control de acceso **bien arquitecturado en 3 capas**:

1. **Atributo `[AuthorizeRol(controlador, vista)]`** — valida contra el menú/permisos cargado en sesión al login. SuperAdmin (IdRol 14) pasa siempre. Sin sesión → denegado. Loguea los intentos denegados. ✅
2. **`BaseController`** — centraliza `EsSuperAdmin`, `TiendaActiva`, `TiendaOperativa` y `TienePermiso(idTienda)`. ✅
3. **Filtrado por tienda en los SP** — las listas reciben `@IdTienda` (0 = todas para SuperAdmin). ✅

La regla "cada usuario solo opera su sucursal, salvo SuperAdmin" **se cumple** en login (`TiendaActiva = usuario.IdTienda ?? 0`) y en casi todas las operaciones de escritura y de listado.

---

## 2. ✅ Lo que está correcto

**Aislamiento por sucursal en operaciones de escritura** — validan con `TienePermiso(idTienda)` antes de actuar:
- `Compra/Guardar` (L115), `OrdenCompra/Guardar` (L303), `OrdenCompra/Aprobar` (L380), `Rechazar` (L401), `Anular` (L420).
- `Producto/RegistrarProductoTienda` (L133), `Producto/BajaStock` (L348), `Inventario/RegistrarTraslado` (L46), `Inventario/BajarStock` (L90).

**Listados filtrados por sucursal** — fuerzan `idtienda = TiendaActiva` cuando no es SuperAdmin (ignoran el parámetro que mande el cliente):
- Compra, OrdenCompra, OrdenPago, Venta, OrdenVenta, ComprobanteCobro, NotaCredito (compra) y NotaCreditoVenta. ✅ Esto es lo correcto: aunque el usuario manipule el request, no ve otras sucursales.

**Caja por sucursal:**
- `CajaVenta/Index`, `Abrir`, `Reporte`, `Historial` usan `idTienda = EsSuperAdmin ? 0 : TiendaActiva`. Al abrir caja, un usuario normal **no puede elegir** otra tienda (L42-43). ✅
- La venta queda atada a la caja vía `TiendaOperativa` (caja abierta > tienda activa). ✅

**Segregación de funciones O&M** — implementada en los SP (no se puede saltar desde el front):
- OC: `usp_AprobarOrdenCompra` rechaza si `IdUsuarioRegistro = IdUsuarioAprobador` (script 15, L174). ✅
- Compra: `usp_ConfirmarCompraEImpactarStock` rechaza si el que confirma es el que registró (script 15 L394 / script 33 L393), salvo SuperAdmin. ✅
- Cobro a crédito: el CAJERO **no** puede cobrar cuentas; solo Supervisor/SuperAdmin (`ComprobanteCobro/Cobrar`). ✅
- Matriz de permisos por rol bien definida (script 37): Repositor/Cajero cargan, Encargado/Supervisor aprueban, Seguridad solo Admin/SuperAdmin. ✅

---

## 3. ⚠️ Hallazgo principal — IDOR en los métodos `Documento` (PDF) y algunos `Obtener*` por id

**Riesgo:** MEDIO-ALTO para la defensa (es el típico hallazgo que un tribunal sabe pedir).

Los métodos que reciben un **id directo** y devuelven el comprobante **no verifican que ese registro pertenezca a la sucursal del usuario**. Un usuario de la Sucursal B, autenticado y con permiso al módulo, puede ver el comprobante de la Sucursal A simplemente cambiando el número en la URL (ej. `/Venta/Documento?idVenta=123`).

Métodos afectados (todos hacen `return View(registro)` sin chequear tienda):

| Controlador | Método | Línea aprox. |
|---|---|---|
| `VentaController` | `Documento(int idVenta)` | 50 |
| `CompraController` | `Documento(int idcompra)` | 39 |
| `CompraController` | `ObtenerDetalleJson(int idcompra)` | 89 |
| `OrdenCompraController` | `Documento(int idordencompra)` | 56 |
| `OrdenCompraController` | `ObtenerDetalleOrdenCompra(int id)` | 226 |
| `OrdenCompraController` | `ObtenerOrden(int id)` | 265 |
| `OrdenPagoController` | `Documento(int idordenpago)` | 25 |
| `OrdenVentaController` | `ObtenerDetalle(int idOrdenVenta)` | 97 |
| `ComprobanteCobroController` | `Documento(int idCompCobro)` | 108 |

**Corrección recomendada (patrón uniforme):** después de traer el registro por id, comparar su `IdTienda` con la sesión:

```csharp
public ActionResult Documento(int idVenta = 0)
{
    var oVenta = CD_Venta.Instancia.ObtenerDocumento(idVenta);
    if (oVenta == null) return HttpNotFound();

    // ── Aislamiento por sucursal (SuperAdmin pasa) ──
    if (!TienePermiso(oVenta.IdTienda))
        return new HttpStatusCodeResult(403, "No tiene permiso para ver este comprobante de otra sucursal.");

    return View(oVenta);
}
```

Para los `JsonResult` usar el `AccesoDenegado()` que ya existe en `BaseController` en vez del 403.

> Nota: el riesgo es real pero acotado — requiere usuario válido y logueado. Aun así, romper el aislamiento entre sucursales es justo lo que se pide evitar, así que conviene cerrarlo.

---

## 4. ⚠️ Hallazgo secundario — Caja: operar una caja de otra sucursal por id

`CajaVenta/ObtenerOperaciones(int idCaja)`, `Cerrar(int idCaja, ...)`, `Arqueo(int idCaja)` y `ComprobanteApertura(int idCaja)` reciben el `idCaja` directo y **no verifican que esa caja sea de la tienda del usuario**. Un cajero podría cerrar/consultar la caja de otra sucursal pasando otro `idCaja`.

**Corrección:** validar la tienda dueña de la caja antes de operar:

```csharp
var caja = CD_CajaVenta.Instancia.ObtenerCajaPorId(idCaja);
if (caja == null) return Json(new { resultado = false, mensaje = "Caja no encontrada." });
if (!TienePermiso(caja.IdTienda)) return AccesoDenegado();
```

(Si `ObtenerCajaPorId` no existe, agregarlo en `CD_CajaVenta` — un SELECT simple por `IdCaja` que devuelva `IdTienda`.)

Idealmente `Cerrar` también debería validar que el cajero sea **quien abrió** la caja (o un supervisor), no solo la tienda.

---

## 5. Observaciones menores

- **`CompraController/Guardar`** deserializa el XML y valida `TienePermiso(detalleRoot.Compra.IdTienda)` ✅ — buen patrón, mantenerlo.
- **Doble defensa:** el filtrado por tienda en los listados está bien, pero la verdadera barrera de aislamiento debe estar **también** en el servidor por id (sección 3). Hoy los listados están protegidos; el acceso directo por id no.
- **SuperAdmin = IdRol 14 hardcodeado** en `BaseController` (`ID_ROL_SUPERADMIN = 14`) y en `LoginController`. Funciona, pero documentarlo como decisión de diseño para la tesis.
- **`NotaCreditoVenta/Registrar` y `AprobarRechazar`**: confirmar que el SP de NC venta también aplique segregación (que quien aprueba ≠ quien registró), como sí hace compras. Revisar `usp_*NotaCreditoVenta`.

---

## 6. Prioridad sugerida

1. **Cerrar IDOR de `Documento`/`ObtenerDetalle` por id** (sección 3) — alto impacto, bajo esfuerzo, patrón repetible.
2. **Validar dueño-tienda en operaciones de Caja por id** (sección 4).
3. Verificar segregación en NC de venta (sección 5).
4. Documentar en la tesis la matriz rol×módulo (script 37) y el modelo de aislamiento por sucursal como decisión de arquitectura.

Ninguno de estos hallazgos rompe el funcionamiento actual; son refuerzos de seguridad. La base ya está bien construida.
