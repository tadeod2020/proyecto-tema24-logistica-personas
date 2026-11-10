# Guía de Defensa Técnica y Arquitectura — TransTijuana OTP (Tema 24)

**Materia:** Programación Lógica y Funcional (ISC-2006) — Semestre Ago–Dic 2026  
**Institución:** TecNM Campus Tijuana — Departamento de Sistemas y Computación  
**Autor:** Axel Tadeo Daniels Ceballos  
**Docente Evaluador:** MC. René Solis R.  
**Proyecto:** Tema 24 — Sistema Concurrente de Logística y Transporte de Personas en Erlang/OTP  

---

## 1. Arquitectura del Sistema: Functional Core / Imperative Shell

El sistema sigue estrictamente el patrón arquitectónico **Functional Core / Imperative Shell**, ampliamente recomendado en la industria de sistemas concurrentes con Erlang/Elixir:

```
┌─────────────────────────────────────────────────────────────┐
│                   IMPERATIVE SHELL (OTP)                    │
│                                                             │
│  logistica_http.erl (gen_tcp / inets: red y sockets)        │
│                         │                                   │
│  logistica_sup.erl  (supervisor: estrategia one_for_one)    │
│       ├── logistica_gestor.erl (gen_server: despacho)       │
│       └── logistica_unidad.erl (gen_server: vehículos)      │
│                         │                                   │
├─────────────────────────┼───────────────────────────────────┤
│                         ▼                                   │
│                 FUNCTIONAL CORE (Puro)                      │
│                                                             │
│  logistica_core.erl                                         │
│  • Cero efectos secundarios, cero sockets, cero I/O         │
│  • Inmutabilidad estricta y funciones deterministas         │
│  • Recursión de cola con acumulador (O(1) stack)            │
│  • Geometría Haversine y cálculo de tiempos                 │
│  • Despacho óptimo con funciones de orden superior          │
│  • Manejo de aforo con pattern matching y guards            │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Justificación Técnica de las Decisiones de Diseño

### 2.1 ¿Por qué Erlang/OTP para Logística de Personas?
En un sistema de transporte metropolitano, las unidades vehiculares son **entidades autónomas concurrentes**. Modelarlas con hilos del sistema operativo (Java `Thread`, C++ `std::thread` o Python `threading`) presenta tres problemas graves:
1. **Consumo de memoria:** Un hilo de SO consume entre 1 MB y 8 MB de stack. En Erlang, un proceso BEAM inicia con solo **~2.5 KB de memoria** en su propio heap privado.
2. **Condiciones de carrera (Race Conditions):** En Erlang **no existe la memoria compartida**. Los procesos se comunican exclusivamente enviando copias inmutables de mensajes a través de sus buzones (`mailbox`). Por diseño, es imposible que dos procesos modifiquen la misma variable a la vez.
3. **Aislamiento de fallos:** Si el sensor GPS o el módulo de una van se desconecta o crashea en Java/C, puede tumbar toda la JVM. En Erlang, el proceso crashea de forma aislada y un `supervisor` lo reinicia sin que el resto del sistema lo note.

---

### 2.2 Recursión de Cola con Acumulador (Tail Call Optimization - TCO)
En `logistica_core:distancia_ruta/1` y en `separar_pasajeros_tail/4`, se utiliza recursión de cola.

#### Contraste Técnico:
- **Recursión Tradicional (No de cola):**
  ```erlang
  %% PELIGRO: Requiere mantener marcos en la pila para la suma pendiente (+)
  distancia_no_cola([P1, P2 | Resto]) ->
      distancia(P1, P2) + distancia_no_cola([P2 | Resto]).
  ```
  *Consecuencia:* Si la ruta tuviera 100,000 paradas, la pila acumula 100,000 marcos y produce un desbordamiento de pila (*stack overflow*). Complejidad espacial $O(N)$.

- **Recursión de Cola Implementada (`logistica_core`):**
  ```erlang
  distancia_ruta_tail([], Acc) -> Acc;
  distancia_ruta_tail([_], Acc) -> Acc;
  distancia_ruta_tail([P1, P2 | Resto], Acc) ->
      Tramo = distancia_entre_paradas(P1, P2),
      distancia_ruta_tail([P2 | Resto], Acc + Tramo). %% Última llamada es la recursiva
  ```
  *Ventaja:* El compilador BEAM reutiliza el marco actual del stack (*Tail Call Optimization*). La memoria consumida es constante $O(1)$, ejecutando en tiempo lineal $O(N)$ sin importar la cantidad de elementos.

---

### 2.3 Pattern Matching y Cláusulas Guarda (Guards)
En lugar de estructuras imperativas anidadas (`if`, `switch`, `try/catch`), el sistema define el comportamiento mediante pattern matching declarativo:

```erlang
asignar_pasajero(#unidad{pasajeros = Pasajeros, capacidad_max = CapMax, paradas = Paradas} = Unidad,
                 #pasajero{origen = Orig, destino = Dest} = Pasajero) ->
    case es_ruta_valida(Paradas, Orig, Dest) of
        false ->
            {error, parada_no_servida};
        true when length(Pasajeros) < CapMax ->
            NuevaLista = [Pasajero | Pasajeros],
            {ok, Unidad#unidad{pasajeros = NuevaLista, estado = en_ruta}};
        true ->
            {error, sin_cupo}
    end.
```
- La guarda `when length(Pasajeros) < CapMax` garantiza a nivel semántico que el aforo nunca se rebase.
- La expresión `[Pasajero | Pasajeros]` realiza la inserción en la cabeza de la lista inmutable con tiempo constante $O(1)$.

---

### 2.4 Árbol de Supervisión OTP: Estrategia `one_for_one`
El módulo `logistica_sup` define:
- `strategy => one_for_one`: Si el proceso `unidad_1` muere, el supervisor **únicamente reinicia a `unidad_1`**. No reinicia a `unidad_2`, ni a `unidad_3`, ni al `logistica_gestor`.
- `intensity => 10, period => 10`: Si una unidad falla más de 10 veces en 10 segundos (bucle catastrófico), el supervisor se detiene formalmente para evitar saturar el procesador, en lugar de ciclarse infinitamente.

---

## 3. Banco de Preguntas y Respuestas Técnicas para la Defensa Oral

### P1: ¿Por qué no utilizaste variables mutables ni bucles `for` o `while` en tu código?
**Respuesta:**  
En Erlang los datos son **estrictamente inmutables**; una variable una vez ligada jamás cambia su valor (*asignación única*). Esto elimina de raíz los efectos secundarios ocultos y las condiciones de carrera concurrentes. Los bucles imperativos `for` o `while` dependen de mutar un índice (`i++`); en su lugar, el paradigma funcional utiliza **recursión de cola con acumuladores** y **funciones de orden superior** (`lists:foldl/3`, `lists:filter/2`), donde cada ciclo genera un nuevo valor inmutable sin alterar el estado anterior.

---

### P2: ¿Qué es el modelo de actores y cómo se refleja en tu solución?
**Respuesta:**  
El modelo de actores establece que la unidad fundamental de cómputo es el "actor" (en Erlang, un proceso BEAM). Cada vehículo (`unidad_1`, `unidad_2`, etc.) y el `gestor` son actores independientes que:
1. Poseen su propio estado privado inmutable.
2. Poseen un buzón de mensajes secuencial (*mailbox*).
3. No comparten memoria; se comunican únicamente mediante mensajes asíncronos (`cast`) o peticiones síncronas (`call`).

---

### P3: ¿Qué diferencia existe entre `gen_server:call` y `gen_server:cast` y dónde usas cada uno?
**Respuesta:**  
- `gen_server:call/2` es **síncrono y bloqueante**: el proceso emisor envía el mensaje y espera una respuesta (`handle_call/3`) dentro de un timeout (default 5000 ms). Lo uso en operaciones que requieren confirmación inmediata, como `solicitar_viaje/3` o `obtener_estado/1`.
- `gen_server:cast/2` es **asíncrono y no bloqueante**: el emisor envía el mensaje y continúa su ejecución de inmediato sin esperar retorno (`handle_cast/2`). Lo uso para notificaciones y registros como `registrar_unidad/1`.

---

### P4: Explica la diferencia entre la estrategia `one_for_one` y `one_for_all` en un Supervisor OTP.
**Respuesta:**  
- En `one_for_one`, si un proceso hijo termina anormalmente, el supervisor **solo reinicia a ese hijo en particular**. Esta es la estrategia correcta para nuestra flota de transporte porque las unidades son autónomas; si la Van 01 se descompone, la Van 02 y el Gestor deben seguir operando normalmente.
- En `one_for_all`, si cualquier hijo muere, el supervisor **mata a todos los demás hijos y los reinicia a todos**. Esa estrategia solo tendría sentido si existiera una dependencia crítica estricta (por ejemplo, si una unidad no pudiera existir sin una base de datos local compartida que falló).

---

### P5: ¿Qué significa la filosofía "Let it crash" en Erlang y cómo la demuestras en tu proyecto?
**Respuesta:**  
"Let it crash" significa que en lugar de escribir código defensivo saturado de `try/catch` para anticipar cada posible fallo inesperado (corrupción de datos, fallos de red, bugs no contemplados), dejamos que el proceso que falló termine de inmediato (*crash fast*). 
En nuestro proyecto lo demostramos con la función `forzar_crash/2` (y el botón rojo en la UI Stitch): al ejecutar `exit(whereis(unidad_1), kill)`, el proceso de la unidad muere; el supervisor atrapa la señal de salida (`child_terminated`), e instantáneamente invoca la función de inicio (`start_link`) creando un nuevo proceso con un PID limpio y estado inicial seguro, restaurando la flota en milisegundos.

---

### P6: ¿Por qué el cálculo de distancias usa la fórmula de Haversine y cómo garantizas su pureza referencial?
**Respuesta:**  
La fórmula de Haversine calcula la distancia de círculo máximo sobre una esfera a partir de latitudes y longitudes geodésicas en radianes, lo cual es indispensable para la geografía real de Tijuana (las distancias euclidianas planas $\sqrt{\Delta x^2 + \Delta y^2}$ ignoran la curvatura terrestre y producen errores de escala).  
Garantizo su **transparencia referencial** porque `logistica_core:distancia_haversine/4` es una función matemática pura: para los mismos cuatro argumentos flotantes de entrada, siempre devolverá exactamente el mismo resultado en kilómetros, sin consultar archivos, variables globales ni el reloj del sistema.

---

### P7: ¿Qué ventaja tiene haber separado `logistica_core.erl` de los `gen_server`?
**Respuesta:**  
Cumple el principio de **Separación de Responsabilidades** (*Functional Core / Imperative Shell*). Toda la lógica de negocio (matemáticas de ruta, validación de paradas, filtrado de aforo, ordenación) es 100% testeable sin necesidad de levantar procesos, sockets ni la infraestructura de OTP. Esto permite que las pruebas en `logistica_tests.erl` se ejecuten en apenas **0.28 segundos**.

---

### P8: ¿Cómo evitaste las dependencias externas (como Cowboy o Rebar3 plugins complejos) en el servidor HTTP?
**Respuesta:**  
Implementé `logistica_http.erl` directamente con el módulo de sockets nativo `gen_tcp` de Erlang y soporte dual con el motor HTTP estándar de OTP. Esto garantiza que el proyecto compile y corra en **cualquier máquina virtual Linux** usando únicamente `erlc *.erl` y `erl`, sin requerir descargas de internet, paquetes npm ni dependencias rotas en el entorno del profesor.

---

### P9: ¿Cómo manejaste el formato JSON sin dependencias en diferentes versiones de Erlang?
**Respuesta:**  
Creé el módulo `logistica_json.erl`, que detecta en tiempo de ejecución si la máquina virtual cuenta con la función nativa `json:encode/1` (incorporada en Erlang/OTP 27+). Si existe, la utiliza; si el sistema corre en una versión previa como OTP 25 o 26 (común en repositorios oficiales de Ubuntu 22.04/24.04), conmuta automáticamente a un serializador funcional recursivo puro desarrollado a la medida.

---

### P10: ¿Qué ocurre con la memoria de los pasajeros cuando se desembarcan en una parada?
**Respuesta:**  
En `logistica_core:desembarcar_en_parada/2`, se utiliza recursión de cola para separar los pasajeros cuyo destino coincide con la parada actual. Los pasajeros desembarcados no se retienen en el nuevo record `#unidad{}`. Dado que cada proceso BEAM tiene su propio recolector de basura (*Garbage Collector*) generacional independiente y por proceso, la memoria de las estructuras desreferenciadas se limpia de forma inmediata y aislada, sin pausar los demás schedulers de la VM (*no stop-the-world GC*).

---

### P11: ¿Qué es una reducción en la BEAM VM y cómo se relaciona con la concurrencia preventiva?
**Respuesta:**  
En la BEAM, una "reducción" es una medida aproximada de trabajo computacional (básicamente una llamada a función). La máquina virtual implementa **multitarea preventiva**: cada proceso tiene asignado un presupuesto de aproximadamente 4,000 reducciones. Cuando un proceso agota sus reducciones, el scheduler lo suspende y le da turno al siguiente en la cola de listos. Esto garantiza que una unidad vehicular que esté realizando un cómputo pesado nunca congele el despacho de pasajeros ni el servidor web.

---

### P12: ¿Por qué utilizaste `lists:foldl/3` para seleccionar la mejor unidad en `logistica_core:buscar_mejor_unidad/3`?
**Respuesta:**  
`lists:foldl/3` es la abstracción funcional canónica de un *catamorfismo* o reducción de lista a un único valor. Recorre la lista de unidades candidatas acumulando la unidad que presente la menor relación de ocupación `length(Pasajeros) / CapacidadMax`. Es inmutable, no requiere variables de tracking externas y evalúa la lista en una sola pasada $O(N)$.

---

### P13: ¿Cómo se maneja la seguridad frente a datos mal formados en la API REST?
**Respuesta:**  
En `logistica_http:despachar_ruta/5`, cualquier payload JSON entrante se valida antes de interactuar con el gestor. Además, para convertir strings a átomos se utiliza `safe_binary_to_atom`, evitando el agotamiento de la tabla de átomos de la BEAM (*atom table exhaustion*) ante peticiones arbitrarias no controladas. Si los datos no cumplen la estructura esperada, la API responde de inmediato con `400 Bad Request` sin propagar el error al núcleo funcional.

---

### P14: ¿Cuál es el significado de los parámetros de supervisión `intensity` y `period` en `logistica_sup.erl`?
**Respuesta:**  
`intensity => 10` y `period => 10` configuran el umbral de tolerancia a reinicios del supervisor: permite hasta 10 reinicios dentro de una ventana de 10 segundos. Si una unidad crasheara 11 veces en ese lapso (lo que indicaría un error de configuración insalvable, no una falla transitoria), el supervisor aborta ordenadamente para evitar saturación de CPU por reinicios infinitos.

---

### P15: ¿Cómo se integra la interfaz de Google Stitch con la lógica de Erlang?
**Respuesta:**  
La interfaz de Google Stitch opera como un cliente desacoplado (HTML5/CSS3/Vanilla JS) que consume la API REST servida en el puerto 8080. El frontend realiza polling cada 1500 ms al endpoint `/api/estado`, obteniendo un payload JSON con las coordenadas de las unidades, pasajeros a bordo y telemetría de la BEAM. Las acciones del usuario (solicitar viaje, avanzar unidad, crash) envían peticiones `POST` que se traducen en llamadas `gen_server:call` en Erlang, reflejando los cambios de estado en pantalla de forma instantánea.
