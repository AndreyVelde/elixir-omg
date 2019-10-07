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

defmodule OMG.Output.NFTMoreVPToken do
  @moduledoc """
  Representation of the payment transaction output of a fungible token `currency`
  """
  alias OMG.Crypto
  defstruct [:owner, :token, :token_ids]

  @type t :: %__MODULE__{
          owner: Crypto.address_t(),
          token: Crypto.address_t(),
          # FIXME: more specific
          token_ids: list(binary())
        }

  def from_db_value(%{owner: owner, token: token, token_ids: token_ids})
      when is_binary(owner) and is_binary(token) and is_list(token_ids) do
    %__MODULE__{owner: owner, token: token, token_ids: token_ids}
  end

  def reconstruct([owner, token, token_ids]) do
    with {:ok, token} <- parse_address(token),
         {:ok, owner} <- parse_address(owner),
         {:ok, token_ids} <- parse_token_ids(token_ids),
         do: %__MODULE__{owner: owner, token: token, token_ids: token_ids}
  end

  # FIXME: dry? same thing is in the Fungible case
  # necessary, because RLP handles empty string equally to integer 0
  @spec parse_address(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp parse_address(binary)
  defp parse_address(""), do: {:ok, <<0::160>>}
  defp parse_address(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp parse_address(_), do: {:error, :malformed_address}

  defp parse_token_ids(token_ids), do: token_ids |> Enum.reverse() |> Enum.reduce_while({:ok, []}, &parse_token_id/2)

  defp parse_token_id(token_id, {:ok, ids_so_far}) do
    case token_id do
      # FIXME: just something to start - a single byte
      <<_::size(1)-unit(8)>> -> {:cont, {:ok, [token_id | ids_so_far]}}
      _ -> {:halt, {:error, :malformed_token_id}}
    end
  end
end

defimpl OMG.Output.Protocol, for: OMG.Output.NFTMoreVPToken do
  alias OMG.Output.NFTMoreVPToken
  alias OMG.Utxo

  require Utxo

  # TODO: dry wrt. Application.fetch_env!(:omg, :output_types_modules)? Use `bimap` perhaps?
  @output_type_marker <<2>>

  @doc """
  For payment outputs, a binary witness is assumed to be a signature equal to the payment's output owner
  """
  # FIXME: dry? same thing is in the Fungible case
  def can_spend?(%NFTMoreVPToken{owner: owner}, witness, _raw_tx) when is_binary(witness) do
    owner == witness
  end

  # FIXME: dry? same thing is in the Fungible case
  def input_pointer(%NFTMoreVPToken{}, blknum, tx_index, oindex, _, _),
    do: Utxo.position(blknum, tx_index, oindex)

  def to_db_value(%NFTMoreVPToken{owner: owner, token: token, token_ids: token_ids})
      when is_binary(owner) and is_binary(token) and is_list(token_ids) do
    %{owner: owner, token: token, token_ids: token_ids, type: @output_type_marker}
  end

  def get_data_for_rlp(%NFTMoreVPToken{owner: owner, token: token, token_ids: token_ids}),
    do: [@output_type_marker, owner, token, token_ids]
end
