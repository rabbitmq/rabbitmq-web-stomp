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
%% Copyright (c) 2007-2020 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(rabbit_web_stomp_app).

-behaviour(application).
-export([start/2, stop/1]).

%%----------------------------------------------------------------------------

-spec start(_, _) -> {ok, pid()}.
start(_Type, _StartArgs) ->
    ok = rabbit_web_stomp_listener:init(),
    rabbit_web_stomp_sup:start_link().

-spec stop(_) -> ok.
stop(_State) ->
    ok.
