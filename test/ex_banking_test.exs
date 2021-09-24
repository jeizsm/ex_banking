defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  setup %{line: line} do
    {:ok, username: "user#{line}", username2: "user#{line + 1}"}
  end

  test "create user", %{username: username} do
    assert ExBanking.create_user(username) == :ok
    assert ExBanking.create_user(String.upcase(username)) == :ok
  end

  test "create user that already exists", %{username: username} do
    ExBanking.create_user(username)
    assert ExBanking.create_user(username) == {:error, :user_already_exists}
  end

  test "wrong arguments" do
    assert ExBanking.create_user(1) == {:error, :wrong_arguments}
    assert ExBanking.create_user(<<239, 191, 19>>) == {:error, :wrong_arguments}

    assert ExBanking.deposit("user", "100", "USD") == {:error, :wrong_arguments}
    assert ExBanking.deposit("user", 100, <<239, 191, 19>>) == {:error, :wrong_arguments}
    assert ExBanking.deposit(<<239, 191, 19>>, 100, "USD") == {:error, :wrong_arguments}

    assert ExBanking.withdraw("user", "100", "USD") == {:error, :wrong_arguments}
    assert ExBanking.withdraw("user", 100, <<239, 191, 19>>) == {:error, :wrong_arguments}
    assert ExBanking.withdraw(<<239, 191, 19>>, 100, "USD") == {:error, :wrong_arguments}

    assert ExBanking.get_balance("user", <<239, 191, 19>>) == {:error, :wrong_arguments}
    assert ExBanking.get_balance(<<239, 191, 19>>, "USD") == {:error, :wrong_arguments}

    assert ExBanking.send("user", <<239, 191, 19>>, 100, "USD") == {:error, :wrong_arguments}
    assert ExBanking.send(<<239, 191, 19>>, "user2", 100, "USD") == {:error, :wrong_arguments}
    assert ExBanking.send("user", "user2", 100, <<239, 191, 19>>) == {:error, :wrong_arguments}
    assert ExBanking.send("user", "user2", "100", "USD") == {:error, :wrong_arguments}
    assert ExBanking.send("user", "user", 100, "USD") == {:error, :wrong_arguments}
  end

  test "user does not exist", %{username: username, username2: username2} do
    assert ExBanking.deposit(username, 100, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.withdraw(username, 100, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.get_balance(username, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.send(username, username2, 100, "USD") == {:error, :sender_does_not_exist}
    ExBanking.create_user(username)
    assert ExBanking.send(username, username2, 100, "USD") == {:error, :receiver_does_not_exist}
  end

  test "too many requests to user", %{username: username, username2: username2} do
    functions = [
      &ExBanking.deposit/3,
      &ExBanking.get_balance/2,
      &ExBanking.withdraw/3,
      &ExBanking.send/4
    ]

    args = [
      get_balance: [username, "USD"],
      deposit: [username, 100, "USD"],
      withdraw: [username, 100, "USD"],
      send: [username, username2, 100, "USD"]
    ]

    errors = [
      {:ok, {:error, :too_many_requests_to_user}},
      {:ok, {:error, :too_many_requests_to_sender}},
      {:ok, {:error, :too_many_requests_to_receiver}}
    ]

    ExBanking.create_user(username)
    ExBanking.create_user(username2)

    prepared_functions = 1..100 |> Enum.map(fn _ -> Enum.random(functions) end)

    tasks =
      Task.async_stream(prepared_functions, fn function ->
        name = Function.info(function)[:name]
        apply(function, args[name])
      end)
      |> Enum.to_list()

    assert Enum.any?(tasks, fn elem -> Enum.any?(errors, fn error -> error == elem end) end) ==
             true
  end

  test "not enough money", %{username: username, username2: username2} do
    ExBanking.create_user(username)
    ExBanking.create_user(username2)
    assert ExBanking.withdraw(username, 0.1, "USD") == {:error, :not_enough_money}
    ExBanking.deposit(username, 0.1, "USD")
    assert ExBanking.withdraw(username, 0.1, "usd") == {:error, :not_enough_money}
    assert ExBanking.send(username, username2, 0.2, "USD") == {:error, :not_enough_money}
  end

  test "deposit money", %{username: username} do
    ExBanking.create_user(username)
    assert ExBanking.deposit(username, 0.1, "USD") == {:ok, 0.1}
    assert ExBanking.deposit(username, 0.2, "USD") == {:ok, 0.3}
    assert ExBanking.deposit(username, 0.2, "usd") == {:ok, 0.2}
  end

  test "get balance", %{username: username} do
    ExBanking.create_user(username)
    ExBanking.deposit(username, 0.1, "USD")
    assert ExBanking.get_balance(username, "USD") == {:ok, 0.1}
  end

  test "withdraw money", %{username: username} do
    ExBanking.create_user(username)
    ExBanking.deposit(username, 0.3, "USD")
    assert ExBanking.withdraw(username, 0.1, "USD") == {:ok, 0.2}
  end

  test "send money", %{username: username, username2: username2} do
    ExBanking.create_user(username)
    ExBanking.create_user(username2)
    ExBanking.deposit(username, 0.3, "USD")
    assert ExBanking.send(username, username2, 0.1, "USD") == {:ok, 0.2, 0.1}
  end
end
