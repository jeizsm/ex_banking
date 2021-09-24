defmodule ExBanking.User.Balance do
  use Agent

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  def deposit(balance, amount, currency) do
    Agent.get_and_update(balance, fn state ->
      Map.get_and_update(state, currency, fn current_amount ->
        current_amount = (current_amount || Decimal.new(0))
        new_amount = Decimal.add(current_amount, amount)
        {Decimal.round(new_amount, 2) |> Decimal.to_float, new_amount}
      end)
     end)
  end
end
