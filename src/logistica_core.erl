%% =====================================================================
%% Programa:    logistica_core.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Functional Core, Tail Recursion, Guards, Specs)
%% =====================================================================

-module(logistica_core).

-include("logistica.hrl").

-export([
    paradas_catalogo/0,
    obtener_parada/1,
    distancia_haversine/4,
    distancia_entre_paradas/2,
    distancia_ruta/1,
    tiempo_estimado_minutos/2,
    asignar_pasajero/2,
    desembarcar_en_parada/2,
    avanzar_parada/1,
    buscar_mejor_unidad/3,
    es_ruta_valida/3,
    formatear_unidad_map/1,
    formatear_pasajero_map/1
]).

%% Radio aproximado de la Tierra en kilómetros (WGS84 esférico)
-define(RADIO_TIERRA_KM, 6371.0).
-define(VELOCIDAD_PROMEDIO_KMH, 35.0).
-define(MINUTOS_POR_PARADA, 2.0).

%% =====================================================================
%% 1. Catálogo Inmutable de Paradas de Tijuana
%% =====================================================================

-spec paradas_catalogo() -> [#parada{}].
paradas_catalogo() ->
    [
        #parada{id = otay,               nombre = "Otay - TecNM Campus Tijuana", lat = 32.5323, lon = -116.9634},
        #parada{id = central_camionera,  nombre = "Terminal Central Alamar",     lat = 32.5085, lon = -116.9622},
        #parada{id = zona_rio,           nombre = "Zona Río - Centro Cultural",  lat = 32.5284, lon = -117.0228},
        #parada{id = centro,             nombre = "Centro Histórico / Revolución",lat = 32.5332, lon = -117.0382},
        #parada{id = el_florido,         nombre = "Parque Industrial El Florido", lat = 32.4491, lon = -116.8225},
        #parada{id = playas,             nombre = "Playas de Tijuana - Malecón", lat = 32.5262, lon = -117.1219}
    ].

-spec obtener_parada(atom()) -> {ok, #parada{}} | {error, parada_no_encontrada}.
obtener_parada(ParadaId) ->
    case lists:keyfind(ParadaId, #parada.id, paradas_catalogo()) of
        #parada{} = P -> {ok, P};
        false         -> {error, parada_no_encontrada}
    end.

%% =====================================================================
%% 2. Motor Geométrico Puro (Fórmula de Haversine)
%% =====================================================================

-spec grados_a_radianes(float()) -> float().
grados_a_radianes(Grados) ->
    Grados * math:pi() / 180.0.

-spec distancia_haversine(float(), float(), float(), float()) -> float().
distancia_haversine(Lat1, Lon1, Lat2, Lon2) ->
    DLat = grados_a_radianes(Lat2 - Lat1),
    DLon = grados_a_radianes(Lon2 - Lon1),
    RadLat1 = grados_a_radianes(Lat1),
    RadLat2 = grados_a_radianes(Lat2),

    A = math:sin(DLat / 2.0) * math:sin(DLat / 2.0) +
        math:cos(RadLat1) * math:cos(RadLat2) *
        math:sin(DLon / 2.0) * math:sin(DLon / 2.0),
    C = 2.0 * math:atan2(math:sqrt(A), math:sqrt(1.0 - A)),
    ?RADIO_TIERRA_KM * C.

-spec distancia_entre_paradas(atom(), atom()) -> float().
distancia_entre_paradas(P1, P2) when P1 =:= P2 -> 0.0;
distancia_entre_paradas(P1, P2) ->
    case {obtener_parada(P1), obtener_parada(P2)} of
        {{ok, #parada{lat = Lat1, lon = Lon1}}, {ok, #parada{lat = Lat2, lon = Lon2}}} ->
            distancia_haversine(Lat1, Lon1, Lat2, Lon2);
        _ ->
            0.0
    end.

%% =====================================================================
%% 3. Recursión de Cola con Acumulador (Tail Recursion)
%% =====================================================================

%% Calcula la longitud total de una ruta sumando tramos continuos.
%% Demuestra eficiencia O(N) en tiempo y espacio de stack O(1).
-spec distancia_ruta([atom()]) -> float().
distancia_ruta(Paradas) ->
    distancia_ruta_tail(Paradas, 0.0).

distancia_ruta_tail([], Acc) ->
    Acc;
distancia_ruta_tail([_ParadaFinal], Acc) ->
    Acc;
distancia_ruta_tail([P1, P2 | Resto], Acc) ->
    Tramo = distancia_entre_paradas(P1, P2),
    distancia_ruta_tail([P2 | Resto], Acc + Tramo).

%% Estima tiempo de recorrido en minutos: tiempo de traslado + penalización de parada
-spec tiempo_estimado_minutos(float(), non_neg_integer()) -> float().
tiempo_estimado_minutos(DistanciaKm, NumParadas) ->
    Horas = DistanciaKm / ?VELOCIDAD_PROMEDIO_KMH,
    MinutosTraslado = Horas * 60.0,
    MinutosTraslado + (NumParadas * ?MINUTOS_POR_PARADA).

%% =====================================================================
%% 4. Gestión de Pasajeros con Pattern Matching y Guards
%% =====================================================================

-spec asignar_pasajero(#unidad{}, #pasajero{}) ->
    {ok, #unidad{}} | {error, sin_cupo | parada_no_servida}.
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

%% Desembarca pasajeros que llegaron a su destino.
%% Utiliza recursión de cola con acumuladores separados:
%% Quienes descienden vs Quienes continúan a bordo.
-spec desembarcar_en_parada(#unidad{}, atom()) -> {#unidad{}, [#pasajero{}]}.
desembarcar_en_parada(#unidad{pasajeros = Pasajeros} = Unidad, ParadaActual) ->
    {Quedan, Desembarcados} = separar_pasajeros_tail(Pasajeros, ParadaActual, [], []),
    UnidadActualizada = Unidad#unidad{pasajeros = Quedan},
    {UnidadActualizada, Desembarcados}.

separar_pasajeros_tail([], _Parada, AccQuedan, AccDescienden) ->
    {lists:reverse(AccQuedan), lists:reverse(AccDescienden)};
separar_pasajeros_tail([#pasajero{destino = Dest} = P | Resto], Parada, AccQuedan, AccDescienden)
  when Dest =:= Parada ->
    separar_pasajeros_tail(Resto, Parada, AccQuedan, [P | AccDescienden]);
separar_pasajeros_tail([P | Resto], Parada, AccQuedan, AccDescienden) ->
    separar_pasajeros_tail(Resto, Parada, [P | AccQuedan], AccDescienden).

%% Avanza la unidad a la siguiente parada del itinerario
-spec avanzar_parada(#unidad{}) -> {#unidad{}, [#pasajero{}]}.
avanzar_parada(#unidad{paradas = Paradas,
                       parada_actual_idx = Idx,
                       kms_totales = Kms,
                       viajes_completados = Viajes} = Unidad) ->
    TotalParadas = length(Paradas),
    ParadaActual = lists:nth(Idx, Paradas),
    SiguienteIdx = (Idx rem TotalParadas) + 1,
    SiguienteParada = lists:nth(SiguienteIdx, Paradas),

    DistanciaTramo = distancia_entre_paradas(ParadaActual, SiguienteParada),
    NuevosViajes = case SiguienteIdx of
        1 -> Viajes + 1;
        _ -> Viajes
    end,

    UnidadMovida = Unidad#unidad{
        parada_actual_idx = SiguienteIdx,
        kms_totales = Kms + DistanciaTramo,
        viajes_completados = NuevosViajes,
        estado = en_parada
    },
    desembarcar_en_parada(UnidadMovida, SiguienteParada).

%% =====================================================================
%% 5. Búsqueda y Despacho Funcional de Unidades
%% =====================================================================

%% Verifica si una unidad sirve el trayecto Origen -> Destino en el orden correcto
-spec es_ruta_valida([atom()], atom(), atom()) -> boolean().
es_ruta_valida(Paradas, Origen, Destino) ->
    case {indice_de(Origen, Paradas), indice_de(Destino, Paradas)} of
        {{ok, IdxOrig}, {ok, IdxDest}} when IdxOrig < IdxDest ->
            true;
        _ ->
            false
    end.

-spec indice_de(atom(), [atom()]) -> {ok, pos_integer()} | error.
indice_de(Elem, Lista) ->
    indice_de_tail(Elem, Lista, 1).

indice_de_tail(_Elem, [], _Idx) -> error;
indice_de_tail(Elem, [Elem | _], Idx) -> {ok, Idx};
indice_de_tail(Elem, [_ | Resto], Idx) -> indice_de_tail(Elem, Resto, Idx + 1).

%% Selecciona la unidad óptima para el usuario usando listas y foldl funcional
-spec buscar_mejor_unidad([#unidad{}], atom(), atom()) ->
    {ok, #unidad{}} | {error, no_hay_unidades_disponibles}.
buscar_mejor_unidad(Unidades, Origen, Destino) ->
    Candidatas = lists:filter(
        fun(#unidad{capacidad_max = Cap, pasajeros = Pas, paradas = Par}) ->
            (length(Pas) < Cap) andalso es_ruta_valida(Par, Origen, Destino)
        end,
        Unidades
    ),
    case Candidatas of
        [] ->
            {error, no_hay_unidades_disponibles};
        [Primera | Resto] ->
            %% Minimiza por ocupación relativa para balancear carga de pasajeros
            Mejor = lists:foldl(
                fun(#unidad{pasajeros = P1, capacidad_max = C1} = U1,
                    #unidad{pasajeros = P2, capacidad_max = C2} = MejorActual) ->
                    Ratio1 = length(P1) / C1,
                    Ratio2 = length(P2) / C2,
                    if Ratio1 < Ratio2 -> U1;
                       true            -> MejorActual
                    end
                end,
                Primera,
                Resto
            ),
            {ok, Mejor}
    end.

%% =====================================================================
%% 6. Formateo y Serialización Inmutable para API JSON
%% =====================================================================

-spec formatear_pasajero_map(#pasajero{}) -> map().
formatear_pasajero_map(#pasajero{id = Id, nombre = Nombre, origen = Orig, destino = Dest, timestamp = Ts}) ->
    #{
        id => Id,
        nombre => list_to_binary(Nombre),
        origen => Orig,
        destino => Dest,
        timestamp => Ts
    }.

-spec formatear_unidad_map(#unidad{}) -> map().
formatear_unidad_map(#unidad{
    id = Id,
    nombre = Nombre,
    ruta_id = RutaId,
    paradas = Paradas,
    parada_actual_idx = Idx,
    capacidad_max = CapMax,
    pasajeros = Pasajeros,
    estado = Estado,
    kms_totales = Kms,
    viajes_completados = Viajes,
    fallas_recuperadas = Fallas
}) ->
    ParadaActual = case (Idx >= 1 andalso Idx =< length(Paradas)) of
        true  -> lists:nth(Idx, Paradas);
        false -> desconocido
    end,
    PasajerosMaps = [formatear_pasajero_map(P) || P <- Pasajeros],
    #{
        id => Id,
        nombre => list_to_binary(Nombre),
        ruta_id => RutaId,
        parada_actual => ParadaActual,
        parada_actual_idx => Idx,
        paradas => Paradas,
        capacidad_max => CapMax,
        pasajeros_actuales => length(Pasajeros),
        pasajeros => PasajerosMaps,
        estado => Estado,
        kms_totales => round_dos_decimales(Kms),
        viajes_completados => Viajes,
        fallas_recuperadas => Fallas
    }.

-spec round_dos_decimales(float()) -> float().
round_dos_decimales(Val) ->
    trunc(Val * 100.0) / 100.0.
