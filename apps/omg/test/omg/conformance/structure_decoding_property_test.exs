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

defmodule OMG.Conformance.StructureDecodingPropertyTest do
  @moduledoc """
  Checks if some properties about the signatures (structural, EIP-712 hashes to be precise) hold for the Elixir and
  Solidity implementations
  """

  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.Utxo

  import Support.Conformance.Property

  use PropCheck
  use Support.Conformance.Case, async: false

  @moduletag :integration
  @moduletag :common
  @moduletag :property
  @moduletag timeout: 240_000

  # FIXME: remove work tag
  @tag :work
  property "any encoded tx decodes to the same transaction object in all implementations",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{tx_model_inspector: contract} do
    forall tx <- payment_tx() do
      verify(contract, tx)
    end
  end

  # FIXME: implement
  # property "any 2 different encoded txs decode to different transaction objects, regardless of implementation",
  #          [1000, :verbose, max_size: 100, constraint_tries: 100_000],
  #          %{tx_model_inspector: contract} do
  #   forall [{tx1, tx2} <- distinct_payment_txs()] do
  #     verify_distinct(contract, tx1, tx2)
  #   end
  # end

  # FIXME: rethink, after the mutation story is figured out. Without mutations mutating to sth that makes sense, there's
  #        no point in having those, since in current form, they always test only invalid inputs and throw
  # property "any crude-mutated tx binary either fails to decode to a transaction object or is recognized as different",
  #          [1000, :verbose, max_size: 100, constraint_tries: 100_000],
  #          %{contract: contract}
  #
  # property "any rlp-mutated tx binary either fails to decode to a transaction object or is recognized as different",
  #          [1000, :verbose, max_size: 100, constraint_tries: 100_000],
  #          %{contract: contract}

  defp verify(contract, tx) do
    assert get_field!(contract, tx, "txType", {:uint, 256}) == 1

    if length(tx.inputs) > 0,
      do:
        0..(length(tx.inputs) - 1)
        |> Enum.each(
          &assert get_field!(contract, tx, "input", {:bytes, 32}, &1) ==
                    tx.inputs
                    |> Enum.at(&1)
                    |> Utxo.Position.encode()
                    |> :binary.encode_unsigned()
                    |> Binary.pad_leading(32, 0)
        )

    get_field(contract, tx, "input", {:bytes, 32}, length(tx.inputs)) |> check_EVM_exception()
  end

  defp get_field!(contract, tx, name, return_type, index \\ nil) do
    {:ok, get_field} = get_field(contract, tx, name, return_type, index)
    get_field
  end

  defp get_field(contract, %{} = tx, name, return_type, index),
    do: get_field(contract, Transaction.raw_txbytes(tx), name, return_type, index)

  defp get_field(contract, encoded_tx, name, return_type, index) when is_binary(encoded_tx) do
    index_signature_part = if index, do: ",uint256", else: ""
    signature = name <> "(bytes" <> index_signature_part <> ")"
    index_args_part = if index, do: [index], else: []
    args = [encoded_tx] ++ index_args_part
    Eth.call_contract(contract, signature, args, [return_type])
  end

  defp check_EVM_exception({:error, error_body}),
    do: assert(error_body["message"] == "VM Exception while processing transaction: invalid opcode")
end
