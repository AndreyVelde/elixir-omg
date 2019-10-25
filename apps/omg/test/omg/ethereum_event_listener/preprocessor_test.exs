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

defmodule OMG.EthereumEventListener.PreprocessorTest do
  @moduledoc """
  Tests whether all known events are preprocessed accurately
  """

  use ExUnit.Case, async: true

  alias OMG.Utxo
  alias OMG.EthereumEventListener.Preprocessor

  require Utxo

  @encoded_utxo_pos 1_000_000_000_000_000_000_000

  describe "apply/1" do
    test "injects input/output information into piggyback-related events" do
      assert %{omg_data: %{piggyback_type: :input}} =
               Preprocessor.apply(%{event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)"})

      assert %{omg_data: %{piggyback_type: :input}} =
               Preprocessor.apply(%{event_signature: "InFlightExitInputBlocked(address,bytes32,uint16)"})

      assert %{omg_data: %{piggyback_type: :input}} =
               Preprocessor.apply(%{event_signature: "InFlightExitInputWithdrawn(uint160,uint16)"})

      assert %{omg_data: %{piggyback_type: :output}} =
               Preprocessor.apply(%{event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)"})

      assert %{omg_data: %{piggyback_type: :output}} =
               Preprocessor.apply(%{event_signature: "InFlightExitOutputBlocked(address,bytes32,uint16)"})

      assert %{omg_data: %{piggyback_type: :output}} =
               Preprocessor.apply(%{event_signature: "InFlightExitOutputWithdrawn(uint160,uint16)"})
    end
  end

  test "decodes utxo_positions automatically" do
    assert Utxo.position(_, _, _) =
             Preprocessor.apply(%{event_signature: "", challenge_position: @encoded_utxo_pos}).challenge_position

    assert Utxo.position(_, _, _) =
             Preprocessor.apply(%{event_signature: "", competitor_position: @encoded_utxo_pos}).competitor_position

    assert [Utxo.position(_, _, _) = utxo_pos, utxo_pos] =
             Preprocessor.apply(%{
               event_signature: "",
               call_data: %{input_utxos_pos: [@encoded_utxo_pos, @encoded_utxo_pos]}
             }).call_data.input_utxos_pos

    assert Utxo.position(_, _, _) =
             Preprocessor.apply(%{event_signature: "", call_data: %{utxo_pos: @encoded_utxo_pos}}).call_data.utxo_pos
  end

  test "preserves existing event data" do
    event = %{event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)", other_stuff: ""}

    assert %{event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)", other_stuff: ""} =
             Preprocessor.apply(event)
  end

  test "by default does nothing, if only the signature is defined (it must be)" do
    event = %{event_signature: "NoSuchEvent()"}
    assert ^event = Preprocessor.apply(event)
    assert_raise FunctionClauseError, fn -> Preprocessor.apply({%{}}) end
  end
end
