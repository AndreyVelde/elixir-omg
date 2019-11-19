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

defmodule OMG.Performance.ByzantineEvents.MutationsTest do
  use ExUnit.Case, async: true

  alias OMG.Performance.ByzantineEvents.Mutations
  alias OMG.State.Transaction

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  setup do
    alice = OMG.TestHelper.generate_entity()
    {:ok, %{alice: alice}}
  end

  describe "mutate_txs/2" do
    test "should produce a different signed transaction every time", %{alice: alice} do
      tx = OMG.TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [{alice, 1}])
      [mutated] = Mutations.mutate_txs([tx], [alice.priv])
      assert mutated != tx
      [mutated2] = Mutations.mutate_txs([mutated], [alice.priv])
      assert mutated2 != mutated
      assert mutated2 != tx
    end

    test "should sign using the private key provided", %{alice: alice} do
      tx = OMG.TestHelper.create_encoded([{1000, 0, 0, alice}], @eth, [{alice, 1}])
      [mutated] = Mutations.mutate_txs([tx], [alice.priv])
      assert %Transaction.Recovered{witnesses: witnesses} = Transaction.Recovered.recover_from!(tx)
      assert %Transaction.Recovered{witnesses: ^witnesses} = Transaction.Recovered.recover_from!(mutated)
    end
  end
end