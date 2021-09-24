defmodule ExBanking.User.Balance do
  use Agent

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end
end
