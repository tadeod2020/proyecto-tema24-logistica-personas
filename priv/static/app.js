/**
 * TransTijuana OTP · Dashboard de Logística y Transporte de Personas
 * Autor: Axel Tadeo Daniels Ceballos · TecNM Campus Tijuana
 * Tema 24: Concurrencia y Resiliencia en Erlang/OTP
 */

const API_BASE = window.location.origin;

let estadoLocal = null;
let autoSimularInterval = null;
let logLineasVistas = new Set();

const NOMBRES_ALEATORIOS = [
    "Ana Martínez", "Carlos Delgado", "Valeria Gómez", "Eduardo Rivas", 
    "Sofía Mendoza", "Gabriel Estrada", "Mariana Fuentes", "Javier Ochoa",
    "Fernanda Ramos", "Daniel Castillo", "Camila Villalobos", "Rodrigo Vega"
];

const PARADAS_CLAVE = ["otay", "central_camionera", "zona_rio", "centro", "el_florido", "playas"];

// =====================================================================
// Inicialización
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
    actualizarReloj();
    setInterval(actualizarReloj, 1000);

    // Cargar estado inicial y comenzar polling
    refrescarEstado();
    setInterval(refrescarEstado, 1500);

    // Event Listeners
    document.getElementById('form-solicitar').addEventListener('submit', manejarSolicitudPasajero);
    document.getElementById('btn-avanzar-todas').addEventListener('click', () => avanzarUnidad('todas'));
    document.getElementById('btn-auto-simular').addEventListener('click', alternarAutoSimulacion);
    document.getElementById('btn-generar-pasajero').addEventListener('click', generarPasajeroAleatorio);
    document.getElementById('btn-limpiar-consola').addEventListener('click', () => {
        document.getElementById('terminal-log').innerHTML = '';
        logLineasVistas.clear();
    });
});

// =====================================================================
// Polling y Renderizado Principal
// =====================================================================

async function refrescarEstado() {
    try {
        const res = await fetch(`${API_BASE}/api/estado`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        estadoLocal = data;

        renderizarMetricas(data.metricas);
        renderizarMapa(data.paradas, data.unidades);
        renderizarUnidades(data.unidades);
        renderizarBitacora(data.metricas.bitacora);
    } catch (err) {
        console.warn('Error al sincronizar con el backend Erlang:', err);
    }
}

function renderizarMetricas(m) {
    if (!m) return;
    document.getElementById('metric-procesos').textContent = m.beam_procesos || '--';
    document.getElementById('metric-memoria').textContent = `${(m.beam_memoria_kb || 0).toLocaleString()} KB`;
    document.getElementById('metric-schedulers').textContent = m.beam_schedulers || '--';
    document.getElementById('metric-uptime').textContent = `${m.uptime_segundos || 0}s`;

    document.getElementById('kpi-transportados').textContent = m.total_transportados || 0;
    document.getElementById('kpi-a-bordo').textContent = `${m.pasajeros_a_bordo} / ${m.capacidad_total}`;
    
    const pct = m.porcentaje_ocupacion || 0;
    document.getElementById('kpi-ocupacion').textContent = `${pct}%`;
    const pb = document.getElementById('kpi-progress-ocupacion');
    pb.style.width = `${Math.min(pct, 100)}%`;
    if (pct > 85) pb.style.background = 'var(--accent-rose)';
    else if (pct > 60) pb.style.background = 'var(--accent-amber)';
    else pb.style.background = 'linear-gradient(90deg, var(--accent-cyan), var(--accent-indigo))';

    document.getElementById('kpi-kilometros').textContent = `${m.kms_flota_acumulados} km`;
    document.getElementById('badge-unidades-count').textContent = `${m.unidades_activas} de ${m.unidades_totales} Activas`;
}

function renderizarMapa(paradas, unidades) {
    const container = document.getElementById('circuit-map');
    if (!paradas || !container) return;

    // Mapear unidades por parada actual
    const unidadesPorParada = {};
    (unidades || []).forEach(u => {
        const parada = u.parada_actual;
        if (!unidadesPorParada[parada]) unidadesPorParada[parada] = [];
        unidadesPorParada[parada].push(u);
    });

    container.innerHTML = paradas.map(p => {
        const docked = unidadesPorParada[p.id] || [];
        const chipsHtml = docked.map(u => 
            `<span class="docked-chip" title="${u.nombre}">${u.id.replace('unidad_', 'Van ')}</span>`
        ).join('');

        return `
            <div class="stop-node">
                <div class="stop-header">
                    <span class="stop-dot"></span>
                    <span class="stop-name">${p.nombre.split(' - ')[0]}</span>
                </div>
                <div class="stop-coords">${p.lat.toFixed(4)}, ${p.lon.toFixed(4)}</div>
                <div class="stop-docked">
                    ${chipsHtml || '<span style="font-size:0.7rem;color:var(--text-muted);">Sin unidades</span>'}
                </div>
            </div>
        `;
    }).join('');
}

function renderizarUnidades(unidades) {
    const container = document.getElementById('units-container');
    if (!unidades || !container) return;

    container.innerHTML = unidades.map(u => {
        const pasajerosCount = u.pasajeros_actuales || 0;
        const capMax = u.capacidad_max || 15;
        const pct = Math.round((pasajerosCount / capMax) * 100);

        let fillClass = 'fill-low';
        if (pct >= 85) fillClass = 'fill-high';
        else if (pct >= 50) fillClass = 'fill-med';

        const pasajerosHtml = (u.pasajeros || []).map(p => 
            `<span class="passenger-chip">👤 ${p.nombre} <span>(${p.origen}➔${p.destino})</span></span>`
        ).join('');

        return `
            <div class="unit-card" id="card-${u.id}">
                <div class="unit-card-header">
                    <div class="unit-title-group">
                        <span class="unit-id-badge">${u.id.toUpperCase()}</span>
                        <span class="unit-name">${u.nombre}</span>
                    </div>
                    <span class="unit-status-badge status-${u.estado}">${u.estado.replace('_', ' ')}</span>
                </div>

                <div class="unit-meta-row">
                    <span>Parada actual: <strong class="text-cyan">${formatearNombreParada(u.parada_actual)}</strong></span>
                    <span>Recorrido: <strong>${u.kms_totales} km</strong> (${u.viajes_completados} vueltas)</span>
                </div>

                <div class="unit-capacity-gauge">
                    <div class="gauge-label">
                        <span>Aforo de Pasajeros:</span>
                        <span><strong>${pasajerosCount}</strong> de ${capMax} (${pct}%)</span>
                    </div>
                    <div class="gauge-track">
                        <div class="gauge-fill ${fillClass}" style="width: ${pct}%"></div>
                    </div>
                </div>

                <div class="unit-passengers-list">
                    ${pasajerosHtml || '<span style="font-style:italic;color:var(--text-muted);">Sin pasajeros a bordo (disponible para despacho)</span>'}
                </div>

                <div class="unit-actions-row">
                    <button class="btn btn-secondary" style="flex: 1;" onclick="avanzarUnidad('${u.id}')">
                        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>
                        Avanzar Parada
                    </button>
                    <button class="btn btn-danger" onclick="provocarCrash('${u.id}')" title="Inyecta kill a este proceso BEAM para demostrar la recuperación por el Supervisor OTP">
                        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
                        Crash (Let it crash)
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function renderizarBitacora(bitacora) {
    const term = document.getElementById('terminal-log');
    if (!bitacora || !term) return;

    bitacora.forEach(evento => {
        const hash = `${evento.timestamp}-${evento.mensaje}`;
        if (!logLineasVistas.has(hash)) {
            logLineasVistas.add(hash);
            const d = new Date(evento.timestamp * 1000);
            const hora = d.toTimeString().split(' ')[0];
            const div = document.createElement('div');
            div.className = `terminal-line line-${evento.tipo}`;
            div.textContent = `[${hora}] [${evento.tipo.toUpperCase()}] ${evento.mensaje}`;
            term.appendChild(div);
            term.scrollTop = term.scrollHeight;
        }
    });
}

// =====================================================================
// Acciones e Interacción con la API REST de Erlang
// =====================================================================

async function manejarSolicitudPasajero(e) {
    e.preventDefault();
    const nombre = document.getElementById('input-nombre').value.trim();
    const origen = document.getElementById('select-origen').value;
    const destino = document.getElementById('select-destino').value;

    if (!nombre) {
        mostrarToast('Ingresa el nombre del pasajero.', 'error');
        return;
    }
    if (origen === destino) {
        mostrarToast('El origen y el destino deben ser diferentes.', 'error');
        return;
    }

    const btn = document.getElementById('btn-submit-solicitar');
    btn.disabled = true;
    btn.textContent = 'Procesando en BEAM...';

    try {
        const res = await fetch(`${API_BASE}/api/solicitar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ nombre, origen, destino })
        });
        const data = await res.json();

        const box = document.getElementById('dispatch-result');
        box.style.display = 'block';

        if (res.ok && data.exito) {
            box.className = 'dispatch-result-box text-emerald';
            box.innerHTML = `
                <strong>✅ Pasajero Asignado Exitosamente:</strong><br>
                • <strong>ID Ticket:</strong> #${data.pasajero_id}<br>
                • <strong>Unidad:</strong> ${data.unidad_asignada.toUpperCase()}<br>
                • <strong>Tramo:</strong> ${data.origen} ➔ ${data.destino} (${data.distancia_km} km)<br>
                • <strong>Tiempo estimado:</strong> ${data.tiempo_estimado_min} minutos
            `;
            mostrarToast(`Pasajero asignado a ${data.unidad_asignada}`, 'success');
            document.getElementById('input-nombre').value = '';
        } else {
            box.className = 'dispatch-result-box text-rose';
            box.innerHTML = `<strong>⚠️ Despacho Rechazado:</strong> ${data.error || 'Sin cupo o sin ruta disponible'}`;
            mostrarToast(`No se pudo asignar: ${data.error || 'Sin cupo'}`, 'error');
        }
        await refrescarEstado();
    } catch (err) {
        mostrarToast(`Error de comunicación: ${err.message}`, 'error');
    } finally {
        btn.disabled = false;
        btn.textContent = 'Asignar Unidad Óptima (Despacho OTP)';
    }
}

async function avanzarUnidad(unidadId) {
    try {
        const res = await fetch(`${API_BASE}/api/avanzar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ unidad_id: unidadId })
        });
        const data = await res.json();
        if (data.exito) {
            if (unidadId === 'todas') {
                mostrarToast('Toda la flota ha avanzado a su siguiente parada', 'info');
            } else {
                mostrarToast(`${unidadId.toUpperCase()} avanzó a ${formatearNombreParada(data.unidad.parada_actual)}`, 'info');
            }
            await refrescarEstado();
        }
    } catch (err) {
        mostrarToast(`Error al avanzar: ${err.message}`, 'error');
    }
}

async function provocarCrash(unidadId) {
    try {
        mostrarToast(`💥 Inyectando KILL a ${unidadId.toUpperCase()}...`, 'error');
        const res = await fetch(`${API_BASE}/api/crash`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ unidad_id: unidadId })
        });
        const data = await res.json();
        if (data.exito) {
            setTimeout(() => {
                mostrarToast(`🛡️ ¡Supervisor OTP reinició ${unidadId.toUpperCase()} automáticamente!`, 'success');
                refrescarEstado();
            }, 300);
        }
    } catch (err) {
        mostrarToast(`Error al inyectar crash: ${err.message}`, 'error');
    }
}

function generarPasajeroAleatorio() {
    const nombre = NOMBRES_ALEATORIOS[Math.floor(Math.random() * NOMBRES_ALEATORIOS.length)];
    const iOrig = Math.floor(Math.random() * (PARADAS_CLAVE.length - 1));
    const iDest = Math.floor(Math.random() * (PARADAS_CLAVE.length - iOrig - 1)) + iOrig + 1;
    const origen = PARADAS_CLAVE[iOrig];
    const destino = PARADAS_CLAVE[iDest];

    document.getElementById('input-nombre').value = nombre;
    document.getElementById('select-origen').value = origen;
    document.getElementById('select-destino').value = destino;

    document.getElementById('form-solicitar').dispatchEvent(new Event('submit'));
}

function alternarAutoSimulacion() {
    const btn = document.getElementById('btn-auto-simular');
    const label = document.getElementById('label-auto-simular');

    if (autoSimularInterval) {
        clearInterval(autoSimularInterval);
        autoSimularInterval = null;
        label.textContent = 'Iniciar Auto-Simulación (3s)';
        btn.classList.remove('btn-primary');
        btn.classList.add('btn-secondary');
        mostrarToast('Auto-simulación pausada', 'info');
    } else {
        autoSimularInterval = setInterval(() => {
            // Alternar entre avanzar flota y generar un pasajero
            if (Math.random() > 0.4) {
                avanzarUnidad('todas');
            } else {
                generarPasajeroAleatorio();
            }
        }, 3000);
        label.textContent = 'Pausar Auto-Simulación';
        btn.classList.remove('btn-secondary');
        btn.classList.add('btn-primary');
        mostrarToast('Auto-simulación activa (cada 3s)', 'success');
    }
}

// =====================================================================
// Utilidades de Interfaz
// =====================================================================

function formatearNombreParada(id) {
    if (!id) return '--';
    const mapeo = {
        otay: "Otay (TecNM)",
        central_camionera: "Central Alamar",
        zona_rio: "Zona Río (CECUT)",
        centro: "Centro Revolución",
        el_florido: "El Florido Industrial",
        playas: "Playas de Tijuana"
    };
    return mapeo[id] || id;
}

function actualizarReloj() {
    const now = new Date();
    document.getElementById('clock-display').textContent = now.toLocaleTimeString('es-MX');
}

function mostrarToast(mensaje, tipo = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${tipo}`;
    toast.textContent = mensaje;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(10px)';
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}
