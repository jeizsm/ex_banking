defmodule ExBanking.User.Registry do
  use GenServer

  @spec init(:ok) :: {:ok, %{}}
  def init(:ok) do
    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec create(atom | pid | {atom, any} | {:via, atom, any}, String.t) :: :ok | {:error, :user_already_exists}
  def create(user, username) do
    GenServer.call(user, {:create, username})
  end

  def handle_call({:create, username}, _from, state) do
    if Map.has_key?(state, username) do
      {:reply, {:error, :user_already_exists}, state}
    else
      {:ok, user} = ExBanking.User.start_link([])
      {:reply, :ok, Map.put(state, username, user)}
    end
  end
end
