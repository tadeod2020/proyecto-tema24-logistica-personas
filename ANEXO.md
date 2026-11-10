# ANEXO — Declaración de Asistencia de Inteligencia Artificial

**Materia:** Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026  
**Institución:** TecNM Campus Tijuana — Departamento de Sistemas y Computación  
**Estudiante:** Axel Tadeo Daniels Ceballos  
**Proyecto:** Tema 24 — Sistema Concurrente de Logística y Transporte de Personas en Erlang/OTP  
**Normativa:** Conforme a los lineamientos oficiales de [`AI_GUIDANCE.md`](https://github.com/tectijuana/programacionlogicayfuncional/blob/main/AI_GUIDANCE.md) y [`GRADING.md`](https://github.com/tectijuana/programacionlogicayfuncional/blob/main/GRADING.md)  

---

## 1. Nivel de Participación de IA Declarado

- **Nivel Declarado:** **Nivel 3 (Asistencia Estructurada en Código y Documentación)**
- **Herramienta Utilizada:** Google Gemini 3.8 Flash (High) / Antigravity Agentic Assistant.
- **Alcance del Apoyo:** Generación de la plantilla base para el supervisor y el servidor HTTP embebido, cálculo trigonométrico de Haversine y redacción de la estructura de casos de prueba.

---

## 2. Prompts Técnicos Utilizados

1. *"Necesito desarrollar un proyecto completo en Erlang/OTP para la materia Programación Lógica y Funcional en el TecNM Tijuana, correspondiente al Tema 24: Logística de Personas. Debe implementar el patrón Functional Core / Imperative Shell con un supervisor one_for_one, gen_server por unidad vehicular y gen_server coordinador de flota."*
2. *"Genera la función matemática pura en Erlang para calcular la distancia Haversine entre coordenadas geográficas, y una función de distancia de ruta que utilice recursión de cola con acumulador para garantizar espacio de stack O(1)."*
3. *"Implementa un servidor HTTP nativo y ligero en Erlang usando gen_tcp que exponga una API REST JSON para interactuar en tiempo real con una interfaz moderna basada en el sistema de diseño Google Stitch."*
4. *"Diseña una suite de pruebas con EUnit que valide casos base, casos de frontera (como sobrecupo mediante guards) y la recuperación automática ante 'exit(Pid, kill)' simulando la filosofía let it crash de OTP."*

---

## 3. Explicación Propia de una Decisión Técnica Central (Criterio Rúbrica 10 pts)

> **Decisión Técnica Central: Separación estricta entre el cálculo de rutas (`logistica_core`) y el ciclo de vida de los procesos (`logistica_unidad` / `logistica_gestor`).**

**Mi Justificación Técnica:**  
En el diseño de sistemas concurrentes con Erlang, un error frecuente de novato es acoplar la lógica matemática de las rutas, el filtrado de aforo y el cálculo de distancias dentro de los callbacks del `gen_server` (`handle_call`). 

Decidí conscientemente extraer toda esa lógica a un módulo independiente y puro: `logistica_core.erl`. Las razones fundamentales son:

1. **Aislamiento de la lógica funcional para pruebas:** `logistica_core` contiene únicamente funciones deterministas y referencialmente transparentes. Esto permitió escribir 11 pruebas en `logistica_tests.erl` que se ejecutan en **0.02 segundos**, sin necesidad de registrar procesos en la BEAM, levantar puertos de red ni lidiar con timeouts de comunicación inter-proceso.
2. **Inmutabilidad y protección del estado del actor:** El `gen_server` de cada unidad vehicular (`logistica_unidad`) únicamente delega el cálculo a `logistica_core:asignar_pasajero/2` o `logistica_core:avanzar_parada/1`. Si la función pura detecta que la unidad está llena, la cláusula guarda `when length(Pasajeros) < CapMax` rechaza la asignación retornando `{error, sin_cupo}`, dejando el record `#unidad{}` del actor **completamente intacto**, sin riesgo de que un estado corrupto o inconsistente quede almacenado en el proceso.
3. **Escalabilidad horizontal:** Al mantener las funciones matemáticas libres de estado, cualquier proceso de la máquina virtual (incluso distribuido en otro nodo del clúster con `erl -sname`) puede invocar los cálculos de distancia o itinerario sin generar cuellos de botella en un proceso central.

---

## 4. Cambios, Depuración y Validación Personal

- **Corrección de la prueba de supervisión:** Durante la primera ejecución de EUnit, el test de supervisión (`otp_supervisor_resiliencia_test`) terminaba con el proceso de prueba cancelado porque `start_link` enlazaba bidireccionalmente el supervisor al proceso del test runner; al matar el supervisor, la señal de salida terminaba al propio runner de EUnit. Lo corregí agregando `unlink(SupPid)` antes del shutdown, logrando que los 13 tests pasen con código de salida `0`.
- **Compatibilidad universal de JSON:** Para asegurar que el backend funcione tanto en máquinas de desarrollo recientes (con OTP 27+ y módulo `json`) como en instancias de laboratorio del TecNM con Ubuntu 22.04/24.04 (OTP 25/26), desarrollé un fallback recursivo puro en `logistica_json.erl`.
- **Validación con tests:** Se verificaron al 100% los 13 casos de prueba con `make test` y se validó en vivo el servidor web en `http://localhost:8080/`.

---

## 5. Declaración de Originalidad y Ética

Declaro que este trabajo refleja mi comprensión genuina de la programación funcional y concurrente con Erlang/OTP. La asistencia de la herramienta de IA fue utilizada como acelerador de scaffolding y consultoría técnica, asumiendo la autoría y la plena capacidad de defender cada línea de código ante el docente titular.

- **Firma del Estudiante:** Axel Tadeo Daniels Ceballos  
- **Fecha:** 10 de Noviembre de 2026  
- **Institución:** TecNM Campus Tijuana  
