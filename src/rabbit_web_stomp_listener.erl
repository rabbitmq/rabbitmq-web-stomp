%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2019 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_web_stomp_listener).

-export([init/0]).

%% for testing purposes
-export([get_binding_address/1, get_tcp_port/1, get_tcp_conf/2]).

-include_lib("rabbitmq_stomp/include/rabbit_stomp.hrl").


%% --------------------------------------------------------------------------

-spec init() -> ok.
init() ->
    WsFrame = get_env(ws_frame, text),
    CowboyOpts0 = maps:from_list(get_env(cowboy_opts, [])),
    CowboyOpts = CowboyOpts0#{proxy_header => get_env(proxy_protocol, false)},
    CowboyWsOpts = maps:from_list(get_env(cowboy_ws_opts, [])),

    VhostRoutes = [
        {get_env(ws_path, "/ws"), rabbit_web_stomp_handler, [{type, WsFrame}, {ws_opts, CowboyWsOpts}]}
    ],
    Routes = cowboy_router:compile([{'_',  VhostRoutes}]), % any vhost

    case get_env(tcp_config, []) of
        []       -> ok;
        TCPConf0 -> start_tcp_listener(TCPConf0, CowboyOpts, Routes)
    end,
    case get_env(ssl_config, []) of
        []       -> ok;
        TLSConf0 -> start_tls_listener(TLSConf0, CowboyOpts, Routes)
    end,
    ok.

start_tcp_listener(TCPConf0, CowboyOpts, Routes) ->
  NumTcpAcceptors = case application:get_env(rabbitmq_web_stomp, num_tcp_acceptors) of
      undefined -> get_env(num_acceptors, 10);
      {ok, NumTcp}  -> NumTcp
  end,
  Port = get_tcp_port(application:get_all_env(rabbitmq_web_stomp)),
  TCPConf = get_tcp_conf(TCPConf0, Port),
  MaxConnections = get_max_connections(),
  case ranch:start_listener(
          http, NumTcpAcceptors,
          ranch_tcp, [{connection_type, supervisor}, {max_connections, MaxConnections}] ++ TCPConf,
          rabbit_web_stomp_connection_sup,
          CowboyOpts#{env => #{dispatch => Routes},
                      middlewares => [cowboy_router,
                                      rabbit_web_stomp_middleware,
                                      cowboy_handler]}) of
      {ok, _}                       -> ok;
      {error, {already_started, _}} -> ok;
      {error, ErrTCP}                  ->
          rabbit_log_connection:error(
              "Failed to start a WebSocket (HTTP) listener. Error: ~p,"
              " listener settings: ~p~n",
              [ErrTCP, TCPConf]),
          throw(ErrTCP)
  end,
  listener_started('http/web-stomp', TCPConf),
  rabbit_log_connection:info(
      "rabbit_web_stomp: listening for HTTP connections on ~s:~w~n",
      [get_binding_address(TCPConf), Port]).


start_tls_listener(TLSConf0, CowboyOpts, Routes) ->
  rabbit_networking:ensure_ssl(),
  NumSslAcceptors = case application:get_env(rabbitmq_web_stomp, num_ssl_acceptors) of
      undefined     -> get_env(num_acceptors, 10);
      {ok, NumSsl}  -> NumSsl
  end,
  TLSPort = proplists:get_value(port, TLSConf0),
  TLSConf = maybe_parse_ip(TLSConf0),
  MaxConnections = get_max_connections(),
  case ranch:start_listener(
         https, NumSslAcceptors,
         ranch_ssl, [{connection_type, supervisor}, {max_connections, MaxConnections}] ++ TLSConf,
         rabbit_web_stomp_connection_sup,
         CowboyOpts#{env => #{dispatch => Routes},
                     middlewares => [cowboy_router,
                                     rabbit_web_stomp_middleware,
                                     cowboy_handler]}) of
      {ok, _}                       -> ok;
      {error, {already_started, _}} -> ok;
      {error, ErrTLS}                  ->
          rabbit_log_connection:error(
              "Failed to start a TLS WebSocket (HTTPS) listener. Error: ~p,"
              " listener settings: ~p~n",
              [ErrTLS, TLSConf]),
          throw(ErrTLS)
  end,
  listener_started('https/web-stomp', TLSConf),
  rabbit_log_connection:info(
      "rabbit_web_stomp: listening for HTTPS connections on ~s:~w~n",
      [get_binding_address(TLSConf), TLSPort]).

listener_started(Protocol, Listener) ->
    Port = rabbit_misc:pget(port, Listener),
    [rabbit_networking:tcp_listener_started(Protocol, Listener,
                                            IPAddress, Port)
     || {IPAddress, _Port, _Family}
        <- rabbit_networking:tcp_listener_addresses(Port)],
    ok.

get_env(Key, Default) ->
    rabbit_misc:get_env(rabbitmq_web_stomp, Key, Default).

get_tcp_port(Configuration) ->
    %% The 'tcp_config' option may include the port, and we already have
    %% a 'port' option. We prioritize the 'port' option  in 'tcp_config' (if any)
    %% over the one found at the root of the env proplist.
    TcpConfiguration = proplists:get_value(tcp_config, Configuration, []),
    case proplists:get_value(port, TcpConfiguration) of
        undefined ->
            proplists:get_value(port, Configuration, 15674);
        Port ->
            Port
    end.

get_tcp_conf(TcpConfiguration, Port0) ->
    Port = [{port, Port0} | proplists:delete(port, TcpConfiguration)],
    maybe_parse_ip(Port).

maybe_parse_ip(Configuration) ->
    case proplists:get_value(ip, Configuration) of
        undefined ->
            Configuration;
        IP when is_tuple(IP) ->
            Configuration;
        IP when is_list(IP) ->
            {ok, ParsedIP} = inet_parse:address(IP),
            [{ip, ParsedIP} | proplists:delete(ip, Configuration)]
    end.

get_binding_address(Configuration) ->
    case proplists:get_value(ip, Configuration) of
        undefined ->
            "0.0.0.0";
        IP when is_tuple(IP) ->
            inet:ntoa(IP);
        IP when is_list(IP) ->
            IP
    end.

get_max_connections() ->
  rabbit_misc:get_env(rabbitmq_web_stomp, max_connections, infinity).
