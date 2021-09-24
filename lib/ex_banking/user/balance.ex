defmodule ExBanking.User.Balance do
  use Agent

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  @spec deposit(atom | pid | {atom, any} | {:via, atom, any}, amount :: Decimal.t(), currency :: String.t()) :: number
  def deposit(balance, amount, currency) do
    Agent.get_and_update(balance, fn state ->
      Map.get_and_update(state, currency, fn current_amount ->
        current_amount = (current_amount || Decimal.new(0))
        new_amount = Decimal.add(current_amount, amount)
        {Decimal.round(new_amount, 2) |> Decimal.to_float, new_amount}
      end)
     end)
  end

  @spec withdraw(atom | pid | {atom, any} | {:via, atom, any}, amount :: Decimal.t(), currency :: String.t()) :: {:ok, number} | {:error, :not_enough_money}
  def withdraw(balance, amount, currency) do
    Agent.get_and_update(balance, fn state ->
      Map.get_and_update(state, currency, fn current_amount ->
        with current_amount when current_amount != nil <- current_amount,
          new_amount <- Decimal.sub(current_amount, amount),
          :gt <- Decimal.compare(new_amount, 0) do
            {{:ok, Decimal.round(new_amount, 2) |> Decimal.to_float}, new_amount}
          else
            _ -> {{:error, :not_enough_money}, current_amount}
          end
      end)
     end)
  end

  @spec get_balance(atom | pid | {atom, any} | {:via, atom, any}, currency :: String.t()) :: number
  def get_balance(balance, currency) do
    Agent.get(balance, &Map.get(&1, currency, Decimal.new(0)) |> Decimal.round(2) |> Decimal.to_float)
  end
end
