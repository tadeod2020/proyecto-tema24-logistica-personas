%% =====================================================================
%% Programa:    logistica_tests.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (EUnit Automatizado, Casos de Frontera, Let-It-Crash)
%% =====================================================================

-module(logistica_tests).
-include_lib("eunit/include/eunit.hrl").
-include("logistica.hrl").

%% =====================================================================
%% 1. Pruebas del Motor Funcional Puro (Geometría y Haversine)
%% =====================================================================

haversine_cero_test() ->
    Distancia = logistica_core:distancia_haversine(32.5323, -116.9634, 32.5323, -116.9634),
    ?assertEqual(0.0, Distancia).

haversine_otay_centro_test() ->
    Dist = logistica_core:distancia_entre_paradas(otay, centro),
    %% La distancia entre Otay y Centro de Tijuana es de aproximadamente 7.0 a 7.5 km
    ?assert(Dist > 6.5 andalso Dist < 8.0).

distancia_ruta_tail_recursion_test() ->
    Ruta = [otay, central_camionera, zona_rio, centro],
    DistTotal = logistica_core:distancia_ruta(Ruta),
    ?assert(DistTotal > 9.0 andalso DistTotal < 15.0).

distancia_ruta_vacia_test() ->
    ?assertEqual(0.0, logistica_core:distancia_ruta([])),
    ?assertEqual(0.0, logistica_core:distancia_ruta([otay])).

tiempo_estimado_test() ->
    %% 35 km a 35 km/h = 60 min + (3 paradas * 2 min) = 66 min
    Minutos = logistica_core:tiempo_estimado_minutos(35.0, 3),
    ?assertEqual(66.0, Minutos).

%% =====================================================================
%% 2. Pruebas de Asignación, Sobrecupo y Guards
%% =====================================================================

asignar_pasajero_valido_test() ->
    Unidad = #unidad{
        id = test_van,
        nombre = "Van Test",
        ruta_id = test_ruta,
        paradas = [otay, zona_rio, centro],
        capacidad_max = 2,
        pasajeros = []
    },
    Pasajero1 = #pasajero{id = 1, nombre = "Axel Daniels", origen = otay, destino = centro, timestamp = 123},
    {ok, UnidadCon1} = logistica_core:asignar_pasajero(Unidad, Pasajero1),
    ?assertEqual(1, length(UnidadCon1#unidad.pasajeros)),
    ?assertEqual(en_ruta, UnidadCon1#unidad.estado).

asignar_pasajero_sobrecupo_guard_test() ->
    UnidadLlena = #unidad{
        id = test_van,
        nombre = "Van Llena",
        ruta_id = test_ruta,
        paradas = [otay, zona_rio, centro],
        capacidad_max = 1,
        pasajeros = [#pasajero{id = 1, nombre = "Pasajero 1", origen = otay, destino = centro, timestamp = 100}]
    },
    Pasajero2 = #pasajero{id = 2, nombre = "Pasajero 2", origen = otay, destino = centro, timestamp = 101},
    Resultado = logistica_core:asignar_pasajero(UnidadLlena, Pasajero2),
    ?assertEqual({error, sin_cupo}, Resultado).

asignar_pasajero_ruta_invalida_test() ->
    Unidad = #unidad{
        id = test_van,
        nombre = "Van Test",
        ruta_id = test_ruta,
        paradas = [otay, zona_rio, centro],
        capacidad_max = 10,
        pasajeros = []
    },
    %% Destino antes que origen en la ruta unidireccional
    PasajeroSentidoContrario = #pasajero{id = 1, nombre = "Pedro", origen = centro, destino = otay, timestamp = 100},
    ?assertEqual({error, parada_no_servida}, logistica_core:asignar_pasajero(Unidad, PasajeroSentidoContrario)),

    %% Parada fuera de la ruta
    PasajeroFuera = #pasajero{id = 2, nombre = "Juan", origen = el_florido, destino = centro, timestamp = 100},
    ?assertEqual({error, parada_no_servida}, logistica_core:asignar_pasajero(Unidad, PasajeroFuera)).

%% =====================================================================
%% 3. Pruebas de Desembarque y Avance de Itinerario
%% =====================================================================

desembarcar_pasajeros_test() ->
    P1 = #pasajero{id = 1, nombre = "Baja en Centro", origen = otay, destino = centro, timestamp = 1},
    P2 = #pasajero{id = 2, nombre = "Baja en Zona Rio", origen = otay, destino = zona_rio, timestamp = 2},
    Unidad = #unidad{
        id = test_van,
        nombre = "Van",
        ruta_id = test,
        paradas = [otay, zona_rio, centro],
        pasajeros = [P1, P2]
    },
    {UnidadTrasParada, Desembarcados} = logistica_core:desembarcar_en_parada(Unidad, zona_rio),
    ?assertEqual(1, length(Desembarcados)),
    ?assertEqual(1, length(UnidadTrasParada#unidad.pasajeros)),
    [PasajeroQueda] = UnidadTrasParada#unidad.pasajeros,
    ?assertEqual(centro, PasajeroQueda#pasajero.destino).

avanzar_parada_ciclo_completo_test() ->
    Unidad = #unidad{
        id = test_van,
        nombre = "Van",
        ruta_id = test,
        paradas = [otay, centro],
        parada_actual_idx = 1,
        kms_totales = 0.0,
        viajes_completados = 0
    },
    %% Avanzar a la parada 2 (centro)
    {UnidadEnCentro, _} = logistica_core:avanzar_parada(Unidad),
    ?assertEqual(2, UnidadEnCentro#unidad.parada_actual_idx),
    ?assert(UnidadEnCentro#unidad.kms_totales > 0.0),
    ?assertEqual(0, UnidadEnCentro#unidad.viajes_completados),

    %% Avanzar de nuevo (regresa a otay, completando ciclo)
    {UnidadEnOtay, _} = logistica_core:avanzar_parada(UnidadEnCentro),
    ?assertEqual(1, UnidadEnOtay#unidad.parada_actual_idx),
    ?assertEqual(1, UnidadEnOtay#unidad.viajes_completados).

%% =====================================================================
%% 4. Pruebas de Despacho y Funciones de Orden Superior
%% =====================================================================

buscar_mejor_unidad_test() ->
    U1 = #unidad{
        id = u1,
        nombre = "Unidad 1",
        ruta_id = r1,
        paradas = [otay, centro],
        capacidad_max = 10,
        pasajeros = [#pasajero{id = 10, nombre = "A", origen = otay, destino = centro, timestamp = 1}]
    },
    U2 = #unidad{
        id = u2,
        nombre = "Unidad 2",
        ruta_id = r1,
        paradas = [otay, centro],
        capacidad_max = 10,
        pasajeros = [] %% Vacia: mejor balance de carga
    },
    {ok, Mejor} = logistica_core:buscar_mejor_unidad([U1, U2], otay, centro),
    ?assertEqual(u2, Mejor#unidad.id).

%% =====================================================================
%% 5. Pruebas de Concurrencia OTP y Resiliencia ("Let it crash")
%% =====================================================================

otp_unidad_gen_server_ciclo_vida_test() ->
    Id = test_unidad_otp,
    Ruta = [otay, zona_rio, centro],
    {ok, Pid} = logistica_unidad:start_link(Id, "Unidad Prueba OTP", ruta_test, Ruta, 5),
    ?assert(is_pid(Pid)),

    %% Consultar estado
    {ok, Estado} = logistica_unidad:obtener_estado(Id),
    ?assertEqual(1, Estado#unidad.parada_actual_idx),

    %% Abordar
    Pasajero = #pasajero{id = 99, nombre = "Axel", origen = otay, destino = centro, timestamp = 10},
    {ok, EstadoTrasAbordar} = logistica_unidad:abordar(Id, Pasajero),
    ?assertEqual(1, length(EstadoTrasAbordar#unidad.pasajeros)),

    %% Avanzar parada
    {ok, EstadoAvanzado, _Desembarcados} = logistica_unidad:avanzar(Id),
    ?assertEqual(2, EstadoAvanzado#unidad.parada_actual_idx),

    logistica_unidad:stop(Id).

otp_supervisor_resiliencia_test() ->
    %% Detener instancias previas si existieran
    try supervisor:terminate_child(logistica_sup, unidad_1) catch _:_ -> ok end,
    try application:stop(logistica) catch _:_ -> ok end,

    %% Iniciar aplicación o supervisor
    {ok, SupPid} = logistica_sup:start_link(),
    ?assert(is_pid(SupPid)),

    %% Obtener el PID de la unidad 1 antes del fallo
    PidOriginal = whereis(unidad_1),
    ?assert(is_pid(PidOriginal)),

    %% Matar abruptamente el proceso simulando fallo de hardware/red ("let it crash")
    exit(PidOriginal, kill),

    %% Dar una ventana de 150 ms para que el supervisor actúe
    timer:sleep(150),

    %% El supervisor debe haber reiniciado la unidad automáticamente
    PidNuevo = whereis(unidad_1),
    ?assert(is_pid(PidNuevo)),
    ?assertNotEqual(PidOriginal, PidNuevo),

    %% El resto de las unidades y el gestor deben continuar vivos sin reinicio
    ?assert(is_pid(whereis(unidad_2))),
    ?assert(is_pid(whereis(logistica_gestor))),

    %% Limpieza ordenada: desenlazar el supervisor del proceso de prueba antes de detenerlo
    unlink(SupPid),
    exit(SupPid, kill),
    timer:sleep(50).
