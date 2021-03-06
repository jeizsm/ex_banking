defmodule ExBanking do
  use Application

  @moduledoc """
    Test task for Elixir developers. Candidate should write a simple banking OTP application in Elixir language.
    General acceptance criteria
      All code is in git repo (candidate can use his/her own github account).
      OTP application is a standard mix project.
      Application name is :ex_banking (main Elixir module is ExBanking).
      Application interface is just set of public functions of ExBanking module (no API endpoint, no REST / SOAP API, no TCP / UDP sockets, no any external network interface).
      Application should not use any database / disc storage. All needed data should be stored only in application memory.
      Candidate can use any Elixir or Erlang library he/she wants to (but app can be written in pure Elixir / Erlang / OTP).
      Solution will be tested using our auto-tests for this task. So, please follow specifications accurately.
      Public functions of ExBanking module described in this document is the only one thing tested by our auto-tests. If anything else needs to be called for normal application functioning then probably tests will fail.
      Code accuracy also matters. Readable, safe, refactorable code is a plus.

    Money amounts
      Money amount of any currency should not be negative.
      Application should provide 2 decimal precision of money amount for any currency.
      Amount of money incoming to the system should be equal to amount of money inside the system + amount of withdraws (money should not appear or disappear accidentally).
      User and currency type is any string. Case sensitive. New currencies / users can be added dynamically in runtime. In the application, there should be a special public function (described below) for creating users. Currencies should be created automatically (if needed).

    Performance
      In every single moment of time the system should handle 10 or less operations for every individual user (user is a string passed as the first argument to API functions). If there is any new operation for this user and he/she still has 10 operations in pending state - new operation for this user should immediately return too_many_requests_to_user error until number of requests for this user decreases < 10
      The system should be able to handle requests for different users in the same moment of time
      Requests for user A should not affect to performance of requests to user B (maybe except send function when both A and B users are involved in the request)
  """

  @impl true
  def start(_type, _args) do
    ExBanking.Supervisor.start_link(name: ExBanking.Supervisor)
  end

  @doc """
    Function creates new user in the system
    New user has zero balance of any currency
  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    with true <- String.valid?(user) do
      ExBanking.User.Registry.create(ExBanking.User.Registry, user)
    else
      _ -> {:error, :wrong_arguments}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @doc """
    Increases user???s balance in given currency by amount value
    Returns new_balance of the user in given format
  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    with {true, true} <- {String.valid?(user), String.valid?(currency)},
         {:ok, amount} <- convert_amount(amount),
         {:ok, user} <- ExBanking.User.Registry.get(ExBanking.User.Registry, user),
         {:ok, balance} <- ExBanking.User.inc(user),
         new_amount <- ExBanking.User.Balance.deposit(balance, amount, currency),
         :ok <- ExBanking.User.dec(user) do
      {:ok, new_amount}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, :wrong_arguments}
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
    Decreases user???s balance in given currency by amount value
    Returns new_balance of the user in given format
  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    with {true, true} <- {String.valid?(user), String.valid?(currency)},
         {:ok, amount} <- convert_amount(amount),
         {:ok, user} <- ExBanking.User.Registry.get(ExBanking.User.Registry, user),
         {:ok, balance} <- ExBanking.User.inc(user),
         {:ok, new_amount} <- ExBanking.User.Balance.withdraw(balance, amount, currency),
         :ok <- ExBanking.User.dec(user) do
      {:ok, new_amount}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, :wrong_arguments}
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
    Returns balance of the user in given format
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    with {true, true} <- {String.valid?(user), String.valid?(currency)},
         {:ok, user} <- ExBanking.User.Registry.get(ExBanking.User.Registry, user),
         {:ok, balance} <- ExBanking.User.inc(user),
         amount <- ExBanking.User.Balance.get_balance(balance, currency),
         :ok <- ExBanking.User.dec(user) do
      {:ok, amount}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, :wrong_arguments}
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @doc """
    Decreases from_user???s balance in given currency by amount value
    Increases to_user???s balance in given currency by amount value
    Returns balance of from_user and to_user in given format
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_binary(currency) and
             is_number(amount) do
    with {true, true, true} when from_user != to_user <-
           {String.valid?(from_user), String.valid?(currency), String.valid?(to_user)},
         {:ok, amount} <- convert_amount(amount),
         {:ok, from_user} <-
           (case ExBanking.User.Registry.get(ExBanking.User.Registry, from_user) do
              {:error, :user_does_not_exist} -> {:error, :sender_does_not_exist}
              response -> response
            end),
         {:ok, to_user} <- ExBanking.User.Registry.get(ExBanking.User.Registry, to_user),
         {:ok, from_balance} <- ExBanking.User.inc(from_user),
         {:ok, to_balance} <- ExBanking.User.inc(to_user),
         {:ok, from_user_balance} <-
           ExBanking.User.Balance.withdraw(from_balance, amount, currency),
         :ok <- ExBanking.User.dec(from_user),
         to_user_balance <- ExBanking.User.Balance.deposit(to_balance, amount, currency),
         :ok <- ExBanking.User.dec(to_user) do
      {:ok, from_user_balance, to_user_balance}
    else
      {:error, :user_does_not_exist} -> {:error, :receiver_does_not_exist}
      {:error, :sender_does_not_exist} -> {:error, :sender_does_not_exist}
      {:error, error} -> {:error, error}
      _ -> {:error, :wrong_arguments}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  @compile {:inline, convert_amount: 1}
  defp convert_amount(amount) when amount < 0, do: {:error, :wrong_arguments}
  defp convert_amount(amount) when is_integer(amount), do: {:ok, Decimal.new(amount)}
  defp convert_amount(amount) when is_float(amount), do: {:ok, Decimal.from_float(amount)}
end
