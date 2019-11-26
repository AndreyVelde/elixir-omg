# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Support.Conformance.Case do
  @moduledoc """
  `ExUnit` test case for the setup required by a test of Elixir and Solidity implementation conformance
  """
  use ExUnit.CaseTemplate

  alias OMG.Eth
  alias Support.Deployer
  alias Support.DevNode

  setup_all do
    {:ok, exit_fn} =
      if Application.get_env(:omg_eth, :run_test_eth_dev_node, true) do
        DevNode.start()
      else
        {:ok, fn -> :ok end}
      end

    root_path = Application.fetch_env!(:omg_eth, :umbrella_root_dir)
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _, signtest_addr} = Deployer.create_new("PaymentEip712LibMock", root_path, Eth.Encoding.from_hex(addr), [])

    {:ok, _, tx_model_inspector_addr} =
      Deployer.create_new("PaymentTransactionModelInspector", root_path, Eth.Encoding.from_hex(addr), [])

    # impose our testing signature contract wrapper (mock) as the validating contract, which normally would be
    # plasma framework
    :ok = Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: Eth.Encoding.to_hex(signtest_addr)})

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: "0x0000000000000000000000000000000000000001"})
      exit_fn.()
    end)

    # FIXME: consider splitting into 2 cases or moving the deployment elsewhere; refactor this code
    [contract: signtest_addr, tx_model_inspector: tx_model_inspector_addr]
  end
end
