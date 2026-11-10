%% =====================================================================
%% Programa:    logistica_gestor.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Coordinador OTP, Despacho Concurrente, Métricas)
%% =====================================================================

-module(logistica_gestor).
-behaviour(gen_server).

-include("logistica.hrl").

%% API Cliente
-export([
    start_link/0,
    solicitar_viaje/3,
    listar_unidades/0,
    avanzar_unidad/1,
    avanzar_todas/0,
    provocar_crash/1,
    obtener_metricas/0,
    registrar_unidad/1
]).

%% Callbacks de gen_server
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-record(state, {
    unidades = [unidad_1, unidad_2, unidad_3, unidad_4] :: [atom()],
    contador_pasajeros = 1000 :: non_neg_integer(),
    total_transportados = 0 :: non_neg_integer(),
    hora_inicio :: integer(),
    bitacora = [] :: [{integer(), atom(), binary()}]
}).

%% =====================================================================
%% API Cliente
%% =====================================================================

-spec start_link() -> {ok, pid()} | {error, any()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec solicitar_viaje(string(), atom(), atom()) ->
    {ok, map()} | {error, any()}.
solicitar_viaje(Nombre, Origen, Destino) ->
    gen_server:call(?MODULE, {solicitar_viaje, Nombre, Origen, Destino}).

-spec listar_unidades() -> [map()].
listar_unidades() ->
    gen_server:call(?MODULE, listar_unidades).

-spec avanzar_unidad(atom()) -> {ok, map(), [map()]} | {error, any()}.
avanzar_unidad(UnidadId) ->
    gen_server:call(?MODULE, {avanzar_unidad, UnidadId}).

-spec avanzar_todas() -> [{atom(), ok | {error, any()}}].
avanzar_todas() ->
    gen_server:call(?MODULE, avanzar_todas).

-spec provocar_crash(atom()) -> {ok, binary()} | {error, any()}.
provocar_crash(UnidadId) ->
    gen_server:call(?MODULE, {provocar_crash, UnidadId}).

-spec obtener_metricas() -> map().
obtener_metricas() ->
    gen_server:call(?MODULE, obtener_metricas).

-spec registrar_unidad(atom()) -> ok.
registrar_unidad(UnidadId) ->
    gen_server:cast(?MODULE, {registrar_unidad, UnidadId}).

%% =====================================================================
%% Callbacks de gen_server
%% =====================================================================

init([]) ->
    Now = erlang:system_time(second),
    EstadoInicial = #state{
        unidades = [unidad_1, unidad_2, unidad_3, unidad_4],
        contador_pasajeros = 1000,
        total_transportados = 0,
        hora_inicio = Now,
        bitacora = [{Now, sistema, <<"Gestor logístico de personas iniciado exitosamente">>}]
    },
    {ok, EstadoInicial}.

handle_call({solicitar_viaje, Nombre, Origen, Destino}, _From, #state{
    unidades = UnidadesIds,
    contador_pasajeros = NumPasajero,
    bitacora = Bitacora
} = State) ->
    Now = erlang:system_time(second),
    %% Recolectar estados inmutables de todas las unidades activas
    EstadosUnidades = recolectar_estados_unidades(UnidadesIds),
    case logistica_core:buscar_mejor_unidad(EstadosUnidades, Origen, Destino) of
        {ok, #unidad{id = UnidadAsignadaId}} ->
            NuevoId = NumPasajero + 1,
            Pasajero = #pasajero{
                id = NuevoId,
                nombre = Nombre,
                origen = Origen,
                destino = Destino,
                timestamp = Now
            },
            case logistica_unidad:abordar(UnidadAsignadaId, Pasajero) of
                {ok, _UnidadActualizada} ->
                    DistanciaKm = logistica_core:distancia_entre_paradas(Origen, Destino),
                    TiempoMin = logistica_core:tiempo_estimado_minutos(DistanciaKm, 1),
                    MensajeBitacora = iolist_to_binary(io_lib:format(
                        "Pasajero ~s asignado a ~p (~p -> ~p, est. ~.1f min)",
                        [Nombre, UnidadAsignadaId, Origen, Destino, TiempoMin]
                    )),
                    NuevaBitacora = [{Now, abordaje, MensajeBitacora} | lists:sublist(Bitacora, 40)],
                    Respuesta = #{
                        exito => true,
                        pasajero_id => NuevoId,
                        unidad_asignada => UnidadAsignadaId,
                        origen => Origen,
                        destino => Destino,
                        distancia_km => trunc(DistanciaKm * 100.0) / 100.0,
                        tiempo_estimado_min => trunc(TiempoMin * 10.0) / 10.0,
                        mensaje => MensajeBitacora
                    },
                    {reply, {ok, Respuesta}, State#state{
                        contador_pasajeros = NuevoId,
                        bitacora = NuevaBitacora
                    }};
                {error, Reason} ->
                    MensajeError = iolist_to_binary(io_lib:format(
                        "Fallo al abordar en ~p: ~p", [UnidadAsignadaId, Reason]
                    )),
                    {reply, {error, Reason}, State#state{
                        bitacora = [{Now, error, MensajeError} | Bitacora]
                    }}
            end;
        {error, Motivo} ->
            MensajeRechazo = iolist_to_binary(io_lib:format(
                "Solicitud de ~s rechazada (~p -> ~p): ~p",
                [Nombre, Origen, Destino, Motivo]
            )),
            {reply, {error, Motivo}, State#state{
                bitacora = [{Now, rechazo, MensajeRechazo} | Bitacora]
            }}
    end;

handle_call(listar_unidades, _From, #state{unidades = UnidadesIds} = State) ->
    Estados = recolectar_estados_unidades(UnidadesIds),
    Mapas = [logistica_core:formatear_unidad_map(U) || U <- Estados],
    {reply, Mapas, State};

handle_call({avanzar_unidad, UnidadId}, _From, #state{
    total_transportados = TotalTransportados,
    bitacora = Bitacora
} = State) ->
    Now = erlang:system_time(second),
    case whereis(UnidadId) of
        Pid when is_pid(Pid) ->
            case logistica_unidad:avanzar(UnidadId) of
                {ok, UnidadActualizada, Desembarcados} ->
                    CantDesembarcados = length(Desembarcados),
                    NuevoTotal = TotalTransportados + CantDesembarcados,
                    ParadaNueva = lists:nth(UnidadActualizada#unidad.parada_actual_idx, UnidadActualizada#unidad.paradas),
                    Msg = iolist_to_binary(io_lib:format(
                        "~p arribó a ~p. Desembarcaron ~p pasajeros.",
                        [UnidadId, ParadaNueva, CantDesembarcados]
                    )),
                    NuevaBitacora = [{Now, movimiento, Msg} | lists:sublist(Bitacora, 40)],
                    MapaUnidad = logistica_core:formatear_unidad_map(UnidadActualizada),
                    MapasDesembarcados = [logistica_core:formatear_pasajero_map(P) || P <- Desembarcados],
                    {reply, {ok, MapaUnidad, MapasDesembarcados}, State#state{
                        total_transportados = NuevoTotal,
                        bitacora = NuevaBitacora
                    }};
                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;
        undefined ->
            {reply, {error, unidad_no_encontrada}, State}
    end;

handle_call(avanzar_todas, _From, #state{unidades = UnidadesIds} = State) ->
    Resultados = lists:map(
        fun(Id) ->
            case whereis(Id) of
                Pid when is_pid(Pid) ->
                    {Id, logistica_unidad:avanzar(Id)};
                undefined ->
                    {Id, {error, proceso_caido}}
            end
        end,
        UnidadesIds
    ),
    {reply, Resultados, State};

handle_call({provocar_crash, UnidadId}, _From, #state{bitacora = Bitacora} = State) ->
    Now = erlang:system_time(second),
    case whereis(UnidadId) of
        Pid when is_pid(Pid) ->
            Msg = iolist_to_binary(io_lib:format(
                "Inyectando kill a ~p (PID ~p). El supervisor one_for_one actuará.",
                [UnidadId, Pid]
            )),
            exit(Pid, kill),
            NuevaBitacora = [{Now, alerta, Msg} | lists:sublist(Bitacora, 40)],
            {reply, {ok, Msg}, State#state{bitacora = NuevaBitacora}};
        undefined ->
            {reply, {error, unidad_no_activa}, State}
    end;

handle_call(obtener_metricas, _From, #state{
    unidades = UnidadesIds,
    total_transportados = TotalTransportados,
    hora_inicio = HoraInicio,
    bitacora = Bitacora
} = State) ->
    Estados = recolectar_estados_unidades(UnidadesIds),
    KmsTotales = lists:foldl(fun(#unidad{kms_totales = K}, Acc) -> Acc + K end, 0.0, Estados),
    ViajesTotales = lists:foldl(fun(#unidad{viajes_completados = V}, Acc) -> Acc + V end, 0, Estados),
    PasajerosActualmenteABordo = lists:foldl(
        fun(#unidad{pasajeros = P}, Acc) -> Acc + length(P) end, 0, Estados
    ),
    CapacidadTotal = lists:foldl(
        fun(#unidad{capacidad_max = C}, Acc) -> Acc + C end, 0, Estados
    ),
    Now = erlang:system_time(second),
    UptimeSegundos = Now - HoraInicio,

    %% Telemetría viva de la BEAM VM
    Memory = erlang:memory(total) div 1024,
    ProcessCount = erlang:system_info(process_count),
    Schedulers = erlang:system_info(schedulers_online),

    BitacoraFormat = [
        #{
            timestamp => Ts,
            tipo => Tipo,
            mensaje => Txt
        } || {Ts, Tipo, Txt} <- Bitacora
    ],

    Metricas = #{
        unidades_activas => length(Estados),
        unidades_totales => length(UnidadesIds),
        total_transportados => TotalTransportados,
        pasajeros_a_bordo => PasajerosActualmenteABordo,
        capacidad_total => CapacidadTotal,
        porcentaje_ocupacion => case CapacidadTotal of
            0 -> 0.0;
            _ -> trunc((PasajerosActualmenteABordo / CapacidadTotal) * 1000.0) / 10.0
        end,
        kms_flota_acumulados => trunc(KmsTotales * 100.0) / 100.0,
        viajes_completados => ViajesTotales,
        uptime_segundos => UptimeSegundos,
        beam_memoria_kb => Memory,
        beam_procesos => ProcessCount,
        beam_schedulers => Schedulers,
        bitacora => BitacoraFormat
    },
    {reply, Metricas, State};

handle_call(_Request, _From, State) ->
    {reply, {error, no_implementado}, State}.

handle_cast({registrar_unidad, UnidadId}, #state{unidades = Unidades} = State) ->
    case lists:member(UnidadId, Unidades) of
        true  -> {noreply, State};
        false -> {noreply, State#state{unidades = [UnidadId | Unidades]}}
    end;

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% =====================================================================
%% Funciones Auxiliares
%% =====================================================================

-spec recolectar_estados_unidades([atom()]) -> [#unidad{}].
recolectar_estados_unidades(UnidadesIds) ->
    lists:filtermap(
        fun(Id) ->
            case whereis(Id) of
                Pid when is_pid(Pid) ->
                    try logistica_unidad:obtener_estado(Id) of
                        {ok, Estado} -> {true, Estado};
                        _            -> false
                    catch
                        _:_          -> false
                    end;
                undefined ->
                    false
            end
        end,
        UnidadesIds
    ).
