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

defmodule OMG.EthereumEventListener.Preprocessor do
  @moduledoc """
  Handles various business-logic specific processing of ethereum events
  """

  alias OMG.Utxo

  @doc """
  Applies the preprocessing procedure to the event received from `OMG.Eth`
  """
  @spec apply(%{required(:event_signature) => binary(), optional(any()) => any()}) :: map()
  def apply(raw_event) do
    raw_event
    |> preprocess_signature()
    |> preprocess_utxo_pos()
  end

  defp preprocess_signature(%{event_signature: "InFlightExitInput" <> _} = raw_event),
    do: expand_omg_data_with(raw_event, :piggyback_type, :input)

  defp preprocess_signature(%{event_signature: "InFlightExitOutput" <> _} = raw_event),
    do: expand_omg_data_with(raw_event, :piggyback_type, :output)

  defp preprocess_signature(%{event_signature: signature} = other_event) when is_binary(signature), do: other_event

  defp preprocess_utxo_pos(raw_event) do
    possible_utxo_pos_paths = [
      [:challenge_position],
      [:competitor_position],
      [:call_data, :utxo_pos],
      [:call_data, :input_utxos_pos]
    ]

    Enum.reduce(possible_utxo_pos_paths, raw_event, &preprocess_utxo_pos_path/2)
  end

  defp preprocess_utxo_pos_path(path, raw_event) do
    raw_event
    |> get_in(path)
    |> case do
      nil ->
        raw_event

      encoded_list when is_list(encoded_list) ->
        put_in(raw_event, path, Enum.map(encoded_list, &Utxo.Position.decode!/1))

      encoded ->
        put_in(raw_event, path, Utxo.Position.decode!(encoded))
    end
  end

  # expands (or creates if missing) the special field in the event (`:omg_data`) which holds the specific results of
  # preprocessing in additional fields
  defp expand_omg_data_with(event, key, value),
    do: Map.update(event, :omg_data, %{key => value}, &Map.put(&1, key, value))
end
