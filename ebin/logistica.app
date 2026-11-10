{application, logistica, [
    {description, "Sistema Concurrente de Logistica de Personas en Erlang/OTP"},
    {vsn, "1.0.0"},
    {registered, [logistica_sup, logistica_gestor, logistica_http, unidad_1, unidad_2, unidad_3, unidad_4]},
    {mod, {logistica_app, []}},
    {applications, [
        kernel,
        stdlib
    ]},
    {env, [
        {http_port, 8080}
    ]},
    {modules, [
        logistica_core,
        logistica_json,
        logistica_unidad,
        logistica_gestor,
        logistica_http,
        logistica_sup,
        logistica_app
    ]},
    {licenses, ["Apache-2.0"]},
    {links, [{"GitHub", "https://github.com/tectijuana/programacionlogicayfuncional"}]}
]}.
