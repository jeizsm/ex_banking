defmodule ExBanking.User do
  use GenServer

  @spec init(:ok) :: {:ok, {pid, 0}}
  def init(:ok) do
    {:ok, balance} = ExBanking.User.Balance.start_link([])
    {:ok, {balance, 0}}
  end

  @spec inc(atom | pid | {atom, any} | {:via, atom, any}) ::
          {:ok, pid} | {:error, :too_many_requests_to_user}
  def inc(user) do
    GenServer.call(user, :inc)
  end

  @spec dec(atom | pid | {atom, any} | {:via, atom, any}) :: :ok
  def dec(user) do
    GenServer.call(user, :dec)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_call(:inc, _from, {balance, number_of_clients} = state) do
    if number_of_clients < 10 do
      {:reply, {:ok, balance}, {balance, number_of_clients + 1}}
    else
      {:reply, {:error, :too_many_requests_to_user}, state}
    end
  end

  def handle_call(:dec, _from, {balance, number_of_clients}) do
    if number_of_clients >= 0 do
      {:reply, :ok, {balance, number_of_clients - 1}}
    else
      raise("number of clients less than zero")
    end
  end
end
