%% =====================================================================
%% Programa:    logistica_app.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Application OTP Behaviour, Punto de Entrada)
%% =====================================================================

-module(logistica_app).
-behaviour(application).

-export([start/2, stop/1, iniciar/0, detener/0]).

-spec start(application:start_type(), any()) -> {ok, pid()} | {error, any()}.
start(_StartType, _StartArgs) ->
    io:format("~n=============================================================~n"),
    io:format("  SISTEMA CONCURRENTE DE LOGÍSTICA DE PERSONAS (TEMA 24)~n"),
    io:format("  Autor: Axel Tadeo Daniels Ceballos — TecNM Campus Tijuana~n"),
    io:format("  Entorno: Erlang/OTP BEAM ~s~n", [erlang:system_info(otp_release)]),
    io:format("=============================================================~n"),
    case logistica_sup:start_link() of
        {ok, Pid} ->
            io:format("[logistica_app] Árbol de supervisión y servicios activos.~n"),
            io:format("[logistica_app] Dashboard web: http://localhost:8080/~n~n"),
            {ok, Pid};
        {error, Reason} ->
            io:format("[logistica_app] Error fatal al iniciar supervisor: ~p~n", [Reason]),
            {error, Reason}
    end.

-spec stop(any()) -> ok.
stop(_State) ->
    io:format("[logistica_app] Deteniendo aplicación de logística...~n"),
    ok.

%% Funciones auxiliares para iniciar desde la consola erl
iniciar() ->
    application:start(sasl),
    application:start(logistica).

detener() ->
    application:stop(logistica).
