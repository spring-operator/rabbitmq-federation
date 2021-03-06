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

-module(restart_federation_link_command_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

-define(CMD, 'Elixir.RabbitMQ.CLI.Ctl.Commands.RestartFederationLinkCommand').

all() ->
    [
     {group, federated_down}
    ].

groups() ->
    [
     {federated_down, [], [
                           run,
                           run_not_found,
                           output
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
    {stream, []} = ?CMD:run([], Opts#{'only-down' => false}).

output_not_federated(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    {stream, []} = ?CMD:output({stream, []}, Opts).

run(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    rabbit_federation_test_util:with_ch(
      Config,
      fun(_) ->
              [Link | _] = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                        rabbit_federation_status, status, []),
              Id = proplists:get_value(id, Link),
              ok = ?CMD:run([Id], Opts)
      end,
      [rabbit_federation_test_util:q(<<"upstream">>),
       rabbit_federation_test_util:q(<<"fed.downstream">>)]).

run_not_found(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    {error, _ErrorMsg} = ?CMD:run([<<"MakingItUp">>], Opts).

output(Config) ->
    [A] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    Opts = #{node => A},
    ok = ?CMD:output(ok, Opts).
