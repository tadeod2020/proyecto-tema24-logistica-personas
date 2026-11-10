%% =====================================================================
%% Programa:    logistica_sup.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Supervisor OTP, one_for_one, Resiliencia)
%% =====================================================================

-module(logistica_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

-define(SERVER, ?MODULE).

-spec start_link() -> {ok, pid()} | {error, any()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    %% Estrategia one_for_one:
    %% Si una unidad falla o se le envía 'kill', solo esa unidad es reiniciada
    %% por el supervisor; el gestor y el resto de la flota continúan intactos.
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },

    GestorChild = #{
        id       => logistica_gestor,
        start    => {logistica_gestor, start_link, []},
        restart  => permanent,
        shutdown => 5000,
        type     => worker,
        modules  => [logistica_gestor]
    },

    %% Especificación de las 4 unidades de la flota de transporte de personas
    RutaEstudiantil = [otay, central_camionera, zona_rio, centro],
    RutaMaquila     = [el_florido, central_camionera, otay],
    RutaCosta       = [centro, zona_rio, playas],

    Unidad1Child = #{
        id       => unidad_1,
        start    => {logistica_unidad, start_link, [unidad_1, "Van Sprinter 01 (Estudiantil)", ruta_estudiantil, RutaEstudiantil, 15]},
        restart  => permanent,
        shutdown => 3000,
        type     => worker,
        modules  => [logistica_unidad]
    },

    Unidad2Child = #{
        id       => unidad_2,
        start    => {logistica_unidad, start_link, [unidad_2, "Minibus Crafter 02 (Maquila)", ruta_maquila, RutaMaquila, 22]},
        restart  => permanent,
        shutdown => 3000,
        type     => worker,
        modules  => [logistica_unidad]
    },

    Unidad3Child = #{
        id       => unidad_3,
        start    => {logistica_unidad, start_link, [unidad_3, "Microbus 03 (Costa / Playas)", ruta_costa, RutaCosta, 18]},
        restart  => permanent,
        shutdown => 3000,
        type     => worker,
        modules  => [logistica_unidad]
    },

    Unidad4Child = #{
        id       => unidad_4,
        start    => {logistica_unidad, start_link, [unidad_4, "Van Refuerzo 04 (Express)", ruta_estudiantil, RutaEstudiantil, 12]},
        restart  => permanent,
        shutdown => 3000,
        type     => worker,
        modules  => [logistica_unidad]
    },

    HttpChild = #{
        id       => logistica_http,
        start    => {logistica_http, start_link, [8080]},
        restart  => permanent,
        shutdown => 5000,
        type     => worker,
        modules  => [logistica_http]
    },

    Children = [GestorChild, Unidad1Child, Unidad2Child, Unidad3Child, Unidad4Child, HttpChild],
    {ok, {SupFlags, Children}}.
