%% =====================================================================
%% Programa:    logistica.hrl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Definición:  Registros del dominio (Pasajeros, Unidades y Paradas)
%% =====================================================================

-ifndef(LOGISTICA_HRL).
-define(LOGISTICA_HRL, true).

%% Registro para modelar un pasajero que solicita o aborda el servicio
-record(pasajero, {
    id :: integer() | binary(),
    nombre :: string(),
    origen :: atom(),
    destino :: atom(),
    timestamp :: integer()
}).

%% Registro para modelar una estación o parada física con geolocalización
-record(parada, {
    id :: atom(),
    nombre :: string(),
    lat :: float(),
    lon :: float()
}).

%% Registro de estado inmutable de una unidad vehicular de transporte
-record(unidad, {
    id :: atom(),
    nombre :: string(),
    ruta_id :: atom(),
    paradas :: [atom()],
    parada_actual_idx = 1 :: pos_integer(),
    capacidad_max = 15 :: pos_integer(),
    pasajeros = [] :: [#pasajero{}],
    estado = en_espera :: en_espera | en_ruta | en_parada | recuperado,
    kms_totales = 0.0 :: float(),
    viajes_completados = 0 :: non_neg_integer(),
    fallas_recuperadas = 0 :: non_neg_integer()
}).

-endif.
