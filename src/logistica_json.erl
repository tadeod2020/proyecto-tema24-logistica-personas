%% =====================================================================
%% Programa:    logistica_json.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Serialización Funcional Pura, Compatibilidad)
%% =====================================================================

-module(logistica_json).

-export([encode/1, decode/1]).

%% =====================================================================
%% 1. Codificador JSON Funcional Puro (Universal para OTP 24–29)
%% =====================================================================

-spec encode(any()) -> binary().
encode(Term) ->
    case erlang:function_exported(json, encode, 1) of
        true ->
            try
                iolist_to_binary(json:encode(Term))
            catch
                _:_ -> iolist_to_binary(encode_term(Term))
            end;
        false ->
            iolist_to_binary(encode_term(Term))
    end.

encode_term(true)  -> <<"true">>;
encode_term(false) -> <<"false">>;
encode_term(null)  -> <<"null">>;
encode_term(undefined) -> <<"null">>;
encode_term(Int) when is_integer(Int) ->
    integer_to_binary(Int);
encode_term(Float) when is_float(Float) ->
    io_lib:format("~.2f", [Float]);
encode_term(Atom) when is_atom(Atom) ->
    [<<"\"">>, atom_to_binary(Atom, utf8), <<"\"">>];
encode_term(Bin) when is_binary(Bin) ->
    [<<"\"">>, escapar_string(Bin), <<"\"">>];
encode_term(Str) when is_list(Str) ->
    case io_lib:printable_unicode_list(Str) of
        true ->
            [<<"\"">>, escapar_string(unicode:characters_to_binary(Str)), <<"\"">>];
        false ->
            %% Lista de elementos
            [<<"[">>, unircon_comas([encode_term(Elem) || Elem <- Str]), <<"]">>]
    end;
encode_term(Map) when is_map(Map) ->
    Pares = maps:to_list(Map),
    ParesCodificados = [
        [encode_clave(K), <<":">>, encode_term(V)]
        || {K, V} <- Pares
    ],
    [<<"{">>, unircon_comas(ParesCodificados), <<"}">>];
encode_term(_) ->
    <<"null">>.

encode_clave(Atom) when is_atom(Atom) ->
    [<<"\"">>, atom_to_binary(Atom, utf8), <<"\"">>];
encode_clave(Bin) when is_binary(Bin) ->
    [<<"\"">>, escapar_string(Bin), <<"\"">>];
encode_clave(Str) when is_list(Str) ->
    [<<"\"">>, escapar_string(unicode:characters_to_binary(Str)), <<"\"">>];
encode_clave(Other) ->
    encode_term(Other).

escapar_string(Bin) ->
    binary:replace(
        binary:replace(Bin, <<"\\">>, <<"\\\\">>, [global]),
        <<"\"">>, <<"\\\"">>, [global]
    ).

unircon_comas([]) -> [];
unircon_comas([Unico]) -> [Unico];
unircon_comas([Primero | Resto]) ->
    [Primero, <<",">> | unircon_comas(Resto)].

%% =====================================================================
%% 2. Decodificador JSON Funcional Básico
%% =====================================================================

-spec decode(binary() | string()) -> {ok, map()} | {error, any()}.
decode(Bin) when is_list(Bin) ->
    decode(unicode:characters_to_binary(Bin));
decode(Bin) when is_binary(Bin) ->
    case erlang:function_exported(json, decode, 1) of
        true ->
            try
                {ok, json:decode(Bin)}
            catch
                _:_ -> decode_simple(Bin)
            end;
        false ->
            decode_simple(Bin)
    end.

%% Parser simple para objetos JSON con claves comunes de la aplicación
decode_simple(Bin) ->
    Clean = binary:replace(Bin, [<<"\r">>, <<"\n">>, <<"\t">>], <<>>, [global]),
    case binary:match(Clean, <<"{">>) of
        nomatch -> {error, formato_invalido};
        _ ->
            Campos = [
                extraer_campo(Clean, <<"\"nombre\"">>),
                extraer_campo(Clean, <<"\"origen\"">>),
                extraer_campo(Clean, <<"\"destino\"">>),
                extraer_campo(Clean, <<"\"unidad_id\"">>),
                extraer_campo(Clean, <<"\"accion\"">>)
            ],
            Mapa = lists:foldl(
                fun
                    ({ok, K, V}, Acc) -> Acc#{K => V};
                    (error, Acc)      -> Acc
                end,
                #{},
                Campos
            ),
            {ok, Mapa}
    end.

extraer_campo(Bin, Clave) ->
    case binary:match(Bin, Clave) of
        {Pos, Len} ->
            Resto = binary:part(Bin, Pos + Len, byte_size(Bin) - (Pos + Len)),
            case re:run(Resto, "^\\s*:\\s*\"([^\"]*)\"", [{capture, [1], binary}]) of
                {match, [Valor]} ->
                    ClaveSinComillas = binary:part(Clave, 1, byte_size(Clave) - 2),
                    {ok, ClaveSinComillas, Valor};
                _ ->
                    case re:run(Resto, "^\\s*:\\s*([0-9]+)", [{capture, [1], binary}]) of
                        {match, [NumBin]} ->
                            ClaveSinComillas = binary:part(Clave, 1, byte_size(Clave) - 2),
                            {ok, ClaveSinComillas, binary_to_integer(NumBin)};
                        _ ->
                            error
                    end
            end;
        nomatch ->
            error
    end.
