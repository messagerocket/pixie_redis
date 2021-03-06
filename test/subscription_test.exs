defmodule Pixie.Redis.SubscriptionTest do
  use ExUnit.Case
  alias Pixie.Redis.{Subscription, ConnectionPool, Client, Channel}
  use ConnectionPool

  setup do
    ConnectionPool.reset!
  end

  @client_key "pixie:test:subscriptions_by_client"
  @channel_key "pixie:test:subscriptions_by_channel"

  test "`create`" do
    Subscription.create("client_id", "channel_name")
    with_connection(fn (redis) ->
      assert Redis.sismember(redis, "#{@client_key}:client_id", "channel_name") == "1"
      assert Redis.sismember(redis, "#{@channel_key}:channel_name", "client_id") == "1"
    end)
  end

  test "`destroy`" do
    Subscription.create("client_id", "channel_name")
    with_connection(fn (redis) ->
      assert Redis.sismember(redis, "#{@client_key}:client_id", "channel_name") == "1"
      assert Redis.sismember(redis, "#{@channel_key}:channel_name", "client_id") == "1"
    end)
    Subscription.destroy("client_id", "channel_name")
    with_connection(fn (redis) ->
      assert Redis.sismember(redis, "#{@client_key}:client_id", "channel_name") == "0"
      assert Redis.sismember(redis, "#{@channel_key}:channel_name", "client_id") == "0"
    end)
  end

  test "`list`" do
    Subscription.create("client_id", "channel_name")
    assert Subscription.list == [{{"client_id", "channel_name"}, nil}]
  end

  test "`exist?` when the subscription exists" do
    Subscription.create("client_id", "channel_name")
    assert Subscription.exists?("client_id", "channel_name")
  end

  test "`exist?` when the subscription doesn't exist" do
    refute Subscription.exists?("client_id", "channel_name")
  end

  test "`clients_on`" do
    make_some_subs

    actual =
      "/channel/3"
      |> Subscription.clients_on
      |> Enum.into(MapSet.new)

    expected =
      1..10
      |> Enum.map(fn(i) -> "client_#{i}" end)
      |> Enum.into(MapSet.new)

    assert actual == expected
  end

  test "`channels_on`" do
    make_some_subs

    clients = MapSet.new([
      "/channel/1",
      "/channel/2",
      "/channel/3",
      "/channel/4",
      "/channel/5",
      "/channel/6",
      "/channel/7",
      "/channel/8",
      "/channel/9",
      "/channel/10"
    ])
    assert Subscription.channels_on("client_3") == clients
  end

  defp make_some_subs do
    1..10
    |> Enum.each(fn (i) ->
      client_id = "client_#{i}"
      1..10
      |> Enum.each(fn (j) ->
        channel = "/channel/#{j}"
        Channel.store(channel)
        {:ok, pid} = Agent.start_link(fn -> i end)
        Client.store(client_id, pid)
        Subscription.create(client_id, channel)
      end)
    end)
  end
end