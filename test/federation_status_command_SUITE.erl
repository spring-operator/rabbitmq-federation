%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(federation_status_command_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

-define(CMD, 'Elixir.RabbitMQ.CLI.Ctl.Commands.FederationStatusCommand').

all() ->
    [
     {group, not_federated},
     {group, federated},
     {group, federated_down}
    ].

groups() ->
    [
     {not_federated, [], [
                          run_not_federated,
                          output_not_federated
                         ]},
     {federated, [], [
                      run_federated,
                      output_federated
                     ]},
     {federated_down, [], [
                           run_down_federated
                          ]}
    ].

%% -------------------------------------------------------------------
%% Testsuite setup/teardown.
%% -------------------------------------------------------------------

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    Config1 = rabbit_ct_helpers:set_config(Config, [
        {rmq_nodename_suffix, ?MODULE}
      ]),
    Config2 = rabbit_ct_helpers:run_setup_steps(Config1,
      rabbit_ct_broker_helpers:setup_steps() ++
      rabbit_ct_client_helpers:setup_steps()),
    Config2.

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config,
      rabbit_ct_client_helpers:teardown_steps() ++
      rabbit_ct_broker_helpers:teardown_steps()).

init_per_group(federated, Config) ->
    rabbit_federation_test_util:setup_federation(Config),
    Config;
init_per_group(federated_down, Config) ->
    rabbit_federation_test_util:setup_down_federation(Config),
    Config;
init_per_group(_, Config) ->
    Config.

end_per_group(_, Config) ->
    Config.

init_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_started(Config, Testcase).

end_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_finished(Config, Testcase).

%% -------------------------------------------------------------------
%% Testcases.
%% -------------------------------------------------------------------
run_not_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    {stream, []} = ?CMD:run([], Opts#{only_down => false}).

output_not_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    {stream, []} = ?CMD:output({stream, []}, Opts).

run_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    %% All
    rabbit_federation_test_util:with_ch(
      Config,
      fun(_) ->
              {stream, [Props]} = ?CMD:run([], Opts#{only_down => false}),
              <<"upstream">> = proplists:get_value(upstream_queue, Props),
              <<"fed.downstream">> = proplists:get_value(queue, Props),
              running = proplists:get_value(status, Props)
      end,
      [rabbit_federation_test_util:q(<<"upstream">>),
       rabbit_federation_test_util:q(<<"fed.downstream">>)]),
    %% Down
    rabbit_federation_test_util:with_ch(
      Config,
      fun(_) ->
              {stream, []} = ?CMD:run([], Opts#{only_down => true})
      end,
      [rabbit_federation_test_util:q(<<"upstream">>),
       rabbit_federation_test_util:q(<<"fed.downstream">>)]).

run_down_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    %% All
    rabbit_federation_test_util:with_ch(
      Config,
      fun(_) ->
              {stream, ManyProps} = ?CMD:run([], Opts#{only_down => false}),
              Links = [{proplists:get_value(upstream, Props),
                        proplists:get_value(status, Props)}
                       || Props <- ManyProps],
              [{<<"broken-bunny">>, error}, {<<"localhost">>, running}]
                  = lists:sort(Links)
      end,
      [rabbit_federation_test_util:q(<<"upstream">>),
       rabbit_federation_test_util:q(<<"fed.downstream">>)]),
    %% Down
    rabbit_federation_test_util:with_ch(
      Config,
      fun(_) ->
              {stream, [Props]} = ?CMD:run([], Opts#{only_down => true}),
              <<"broken-bunny">> = proplists:get_value(upstream, Props),
              error = proplists:get_value(status, Props)
      end,
      [rabbit_federation_test_util:q(<<"upstream">>),
       rabbit_federation_test_util:q(<<"fed.downstream">>)]).

output_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    Input = {stream,[[{queue, <<"fed.downstream">>},
                      {upstream_queue, <<"upstream">>},
                      {type, queue},
                      {vhost, <<"/">>},
                      {upstream, <<"localhost">>},
                      {status, running},
                      {local_connection, <<"<rmq-ct-federation_status_command_SUITE-1-21000@localhost.1.563.0>">>},
                      {uri, <<"amqp://localhost:21000">>},
                      {timestamp, {{2016,11,21},{8,51,19}}}]]},
    {stream, [#{queue := <<"fed.downstream">>,
                upstream_queue := <<"upstream">>,
                type := queue,
                vhost := <<"/">>,
                upstream := <<"localhost">>,
                status := running,
                local_connection := <<"<rmq-ct-federation_status_command_SUITE-1-21000@localhost.1.563.0>">>,
                uri := <<"amqp://localhost:21000">>,
                last_changed := <<"2016-11-21 08:51:19">>,
                exchange := <<>>,
                upstream_exchange := <<>>,
                error := <<>>}]}
        = ?CMD:output(Input, Opts).
