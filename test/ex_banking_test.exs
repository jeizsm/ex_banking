defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  test "create user" do
    assert ExBanking.create_user("user") == :ok
    assert ExBanking.create_user("USER") == :ok
  end

  test "create user that already exists" do
    ExBanking.create_user("user")
    assert ExBanking.create_user("user") == {:error, :user_already_exists}
    assert ExBanking.create_user("USER") == :ok
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

  test "user does not exist" do
    assert ExBanking.deposit("user", 100, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.withdraw("user", 100, "USD") == {:error, :user_does_not_exist}
    assert ExBanking.get_balance("user", "USD") == {:error, :user_does_not_exist}
    assert ExBanking.send("user", "user2", 100, "USD") == {:error, :sender_does_not_exist}
    ExBanking.create_user("user")
    assert ExBanking.send("user", "user2", 100, "USD") == {:error, :receiver_does_not_exist}
  end

  test "too many requests to user" do
    functions = [
      &ExBanking.deposit/3,
      &ExBanking.get_balance/2,
      &ExBanking.withdraw/3,
      &ExBanking.send/4
    ]

    args = [
      get_balance: ["user", 100],
      deposit: ["user", 100, "USD"],
      withdraw: ["user", 100, "USD"],
      send: ["user", "user2", 100, "USD"]
    ]

    errors = [
      {:ok, {:error, :too_many_requests_to_user}},
      {:ok, {:error, :too_many_requests_to_sender}},
      {:ok, {:error, :too_many_requests_to_receiver}}
    ]

    ExBanking.create_user("user")
    ExBanking.create_user("user2")

    1..100 |> Enum.map(fn _ -> Enum.random(functions) end)

    tasks =
      Task.async_stream(functions, fn function ->
        name = Function.info(function)[:name]
        apply(function, args[name])
      end)
      |> Enum.to_list()

    assert Enum.any?(tasks, fn elem -> Enum.any?(errors, fn error -> error == elem end) end) == true
  end

  test "not enough money" do
    ExBanking.create_user("user")
    ExBanking.create_user("user2")
    assert ExBanking.withdraw("user", 0.1, "USD") == {:error, :not_enough_money}
    ExBanking.deposit("user", 0.1, "USD")
    assert ExBanking.withdraw("user", 0.1, "usd") == {:error, :not_enough_money}
    assert ExBanking.send("user", "user2", 0.2, "USD") == {:error, :not_enough_money}
  end

  test "deposit money" do
    ExBanking.create_user("user")
    assert ExBanking.deposit("user", 0.1, "USD") == {:ok, 0.1}
    assert ExBanking.deposit("user", 0.2, "USD") == {:ok, 0.3}
    assert ExBanking.deposit("user", 0.2, "usd") == {:ok, 0.2}
  end

  test "get balance" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 0.1, "USD")
    assert ExBanking.get_balance("user", "USD") == {:ok, 0.1}
  end

  test "withdraw money" do
    ExBanking.create_user("user")
    ExBanking.deposit("user", 0.3, "USD")
    assert ExBanking.withdraw("user", 0.1, "USD") == {:ok, 0.2}
  end

  test "send money" do
    ExBanking.create_user("user")
    ExBanking.create_user("user2")
    ExBanking.deposit("user", 0.3, "USD")
    assert ExBanking.send("user", "user2", 0.1, "USD") == {:ok, 0.2, 0.1}
  end
end
