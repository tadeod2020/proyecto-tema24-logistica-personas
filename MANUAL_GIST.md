# Manual de Usuario y Despliegue en VM — TransTijuana OTP (Tema 24)

**Materia:** Programación Lógica y Funcional (ISC-2006) — Semestre Ago–Dic 2026  
**Institución:** TecNM Campus Tijuana — Departamento de Sistemas y Computación  
**Autor:** Axel Tadeo Daniels Ceballos  
**Proyecto:** Tema 24 — Sistema Concurrente de Logística y Transporte de Personas en Erlang/OTP  
**Repositorio de Referencia:** [tectijuana/programacionlogicayfuncional](https://github.com/tectijuana/programacionlogicayfuncional)  

---

## 1. Propósito del Sistema

**TransTijuana OTP** es un sistema concurrente, tolerante a fallos y en tiempo real diseñado para coordinar la logística y despacho de personas (estudiantes del TecNM, personal corporativo y pasajeros urbanos) a través del corredor metropolitano de Tijuana, B.C.

Cada vehículo de transporte (van, minibús o microbús) se ejecuta como un **proceso BEAM aislado** mediante el comportamiento `gen_server` de Erlang/OTP, administrado por un **árbol de supervisión** con estrategia `one_for_one`. Si una unidad experimenta una falla crítica de hardware o desconexión, el sistema aplica la filosofía **"Let it crash"**: el supervisor reinicia el proceso en milisegundos sin interrumpir el resto de la flota ni desconectar a los usuarios.

---

## 2. Requisitos del Sistema y Compatibilidad

El sistema está verificado y listo para ejecutarse sin fricción en:
- **Plataformas objetivo:**
  - Ubuntu 24.04 LTS (Noble) / Ubuntu 22.04 LTS (Jammy) en arquitecturas **ARM64** (instancias AWS Academy EC2 `t4g.large` / `t4g.micro`) y **x86-64** (instancias `t2.micro` / `t3.medium` o entornos locales).
  - Debian 12 (Bookworm).
  - Arch Linux / CachyOS / macOS.
- **Herramientas requeridas:**
  - `erlang` (versiones OTP 25, 26, 27, 28 o 29).
  - `build-essential` y `make`.
  - `curl` (para pruebas HTTP) y navegador web moderno (Chrome, Firefox, Brave, Edge).

---

## 3. Instalación y Puesta en Marcha (Paso a Paso)

### Paso 3.1: Clonar o posicionarse en el proyecto
```bash
cd "/home/axeld/Programacion Logica y Funcional/proyecto-tema24-logistica-personas"
```

### Paso 3.2: Aprovisionamiento automatizado de la VM
Ejecuta el script de aprovisionamiento que valida e instala las dependencias necesarias:
```bash
./setup.sh
```
*Salida esperada:*
```text
[+] Erlang/OTP detectado correctamente: Release OTP 25+
[+] Compilando módulos Erlang en ebin/...
[+] Ejecutando suite de pruebas automatizadas EUnit...
    All 13 tests passed.
[+] ¡PROYECTO LISTO PARA EJECUCIÓN!
```

### Paso 3.3: Ejecución del Backend Erlang y Servidor HTTP
Para iniciar el sistema de transporte y el servidor web:
```bash
./run.sh
```
El sistema iniciará el servidor HTTP nativo en el puerto `8080` y abrirá la consola interactiva de Erlang:
```text
=============================================================
  SISTEMA CONCURRENTE DE LOGÍSTICA DE PERSONAS (TEMA 24)
  Autor: Axel Tadeo Daniels Ceballos — TecNM Campus Tijuana
  Entorno: Erlang/OTP BEAM
=============================================================
[logistica_http] Servidor Web REST activo en http://localhost:8080/
1>
```

---

## 4. Acceso y Uso de la Interfaz Web (Google Stitch UI)

Abre tu navegador e ingresa a:
```
http://localhost:8080/
```
*(Si estás en una instancia remota de AWS EC2, sustituye `localhost` por la IP pública de tu instancia: `http://TU_IP_PUBLICA:8080/` y asegúrate de tener abierto el puerto TCP 8080 en el Security Group).*

---

### Guía Visual y Flujo de Usuario

#### A. Telemetría de la BEAM VM y KPIs de Flota
En la barra superior se visualiza en tiempo real:
- Estado del runtime (`BEAM VM ACTIVA`).
- Procesos ligeros concurrentes, memoria consumida en KB, schedulers por núcleo y uptime.
- Total acumulado de personas transportadas, pasajeros a bordo y porcentaje de ocupación global con barra de colores dinámica.

> *[ESPACIO PARA CAPTURA DE PANTALLA: Dashboard superior con KPIs y telemetría de memoria BEAM]*

---

#### B. Mapa Esquemático de Tijuana
El circuito metropolitano muestra los 6 nodos clave con distancias Haversine:
1. **Otay (TecNM Campus Tijuana)**
2. **Terminal Central Alamar**
3. **Zona Río (CECUT)**
4. **Centro Histórico (Revolución)**
5. **Parque Industrial El Florido**
6. **Playas de Tijuana (Malecón)**

Cada nodo muestra una insignia (badge) en tiempo real con las unidades que se encuentran actualmente estacionadas en dicha parada.

> *[ESPACIO PARA CAPTURA DE PANTALLA: Nodos del circuito metropolitano con unidades dockeadas]*

---

#### C. Solicitud y Despacho de Pasajeros
1. En el panel **"Solicitar Transporte de Pasajero"**:
   - Ingresa el nombre (ej. `Axel Daniels`).
   - Selecciona parada de origen (ej. `Otay - TecNM Tijuana`).
   - Selecciona parada de destino (ej. `Centro Histórico`).
2. Haz clic en **"Asignar Unidad Óptima (Despacho OTP)"**.
3. **Resultado:** El algoritmo de orden superior (`logistica_core:buscar_mejor_unidad/3`) analiza las rutas y balancea la carga, asignando la unidad disponible con menor aforo relativo, calculando la distancia en km y el tiempo estimado en minutos.

> *[ESPACIO PARA CAPTURA DE PANTALLA: Formulario de despacho con confirmación exitosa del ticket]*

---

#### D. Avance de Flota y Desembarque
- Haz clic en **"Avanzar Parada"** en una unidad individual o en **"Avanzar Toda la Flota"**.
- La unidad transita al siguiente punto del itinerario. Si algún pasajero a bordo tenía como destino esa parada, es **desembarcado automáticamente mediante recursión de cola** y se incrementa el contador de "Personas Transportadas".

> *[ESPACIO PARA CAPTURA DE PANTALLA: Tarjeta de unidad avanzando con desembarque de pasajeros]*

---

#### E. Demostración en Vivo de Resiliencia: "Let it crash"
1. En cualquiera de las tarjetas de unidad (ej. `UNIDAD_1`), haz clic en el botón rojo **"Crash (Let it crash)"**.
2. **Lo que ocurre tras bambalinas en Erlang:**
   - Se inyecta una señal de terminación abrupta `exit(Pid, kill)`.
   - El supervisor OTP (`logistica_sup`) detecta la señal de salida.
   - Aplica la estrategia `one_for_one`: crea inmediatamente un nuevo proceso con un PID diferente y restaura el estado operativo seguro.
   - Las otras tres unidades (`unidad_2`, `unidad_3`, `unidad_4`) y el `gestor` continúan respondiendo peticiones sin un solo milisegundo de caída.
   - La interfaz Stitch muestra una alerta Toast: *"🛡️ ¡Supervisor OTP reinició UNIDAD_1 automáticamente!"*.

> *[ESPACIO PARA CAPTURA DE PANTALLA: Notificación Toast de recuperación automática del supervisor tras un Crash]*

---

## 5. Pruebas Automatizadas y Demostración en Terminal

Para ejecutar la verificación formal de la rúbrica con todos los casos de prueba y reporte de resiliencia:

```bash
./test_demo.sh
```

### Casos de prueba ejecutados:
| Caso | Módulo Evaluado | Entrada | Salida Esperada | Estado |
|---|---|---|---|---|
| **1** | `haversine_cero` | Coordenadas idénticas (Otay) | `0.0 km` | ✅ PASS |
| **2** | `haversine_otay_centro` | Otay (TecNM) ➔ Centro | `~7.01 km` | ✅ PASS |
| **3** | `distancia_ruta_tail` | 4 paradas consecutivas | Suma acumulada en cola ($O(N)$, stack $O(1)$) | ✅ PASS |
| **4** | `asignar_valido` | Pasajero con cupo | `{ok, #unidad{}}` con estado `en_ruta` | ✅ PASS |
| **5** | `sobrecupo_guard` | Pasajero en unidad con $aforo = cap$ | `{error, sin_cupo}` rechazado por guard | ✅ PASS |
| **6** | `ruta_invalida` | Sentido inverso en ruta | `{error, parada_no_servida}` | ✅ PASS |
| **7** | `desembarque_tail` | 2 pasajeros (1 con destino actual) | Separación en cola: 1 desembarca, 1 se queda | ✅ PASS |
| **8** | `ciclo_completo` | Unidad avanza al final | Incrementa `viajes_completados` y vuelve al inicio | ✅ PASS |
| **9** | `balanceo_carga` | 2 unidades con diferente aforo | Selecciona unidad más vacía vía `lists:foldl/3` | ✅ PASS |
| **10**| `gen_server_call` | Peticiones síncronas | Manejo ordenado de buzón de mensajes | ✅ PASS |
| **11**| `supervisor_recovery`| `exit(Pid, kill)` en unidad | Supervisor reinicia con nuevo PID (< 150 ms) | ✅ PASS |

---

## 6. Endpoints de la API REST

| Método | Endpoint | Descripción | Ejemplo de Respuesta |
|---|---|---|---|
| `GET` | `/api/estado` | Snapshot completo de flota, métricas y paradas | `{"exito": true, "unidades": [...], "metricas": {...}}` |
| `GET` | `/api/unidades` | Lista de unidades vehiculares activas | `[{"id": "unidad_1", "pasajeros_actuales": 2, ...}]` |
| `GET` | `/api/metricas` | Telemetría BEAM VM y estadísticas | `{"beam_procesos": 50, "total_transportados": 14, ...}` |
| `POST` | `/api/solicitar` | Despachar pasajero a la mejor unidad | `{"exito": true, "unidad_asignada": "unidad_1", ...}` |
| `POST` | `/api/avanzar` | Avanzar una unidad o toda la flota | `{"exito": true, "desembarcados": [...]}` |
| `POST` | `/api/crash` | Simular falla forzada de proceso BEAM | `{"exito": true, "accion": "let_it_crash"}` |

---

## 7. Solución de Problemas Comunes (Troubleshooting)

### Problema 1: `Puerto 8080 ya está en uso (eaddrinuse)`
- **Causa:** Otro servicio o una ejecución previa de Erlang sigue ocupando el puerto.
- **Solución:** El servidor detecta automáticamente el conflicto e intenta en el puerto siguiente (`8081`). Para liberar el puerto 8080:
  ```bash
  fuser -k 8080/tcp || sudo kill $(lsof -t -i:8080)
  ```

### Problema 2: `erl: command not found`
- **Causa:** Erlang no está instalado o no se encuentra en el `$PATH`.
- **Solución:** Ejecuta `./setup.sh` o en Ubuntu/Debian:
  ```bash
  sudo apt-get update && sudo apt-get install -y erlang erlang-eunit
  ```

### Problema 3: Error de permisos al ejecutar scripts `.sh`
- **Solución:** Otorga permisos de ejecución:
  ```bash
  chmod +x *.sh
  ```

---

*Manual generado conforme a los estándares de entrega del TecNM Campus Tijuana. Autor: Axel Tadeo Daniels Ceballos.*
