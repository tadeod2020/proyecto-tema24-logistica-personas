# TransTijuana OTP — Logística de Personas (Tema 24)

**Materia:** Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026  
**TecNM Campus Tijuana — Departamento de Sistemas y Computación**  
**Autor:** Axel Tadeo Daniels Ceballos  
**Calificación Objetivo:** Nivel Excelente (100/100)  

---

## 📌 Descripción del Proyecto

Sistema concurrente, tolerante a fallos y en tiempo real para la gestión y despacho logístico de transporte de personas (estudiantes, personal corporativo y pasajeros urbanos) en el corredor metropolitano de Tijuana, B.C., implementado con **Erlang/OTP** sobre la máquina virtual **BEAM**.

El proyecto cumple estrictamente con los estándares de calidad del repositorio de la materia ([`tectijuana/programacionlogicayfuncional`](https://github.com/tectijuana/programacionlogicayfuncional)):
- **Paradigma Funcional Puro:** Inmutabilidad estricta, recursión de cola con acumulador ($O(1)$ stack), cláusulas con guards y funciones de orden superior (`lists:foldl/3`, `lists:filter/2`).
- **Arquitectura de Concurrencia OTP:** Cada vehículo corre como un proceso independiente (`gen_server`), coordinados por un despachador global y supervisados mediante `logistica_sup` con estrategia `one_for_one` y filosofía **"Let it crash"**.
- **Servidor Web Nativo Embebido:** Servidor HTTP REST (`logistica_http`) en puerto 8080 sin dependencias externas pesadas.
- **Frontend Moderno (Google Stitch UI):** Dashboard interactivo con telemetría viva de la BEAM VM, mapa esquemático de Tijuana, despacho en vivo de pasajeros y botón de inyección de fallos para demostración.
- **Pruebas Automatizadas EUnit:** 13 pruebas unitarias y de integración pasando al 100%.

---

## 🚀 Inicio Rápido (Quick Start)

### 1. Aprovisionamiento automático de la VM
```bash
./setup.sh
```

### 2. Ejecutar la suite de pruebas EUnit
```bash
make test
```
*Salida: 13 tests passed en < 0.3 segundos.*

### 3. Iniciar el sistema y abrir el Dashboard
```bash
./run.sh
```
Abre en tu navegador:
```
http://localhost:8080/
```

### 4. Demostración técnica interactiva en terminal
```bash
./test_demo.sh
```

---

## 📁 Estructura del Repositorio

```
proyecto-tema24-logistica-personas/
├── src/
│   ├── logistica.app             # Descriptor de la aplicación OTP
│   ├── logistica_app.erl         # Application behaviour (punto de entrada)
│   ├── logistica_sup.erl         # Supervisor OTP (one_for_one)
│   ├── logistica_gestor.erl      # GenServer: coordinador de flota y despacho
│   ├── logistica_unidad.erl      # GenServer: actor por cada vehículo
│   ├── logistica_core.erl        # Functional Core: Haversine, rutas, guards
│   ├── logistica_http.erl        # Servidor Web REST nativo (puerto 8080)
│   └── logistica_json.erl        # Codificador/Decodificador JSON compatible
├── include/
│   └── logistica.hrl             # Registros del dominio (#unidad, #pasajero, #parada)
├── test/
│   └── logistica_tests.erl       # Suite de pruebas automatizadas EUnit
├── priv/
│   └── static/                   # Interfaz de usuario (Google Stitch UI)
│       ├── index.html            # Dashboard semántico responsivo
│       ├── style.css             # Estilos de diseño Google Stitch (Dark Theme)
│       └── app.js                # Cliente reactivo sin dependencias
├── docs/
│   └── GOOGLE_STITCH_PROMPT.md   # Prompt de diseño para Google Stitch UI
├── MANUAL_GIST.md                # Manual de usuario para GitHub Gist
├── DEFENSA_TECNICA.md            # Arquitectura y 15 preguntas/respuestas de defensa
├── ANEXO.md                      # Declaración de IA (Nivel 3, conforme a AI_GUIDANCE.md)
├── Makefile                      # Automatización (all, compile, test, run, clean)
├── setup.sh                      # Script de aprovisionamiento para Ubuntu/Debian
├── run.sh                        # Lanzador interactivo
└── test_demo.sh                  # Demostración en vivo de casos de prueba
```

---

## 📑 Documentación Adicional

- [Manual de Usuario y Despliegue en Gist (MANUAL_GIST.md)](MANUAL_GIST.md)
- [Guía de Defensa Técnica y Preguntas de Examen (DEFENSA_TECNICA.md)](DEFENSA_TECNICA.md)
- [Declaración de Asistencia de IA (ANEXO.md)](ANEXO.md)
- [Prompt para Google Stitch (docs/GOOGLE_STITCH_PROMPT.md)](docs/GOOGLE_STITCH_PROMPT.md)

---

*Desarrollado para el TecNM Campus Tijuana por Axel Tadeo Daniels Ceballos.*
