%%  The contents of this file are subject to the Mozilla Public License
%%  Version 1.1 (the "License"); you may not use this file except in
%%  compliance with the License. You may obtain a copy of the License
%%  at http://www.mozilla.org/MPL/
%%
%%  Software distributed under the License is distributed on an "AS IS"
%%  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%  the License for the specific language governing rights and
%%  limitations under the License.
%%
%%  The Original Code is RabbitMQ.
%%
%%  The Initial Developer of the Original Code is GoPivotal, Inc.
%%  Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module('Elixir.RabbitMQ.CLI.Ctl.Commands.RestartFederationLinkCommand').

-behaviour('Elixir.RabbitMQ.CLI.CommandBehaviour').

-export([
         usage/0,
         flags/0,
         validate/2,
         merge_defaults/2,
         banner/2,
         run/2,
         aliases/0,
         output/2,
         description/0
        ]).


%%----------------------------------------------------------------------------
%% Callbacks
%%----------------------------------------------------------------------------
usage() ->
     <<"restart_federation_link <link_id>">>.

flags() ->
    [].

validate([], _Opts) ->
    {validation_failure, not_enough_args};
validate([_, _ | _], _Opts) ->
    {validation_failure, too_many_args};
validate([_], _) ->
    ok.

merge_defaults(A, O) ->
    {A, O}.

banner([Link], #{node := Node}) ->
    erlang:iolist_to_binary([<<"Restarting federation link ">>, Link, << " on node ">>,
                             atom_to_binary(Node, utf8)]).

run([Id], #{node := Node}) ->
    case rabbit_misc:rpc_call(Node, rabbit_federation_status, lookup, [Id]) of
        {badrpc, _} = Error ->
            Error;
        not_found ->
            {error, <<"Link with the given ID was not found">>};
        Obj ->
            Upstream = proplists:get_value(upstream, Obj),
            Supervisor = proplists:get_value(supervisor, Obj),
            rabbit_misc:rpc_call(Node, rabbit_federation_link_sup, restart,
                                 [Supervisor, Upstream])
    end.

aliases() ->
    [].

description() -> <<"Restarts a federation link with link ID of <link_id>">>.

output(Output, _Opts) ->
    'Elixir.RabbitMQ.CLI.DefaultOutput':output(Output).
