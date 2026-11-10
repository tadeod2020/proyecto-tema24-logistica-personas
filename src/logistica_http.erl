%% =====================================================================
%% Programa:    logistica_http.erl
%% Autor:       Axel Tadeo Daniels Ceballos
%% Matrícula:   Estudiante de Ing. en Sistemas Computacionales
%% Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
%% Actividad:   Tema 24: Sistema Concurrente de Logística de Personas
%% Entorno:     Erlang/OTP 25+ / BEAM en Ubuntu Linux (AWS Academy / Local)
%% Rúbrica:     Nivel Excelente (Servidor HTTP Nativo OTP, REST API, UI Stitch)
%% =====================================================================

-module(logistica_http).
-behaviour(gen_server).

-include("logistica.hrl").

%% API Cliente
-export([start_link/0, start_link/1, stop/0]).

%% Callbacks de gen_server
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% Worker de conexión HTTP
-export([gestionar_conexion/2]).

-define(DEFAULT_PORT, 8080).

-record(state, {
    listen_socket :: gen_tcp:socket(),
    port :: inet:port_number(),
    static_dir :: string()
}).

%% =====================================================================
%% API Cliente
%% =====================================================================

-spec start_link() -> {ok, pid()} | {error, any()}.
start_link() ->
    start_link(?DEFAULT_PORT).

-spec start_link(inet:port_number()) -> {ok, pid()} | {error, any()}.
start_link(Port) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Port], []).

-spec stop() -> ok.
stop() ->
    gen_server:stop(?MODULE).

%% =====================================================================
%% Callbacks de gen_server
%% =====================================================================

init([Port]) ->
    %% Directorio de archivos estáticos de la interfaz Google Stitch
    StaticDir = resolver_directorio_estatico(),
    case gen_tcp:listen(Port, [
        binary,
        {packet, http_bin},
        {active, false},
        {reuseaddr, true},
        {nodelay, true}
    ]) of
        {ok, ListenSocket} ->
            io:format("[logistica_http] Servidor Web REST activo en http://localhost:~p/~n", [Port]),
            %% Iniciar el ciclo de aceptación asíncrono
            self() ! accept_siguiente,
            {ok, #state{listen_socket = ListenSocket, port = Port, static_dir = StaticDir}};
        {error, eaddrinuse} ->
            io:format("[logistica_http] Puerto ~p ocupado; intentando en ~p~n", [Port, Port + 1]),
            init([Port + 1]);
        {error, Reason} ->
            {stop, Reason}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, no_soportado}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(accept_siguiente, #state{listen_socket = ListenSocket, static_dir = StaticDir} = State) ->
    case gen_tcp:accept(ListenSocket, 1000) of
        {ok, ClientSocket} ->
            %% Lanzar un proceso ligero de Erlang por cada cliente HTTP
            Pid = spawn(?MODULE, gestionar_conexion, [ClientSocket, StaticDir]),
            gen_tcp:controlling_process(ClientSocket, Pid);
        {error, timeout} ->
            ok;
        {error, closed} ->
            ok;
        {error, Reason} ->
            io:format("[logistica_http] Advertencia al aceptar conexion: ~p~n", [Reason])
    end,
    self() ! accept_siguiente,
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{listen_socket = ListenSocket}) ->
    if ListenSocket =/= undefined -> gen_tcp:close(ListenSocket);
       true -> ok
    end,
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% =====================================================================
%% Worker de Conexión HTTP (Proceso por Petición)
%% =====================================================================

-spec gestionar_conexion(gen_tcp:socket(), string()) -> ok.
gestionar_conexion(Socket, StaticDir) ->
    case gen_tcp:recv(Socket, 0, 5000) of
        {ok, {http_request, Method, {abs_path, PathBin}, _Version}} ->
            Path = binary_to_list(PathBin),
            Headers = leer_encabezados(Socket, #{}),
            Body = leer_cuerpo(Socket, Headers),
            despachar_ruta(Socket, Method, Path, Body, StaticDir);
        _ ->
            gen_tcp:close(Socket)
    end.

leer_encabezados(Socket, Headers) ->
    case gen_tcp:recv(Socket, 0, 5000) of
        {ok, {http_header, _, Field, _, Value}} ->
            FieldStr = string:lowercase(atom_o_string(Field)),
            leer_encabezados(Socket, Headers#{FieldStr => Value});
        {ok, http_eoh} ->
            Headers;
        _ ->
            Headers
    end.

atom_o_string(Atom) when is_atom(Atom) -> atom_to_list(Atom);
atom_o_string(Bin) when is_binary(Bin)  -> binary_to_list(Bin);
atom_o_string(List) when is_list(List)  -> List.

leer_cuerpo(Socket, Headers) ->
    case maps:get("content-length", Headers, undefined) of
        undefined ->
            <<>>;
        LengthStr ->
            Length = binary_to_integer_safe(LengthStr),
            if Length > 0 ->
                inet:setopts(Socket, [{packet, raw}]),
                case gen_tcp:recv(Socket, Length, 5000) of
                    {ok, BodyBin} -> BodyBin;
                    _ -> <<>>
                end;
            true ->
                <<>>
            end
    end.

binary_to_integer_safe(Bin) when is_binary(Bin) ->
    try binary_to_integer(Bin) catch _:_ -> 0 end;
binary_to_integer_safe(Str) when is_list(Str) ->
    try list_to_integer(Str) catch _:_ -> 0 end;
binary_to_integer_safe(_) -> 0.

%% =====================================================================
%% Router REST y Servidor de Archivos Estáticos
%% =====================================================================

despachar_ruta(Socket, 'OPTIONS', _Path, _Body, _StaticDir) ->
    responder(Socket, 200, <<"application/json">>, <<"{\"status\":\"ok\"}">>);

despachar_ruta(Socket, 'GET', "/", _Body, StaticDir) ->
    servir_archivo(Socket, filename:join(StaticDir, "index.html"), <<"text/html; charset=utf-8">>);

despachar_ruta(Socket, 'GET', "/index.html", _Body, StaticDir) ->
    servir_archivo(Socket, filename:join(StaticDir, "index.html"), <<"text/html; charset=utf-8">>);

despachar_ruta(Socket, 'GET', "/style.css", _Body, StaticDir) ->
    servir_archivo(Socket, filename:join(StaticDir, "style.css"), <<"text/css; charset=utf-8">>);

despachar_ruta(Socket, 'GET', "/app.js", _Body, StaticDir) ->
    servir_archivo(Socket, filename:join(StaticDir, "app.js"), <<"application/javascript; charset=utf-8">>);

despachar_ruta(Socket, 'GET', "/api/paradas", _Body, _StaticDir) ->
    Paradas = logistica_core:paradas_catalogo(),
    ParadasMap = [
        #{
            id => P#parada.id,
            nombre => list_to_binary(P#parada.nombre),
            lat => P#parada.lat,
            lon => P#parada.lon
        } || P <- Paradas
    ],
    JSON = logistica_json:encode(ParadasMap),
    responder(Socket, 200, <<"application/json">>, JSON);

despachar_ruta(Socket, 'GET', "/api/unidades", _Body, _StaticDir) ->
    Unidades = logistica_gestor:listar_unidades(),
    JSON = logistica_json:encode(Unidades),
    responder(Socket, 200, <<"application/json">>, JSON);

despachar_ruta(Socket, 'GET', "/api/metricas", _Body, _StaticDir) ->
    Metricas = logistica_gestor:obtener_metricas(),
    JSON = logistica_json:encode(Metricas),
    responder(Socket, 200, <<"application/json">>, JSON);

despachar_ruta(Socket, 'GET', "/api/estado", _Body, _StaticDir) ->
    Unidades = logistica_gestor:listar_unidades(),
    Metricas = logistica_gestor:obtener_metricas(),
    Paradas = [
        #{
            id => P#parada.id,
            nombre => list_to_binary(P#parada.nombre),
            lat => P#parada.lat,
            lon => P#parada.lon
        } || P <- logistica_core:paradas_catalogo()
    ],
    Payload = #{
        exito => true,
        unidades => Unidades,
        metricas => Metricas,
        paradas => Paradas
    },
    JSON = logistica_json:encode(Payload),
    responder(Socket, 200, <<"application/json">>, JSON);

despachar_ruta(Socket, 'POST', "/api/solicitar", Body, _StaticDir) ->
    case logistica_json:decode(Body) of
        {ok, Map} ->
            NombreBin = maps:get(<<"nombre">>, Map, <<"Pasajero">>),
            OrigenBin = maps:get(<<"origen">>, Map, <<"otay">>),
            DestinoBin = maps:get(<<"destino">>, Map, <<"centro">>),
            Nombre = binary_to_list(NombreBin),
            Origen = safe_binary_to_atom(OrigenBin),
            Destino = safe_binary_to_atom(DestinoBin),
            case logistica_gestor:solicitar_viaje(Nombre, Origen, Destino) of
                {ok, InfoAsignacion} ->
                    JSON = logistica_json:encode(InfoAsignacion),
                    responder(Socket, 200, <<"application/json">>, JSON);
                {error, Reason} ->
                    JSON = logistica_json:encode(#{
                        exito => false,
                        error => atom_to_binary(Reason, utf8)
                    }),
                    responder(Socket, 400, <<"application/json">>, JSON)
            end;
        _ ->
            responder(Socket, 400, <<"application/json">>, <<"{\"error\":\"JSON invalido\"}">>)
    end;

despachar_ruta(Socket, 'POST', "/api/avanzar", Body, _StaticDir) ->
    case logistica_json:decode(Body) of
        {ok, Map} ->
            UnidadIdBin = maps:get(<<"unidad_id">>, Map, <<"todas">>),
            case UnidadIdBin of
                <<"todas">> ->
                    Resultados = logistica_gestor:avanzar_todas(),
                    JSON = logistica_json:encode(#{
                        exito => true,
                        mensaje => <<"Todas las unidades avanzaron">>,
                        resultados => [atom_to_binary(Id, utf8) || {Id, _} <- Resultados]
                    }),
                    responder(Socket, 200, <<"application/json">>, JSON);
                _ ->
                    UnidadId = safe_binary_to_atom(UnidadIdBin),
                    case logistica_gestor:avanzar_unidad(UnidadId) of
                        {ok, UnidadMap, Desembarcados} ->
                            JSON = logistica_json:encode(#{
                                exito => true,
                                unidad => UnidadMap,
                                desembarcados => Desembarcados
                            }),
                            responder(Socket, 200, <<"application/json">>, JSON);
                        {error, Reason} ->
                            JSON = logistica_json:encode(#{
                                exito => false,
                                error => atom_to_binary(Reason, utf8)
                            }),
                            responder(Socket, 400, <<"application/json">>, JSON)
                    end
            end;
        _ ->
            responder(Socket, 400, <<"application/json">>, <<"{\"error\":\"JSON invalido\"}">>)
    end;

despachar_ruta(Socket, 'POST', "/api/crash", Body, _StaticDir) ->
    case logistica_json:decode(Body) of
        {ok, Map} ->
            UnidadIdBin = maps:get(<<"unidad_id">>, Map, <<"unidad_1">>),
            UnidadId = safe_binary_to_atom(UnidadIdBin),
            case logistica_gestor:provocar_crash(UnidadId) of
                {ok, Mensaje} ->
                    JSON = logistica_json:encode(#{
                        exito => true,
                        accion => <<"let_it_crash">>,
                        unidad => UnidadId,
                        mensaje => Mensaje
                    }),
                    responder(Socket, 200, <<"application/json">>, JSON);
                {error, Reason} ->
                    JSON = logistica_json:encode(#{
                        exito => false,
                        error => atom_to_binary(Reason, utf8)
                    }),
                    responder(Socket, 400, <<"application/json">>, JSON)
            end;
        _ ->
            responder(Socket, 400, <<"application/json">>, <<"{\"error\":\"JSON invalido\"}">>)
    end;

despachar_ruta(Socket, _Method, _Path, _Body, _StaticDir) ->
    responder(Socket, 404, <<"application/json">>, <<"{\"error\":\"Ruta no encontrada\"}">>).

%% =====================================================================
%% Utilidades HTTP
%% =====================================================================

responder(Socket, StatusCode, ContentType, Body) ->
    StatusText = case StatusCode of
        200 -> <<"200 OK">>;
        400 -> <<"400 Bad Request">>;
        404 -> <<"404 Not Found">>;
        500 -> <<"500 Internal Server Error">>;
        _   -> <<"200 OK">>
    end,
    Len = byte_size(Body),
    Response = [
        <<"HTTP/1.1 ">>, StatusText, <<"\r\n">>,
        <<"Content-Type: ">>, ContentType, <<"\r\n">>,
        <<"Content-Length: ">>, integer_to_binary(Len), <<"\r\n">>,
        <<"Access-Control-Allow-Origin: *\r\n">>,
        <<"Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n">>,
        <<"Access-Control-Allow-Headers: Content-Type\r\n">>,
        <<"Connection: close\r\n\r\n">>,
        Body
    ],
    inet:setopts(Socket, [{packet, raw}]),
    gen_tcp:send(Socket, Response),
    gen_tcp:close(Socket).

servir_archivo(Socket, FilePath, ContentType) ->
    case file:read_file(FilePath) of
        {ok, Content} ->
            responder(Socket, 200, ContentType, Content);
        {error, _Reason} ->
            HtmlFallback = iolist_to_binary([
                <<"<!DOCTYPE html><html><head><title>Logistica Daniels</title></head><body>">>,
                <<"<h1>Logistica de Personas - Erlang/OTP</h1>">>,
                <<"<p>Archivo no encontrado: ">>, list_to_binary(FilePath), <<"</p></body></html>">>
            ]),
            responder(Socket, 404, <<"text/html; charset=utf-8">>, HtmlFallback)
    end.

safe_binary_to_atom(Bin) when is_binary(Bin) ->
    try binary_to_existing_atom(Bin, utf8)
    catch _:_ -> binary_to_atom(Bin, utf8)
    end;
safe_binary_to_atom(Atom) when is_atom(Atom) ->
    Atom;
safe_binary_to_atom(List) when is_list(List) ->
    list_to_atom(List).

resolver_directorio_estatico() ->
    DirCandidatos = [
        filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "static"]),
        filename:join([filename:dirname(code:which(?MODULE)), "priv", "static"]),
        "/home/axeld/Programacion Logica y Funcional/proyecto-tema24-logistica-personas/priv/static",
        "./priv/static"
    ],
    buscar_primer_dir_existente(DirCandidatos).

buscar_primer_dir_existente([]) -> "./priv/static";
buscar_primer_dir_existente([Dir | Resto]) ->
    case filelib:is_dir(Dir) of
        true  -> Dir;
        false -> buscar_primer_dir_existente(Resto)
    end.
