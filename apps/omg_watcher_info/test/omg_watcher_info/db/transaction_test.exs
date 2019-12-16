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

defmodule OMG.WatcherInfo.DB.TransactionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  # TODO: To be replaced by a shared ExUnit.CaseTemplate.setup/0 once #1199 is merged.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DB.Repo)
  end

  # TODO: To be replaced by ExMachina.insert/2 once #1199 is merged.
  defp insert(:block, params) do
    DB.Block
    |> struct(params)
    |> DB.Repo.insert!()
  end

  # TODO: To be replaced by ExMachina.insert/2 once #1199 is merged.
  defp insert(:transaction, params) do
    DB.Transaction
    |> struct(params)
    |> DB.Repo.insert!()
  end

  test "the associated block can be preloaded" do
    _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
    _ = insert(:transaction, txhash: <<1001>>, blknum: 1000, txindex: 1, txbytes: <<0>>)

    preloaded =
      1000
      |> DB.Transaction.get_by_position(1)
      |> DB.Repo.preload(:block)

    assert %DB.Transaction{
             blknum: 1000,
             txindex: 1,
             block: %DB.Block{blknum: 1000}
           } = preloaded
  end

  test "gets all transactions from the given block number" do
    # Block 1000
    _ = insert(:block, blknum: 1000, hash: <<1000>>, eth_height: 1, timestamp: 100)
    _ = insert(:transaction, txhash: <<1001>>, blknum: 1000, txindex: 1, txbytes: <<0>>)

    # Block 2000
    _ = insert(:block, blknum: 2000, hash: <<2000>>, eth_height: 2, timestamp: 200)
    tx_1 = insert(:transaction, txhash: <<2001>>, blknum: 2000, txindex: 1, txbytes: <<0>>)
    tx_2 = insert(:transaction, txhash: <<2002>>, blknum: 2000, txindex: 2, txbytes: <<0>>)

    transactions = DB.Transaction.get_by_blknum(2000)

    assert length(transactions) == 2
    assert Enum.any?(transactions, fn t -> t.txhash == tx_1.txhash end)
    assert Enum.any?(transactions, fn t -> t.txhash == tx_2.txhash end)
  end

  test "returns an empty list for when given an unknown block" do
    assert DB.Transaction.get_by_blknum(5000) == []
  end

  test "passing unsupported constraints takes no effect and print a warning" do
    assert capture_log([level: :warn], fn ->
             DB.Transaction.get_by_filters([blknum: 2000, nothing: "there's no such thing"], %Paginator{})
           end) =~ "Constraint on :nothing does not exist in schema and was dropped from the query"
  end
end
