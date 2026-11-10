# Prompt UI/UX Optimizado para Google Stitch

**Proyecto:** TransTijuana OTP — Sistema Concurrente de Logística y Transporte de Personas  
**Tema 24:** Programación Lógica y Funcional (TecNM Campus Tijuana)  
**Autor:** Axel Tadeo Daniels Ceballos  

---

## Prompt para Generador de UI/UX en Google Stitch

Copia y pega el siguiente prompt en el asistente de diseño de **Google Stitch** para generar o extender la interfaz gráfica del sistema:

```text
Actúa como un Lead Product Designer y Diseñador UI/UX especializado en interfaces de control operacional y telemetría en tiempo real (SaaS Dashboard). Diseña una interfaz web moderna, responsiva y de alta densidad de información para un "Sistema de Logística y Transporte Concurrente de Personas" en Tijuana, México, denominado "TransTijuana OTP".

1. Jerarquía Visual y Estilo (Google Stitch Design System):
- Paleta de Colores en Modo Oscuro (Dark Theme): Fondo principal pizarra profunda (#0a0f1d), tarjetas de superficie (#111827), bordes sutiles (#1e293b). Acentos vibrantes: Cian Eléctrico (#06b6d4) para rutas y datos primarios, Índigo (#6366f1) para marcas y botones de acción, Esmeralda (#10b981) para estado saludable de procesos OTP y unidades en servicio, Ámbar (#f59e0b) para alertas de alta ocupación y Rosa Carmesí (#f43f5e) para botones destructivos y fallas de procesos.
- Tipografía: 'Plus Jakarta Sans' para encabezados y componentes de interfaz; 'JetBrains Mono' para métricas numéricas, coordenadas y logs de terminal.
- Contenedores con radio de 12px a 16px, sombras suaves de elevación y blur de fondo (glassmorphism sutil).

2. Componentes y Distribución del Layout:
- Header Fijo Superior:
  * Logotipo con ícono de transporte y badge: "TEMA 24 · ERLANG / OTP".
  * Título: "TransTijuana OTP · Logística de Personas".
  * Subtítulo: "Axel Tadeo Daniels Ceballos · TecNM Campus Tijuana".
  * Tarjeta de Estado del Runtime BEAM: Indicador de pulso verde vivo con etiqueta "BEAM VM ACTIVA", contador de procesos ligeros, memoria en KB, número de schedulers y tiempo de actividad (uptime).

- Barra Superior de KPIs (5 Tarjetas Métricas):
  1. Personas Transportadas (conteo acumulado).
  2. Pasajeros a Bordo Actuales (fracción y aforo total).
  3. Ocupación de Flota (porcentaje dinámico con barra de progreso codificada por color: verde <60%, ámbar 60-85%, rojo >85%).
  4. Kilómetros Recorridos (distancia Haversine acumulada con 2 decimales).
  5. Resiliencia OTP (etiqueta "one_for_one", destacando el principio "let it crash").

- Barra de Acción Rápida:
  * Botón primario: "Avanzar Toda la Flota" con ícono de play.
  * Botón secundario: "Iniciar Auto-Simulación (3s)" con contador.
  * Botón outline: "+ Generar Pasajero Aleatorio".
  * Reloj digital de operaciones en formato HH:MM:SS.

- Contenedor Principal (Grid Asimétrico 60% / 40%):
  * Columna Izquierda (Visualización Operativa):
    A. Diagrama del Circuito Metropolitano: Nodos visuales de paradas en Tijuana (Otay TecNM, Central Alamar, Zona Río CECUT, Centro Revolución, Parque Industrial El Florido, Playas de Tijuana) con coordenadas GPS y chips dinámicos que muestran las unidades estacionadas en cada parada en tiempo real.
    B. Panel de Flota (gen_server por unidad): Tarjetas para Van Sprinter 01 (Estudiantil), Minibús Crafter 02 (Maquila), Microbús 03 (Costa) y Van Refuerzo 04. Cada tarjeta incluye badge de estado (en_ruta, en_parada, en_espera), indicador de aforo con barra de progreso, listado de pasajeros a bordo con origen y destino, botón "Avanzar Parada" y botón de emergencia en rojo "Crash (Let it crash)" para simular caídas controladas.

  * Columna Derecha (Interacción y Telemetría):
    A. Módulo de Despacho de Pasajeros: Formulario limpio con campo para nombre del pasajero, selector de parada origen y selector de parada destino. Botón de asignación con gradiente. Al confirmar, muestra tarjeta con animación de éxito indicando la unidad óptima asignada por algoritmo de orden superior en Erlang, kilometraje estimado y tiempo de arribo.
    B. Consola de Telemetría OTP: Ventana de terminal oscura de estilo hacker/monitoreo que muestra la secuencia viva de mensajes Erlang (eventos de abordaje, movimientos entre estaciones, alertas de sobrecupo y recuperación de procesos por el supervisor one_for_one).

3. Accesibilidad y Ergonomía:
- Cumplimiento WCAG AA en ratios de contraste.
- Estados activos y de foco visibles (:focus-visible).
- Notificaciones flotantes tipo Toast en la esquina inferior derecha para avisos de despacho y alertas de recuperación del supervisor.
```

---

## Características de la Implementación Frontend Construida

1. **Conexión REST Directa:** El frontend se conecta nativamente al backend Erlang/OTP en `http://localhost:8080/api/estado`.
2. **Polling No Bloqueante:** Sincroniza datos cada 1500 ms sin recargar la página.
3. **Manejo de Errores y Resiliencia:** Si una unidad cae por inyección de fallo, la interfaz detecta el reinicio del supervisor OTP y emite un toast de confirmación.
