defmodule ExBanking.User do
  use GenServer

  @spec init(:ok) :: {:ok, {pid, 0}}
  def init(:ok) do
    {:ok, balance} = ExBanking.User.Balance.start_link([])
    {:ok, {balance, 0}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
end
