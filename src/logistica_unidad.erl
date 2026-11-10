%% =====================================================================
%% Programa:    logistica_unidad.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (GenServer OTP, Concurrencia Aislada, Let it crash)
%% =====================================================================

-module(logistica_unidad).
-behaviour(gen_server).

-include("logistica.hrl").

%% API Cliente
-export([
    start_link/5,
    obtener_estado/1,
    abordar/2,
    avanzar/1,
    forzar_crash/2,
    stop/1
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

%% =====================================================================
%% API Cliente
%% =====================================================================

-spec start_link(atom(), string(), atom(), [atom()], pos_integer()) ->
    {ok, pid()} | {error, any()}.
start_link(Id, Nombre, RutaId, Paradas, CapacidadMax) ->
    gen_server:start_link({local, Id}, ?MODULE, [Id, Nombre, RutaId, Paradas, CapacidadMax], []).

-spec obtener_estado(atom() | pid()) -> {ok, #unidad{}} | {error, any()}.
obtener_estado(IdOrPid) ->
    gen_server:call(IdOrPid, obtener_estado).

-spec abordar(atom() | pid(), #pasajero{}) -> {ok, #unidad{}} | {error, any()}.
abordar(IdOrPid, #pasajero{} = Pasajero) ->
    gen_server:call(IdOrPid, {abordar, Pasajero}).

-spec avanzar(atom() | pid()) -> {ok, #unidad{}, [#pasajero{}]} | {error, any()}.
avanzar(IdOrPid) ->
    gen_server:call(IdOrPid, avanzar).

-spec forzar_crash(atom() | pid(), any()) -> no_return().
forzar_crash(IdOrPid, Motivo) ->
    gen_server:call(IdOrPid, {forzar_crash, Motivo}).

-spec stop(atom() | pid()) -> ok.
stop(IdOrPid) ->
    gen_server:stop(IdOrPid).

%% =====================================================================
%% Callbacks de gen_server
%% =====================================================================

init([Id, Nombre, RutaId, Paradas, CapacidadMax]) ->
    %% Registro inicial de la unidad vehicular como proceso independiente en BEAM
    EstadoInicial = #unidad{
        id = Id,
        nombre = Nombre,
        ruta_id = RutaId,
        paradas = Paradas,
        parada_actual_idx = 1,
        capacidad_max = CapacidadMax,
        pasajeros = [],
        estado = en_espera,
        kms_totales = 0.0,
        viajes_completados = 0,
        fallas_recuperadas = 0
    },
    {ok, EstadoInicial}.

handle_call(obtener_estado, _From, State) ->
    {reply, {ok, State}, State};

handle_call({abordar, #pasajero{} = Pasajero}, _From, State) ->
    case logistica_core:asignar_pasajero(State, Pasajero) of
        {ok, NuevoState} ->
            {reply, {ok, NuevoState}, NuevoState};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call(avanzar, _From, State) ->
    {NuevoState, Desembarcados} = logistica_core:avanzar_parada(State),
    {reply, {ok, NuevoState, Desembarcados}, NuevoState};

handle_call({forzar_crash, Motivo}, _From, State) ->
    %% Simulación de falla crítica del proceso vehicular ("let it crash")
    %% Demuestra cómo el supervisor OTP captura la caída y reinicia el actor
    exit({simulacion_falla_critica, Motivo}),
    {reply, ok, State};

handle_call(_Request, _From, State) ->
    {reply, {error, llamada_no_soportada}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
