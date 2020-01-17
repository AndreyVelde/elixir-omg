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

defmodule OMG.WatcherRPC.Web.Plugs.SupportedWatcherModes do
  @moduledoc """
  A plug that serves the endpoints in scope only when the running watcher's mode matches
  the plug's supported watcher modes.
  """
  alias OMG.WatcherRPC.Web.Controller

  @behaviour Plug
  @app :omg_watcher_rpc

  @spec init([atom()]) :: [atom()]
  def init(supported), do: supported

  @spec call(Plug.Conn.t(), [atom()]) :: Plug.Conn.t()
  def call(conn, supported) do
    case Application.get_env(@app, :api_mode) in supported do
      true -> conn
      false -> Controller.Fallback.call(conn, {:error, :operation_not_found})
    end
  end
end
