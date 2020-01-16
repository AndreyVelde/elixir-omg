# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Controller.Fee do
  @moduledoc """
  Operations related to fees.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.WatcherInfo.HttpRPC.Client

  def fees_all(conn, params) do
    with {:ok, _} <- expect(params, "currencies", list: &to_currency/1, optional: true),
         {:ok, _} <- expect(params, "tx_types", list: &to_tx_type/1, optional: true),
         child_chain_url <- Application.get_env(:omg_watcher, :child_chain_url),
         {:ok, fees} <- Client.get_fees(params, child_chain_url) do
      api_response(fees, conn, :fees_all)
    end
  end

  defp to_currency(currency_str) do
    expect(%{"currency" => currency_str}, "currency", :address)
  end

  defp to_tx_type(tx_type_str) do
    expect(%{"tx_type" => tx_type_str}, "tx_type", :non_neg_integer)
  end
end
