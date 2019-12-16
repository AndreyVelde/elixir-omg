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

defmodule OMG.WatcherInfo.DB.EthEventTest do
  use ExUnit.Case, async: true

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.WatcherInfo.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  # TODO: To be replaced by a shared ExUnit.CaseTemplate.setup/0 once #1199 is merged.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DB.Repo)
  end

  test "insert deposits: creates deposit event and utxo" do
    expected_root_chain_txnhash = Crypto.hash(<<1::256>>)
    expected_log_index = 0
    expected_event_type = :deposit

    expected_blknum = 10_000
    expected_txindex = 0
    expected_oindex = 0
    expected_owner = <<1::160>>
    expected_currency = @eth
    expected_amount = 1

    root_chain_txhash_event =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txnhash, expected_log_index)

    expected_child_chain_utxohash =
      DB.EthEvent.generate_child_chain_utxohash(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txnhash,
                 log_index: expected_log_index,
                 blknum: expected_blknum,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    event = DB.EthEvent.get(root_chain_txhash_event)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txnhash,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type
           } = event

    # check ethevent side of relationship
    assert length(event.txoutputs) == 1

    assert [
             %DB.TxOutput{
               blknum: ^expected_blknum,
               txindex: ^expected_txindex,
               oindex: ^expected_oindex,
               owner: ^expected_owner,
               amount: ^expected_amount,
               currency: ^expected_currency,
               creating_txhash: nil,
               spending_txhash: nil,
               spending_tx_oindex: nil,
               proof: nil,
               child_chain_utxohash: ^expected_child_chain_utxohash
             }
             | _tail
           ] = event.txoutputs

    # check txoutput side of relationship
    txoutput = DB.TxOutput.get_by_position(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert %DB.TxOutput{
             blknum: ^expected_blknum,
             txindex: ^expected_txindex,
             oindex: ^expected_oindex,
             owner: ^expected_owner,
             amount: ^expected_amount,
             currency: ^expected_currency,
             creating_txhash: nil,
             spending_txhash: nil,
             spending_tx_oindex: nil,
             proof: nil,
             child_chain_utxohash: ^expected_child_chain_utxohash
           } = txoutput

    assert length(txoutput.ethevents) == 1

    assert [
             %DB.EthEvent{
               root_chain_txhash: ^expected_root_chain_txnhash,
               log_index: ^expected_log_index,
               event_type: ^expected_event_type
             }
             | _tail
           ] = txoutput.ethevents
  end

  test "insert deposits: creates deposits and retrieves them by hash" do
    alice = OMG.TestHelper.generate_entity()

    expected_event_type = :deposit
    expected_owner = alice.addr
    expected_currency = @eth
    expected_log_index = 0
    expected_amount = 1

    expected_root_chain_txhash_1 = Crypto.hash(<<2::256>>)

    expected_root_chain_txhash_event_1 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_1, expected_log_index)

    expected_blknum_1 = 20_000

    expected_root_chain_txhash_2 = Crypto.hash(<<3::256>>)

    expected_root_chain_txhash_event_2 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_2, expected_log_index)

    expected_blknum_2 = 30_000

    expected_root_chain_txhash_3 = Crypto.hash(<<4::256>>)

    expected_root_chain_txhash_event_3 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_3, expected_log_index)

    expected_blknum_3 = 40_000

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txhash_1,
                 log_index: expected_log_index,
                 blknum: expected_blknum_1,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_2,
                 log_index: expected_log_index,
                 blknum: expected_blknum_2,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_3,
                 log_index: expected_log_index,
                 blknum: expected_blknum_3,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_1,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_1
           } = DB.EthEvent.get(expected_root_chain_txhash_event_1)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_2,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_2
           } = DB.EthEvent.get(expected_root_chain_txhash_event_2)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_3,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_3
           } = DB.EthEvent.get(expected_root_chain_txhash_event_3)

    assert [^expected_root_chain_txhash_1, ^expected_root_chain_txhash_2, ^expected_root_chain_txhash_3] =
             DB.TxOutput.get_utxos(alice.addr)
             |> Enum.map(fn txoutput ->
               [head | _tail] = txoutput.ethevents
               head.root_chain_txhash
             end)
  end

  test "insert exits: creates exit event and marks utxo as spent" do
    expected_owner = <<1::160>>
    expected_log_index = 0
    expected_amount = 1
    expected_currency = @eth

    expected_blknum = 50_000
    expected_txindex = 0
    expected_oindex = 0

    expected_utxo_encoded_position = Position.encode(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    expected_deposit_root_chain_txhash = Crypto.hash(<<5::256>>)
    expected_exit_root_chain_txhash = Crypto.hash(<<6::256>>)

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_deposit_root_chain_txhash,
                 log_index: expected_log_index,
                 blknum: expected_blknum,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    assert length(DB.TxOutput.get_utxos(expected_owner)) == 1

    assert :ok =
             DB.EthEvent.insert_exits!([
               %{
                 call_data: %{utxo_pos: expected_utxo_encoded_position},
                 root_chain_txhash: expected_exit_root_chain_txhash,
                 log_index: expected_log_index
               }
             ])

    assert Enum.empty?(DB.TxOutput.get_utxos(expected_owner))
  end

  test "writes of deposits and exits are idempotent" do
    alice = OMG.TestHelper.generate_entity()

    # try to insert again existing deposit (from initial_blocks)
    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: Crypto.hash(<<1000::256>>),
                 log_index: 0,
                 owner: alice.addr,
                 currency: @eth,
                 amount: 333,
                 blknum: 1
               }
             ])

    exits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))}
      },
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))}
      }
    ]

    assert :ok = DB.EthEvent.insert_exits!(exits)
  end
end
