:ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
:ok = OmiseGO.DB.multi_update([{:put, :last_fast_exit_block_height, 0}])
:ok = OmiseGO.DB.multi_update([{:put, :last_slow_exit_block_height, 0}])
:ok = OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])