defmodule ExBanking.User.Registry do
  use GenServer

  @spec init(:ok) :: {:ok, %{}}
  def init(:ok) do
    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec create(user :: atom | pid | {atom, any} | {:via, atom, any}, username :: String.t()) ::
          :ok | {:error, :user_already_exists}
  def create(user, username) do
    GenServer.call(user, {:create, username})
  end

  @spec get(user :: atom | pid | {atom, any} | {:via, atom, any}, username :: String.t()) ::
          {:ok, pid} | {:error, :user_does_not_exist}
  def get(user, username) do
    with {:ok, user} <- GenServer.call(user, {:get, username}) do
      {:ok, user}
    else
      :error -> {:error, :user_does_not_exist}
    end
  end

  def handle_call({:create, username}, _from, state) do
    if Map.has_key?(state, username) do
      {:reply, {:error, :user_already_exists}, state}
    else
      {:ok, user} = ExBanking.User.start_link([])
      {:reply, :ok, Map.put_new(state, username, user)}
    end
  end

  def handle_call({:get, username}, _from, state) do
    {:reply, Map.fetch(state, username), state}
  end
end
