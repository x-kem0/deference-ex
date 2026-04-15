defmodule DeferenceTest do
  use ExUnit.Case
  import Deference
  doctest Deference

  defmacro set_ets() do
    quote do
      defer do
        :ets.insert(var!(table), {:one, 1})
      end

      defer do
        :ets.insert(var!(table), {:two, 2})
      end

      defer do
        :ets.insert(var!(table), {:three, 3})
      end
    end
  end

  defmacro get_ets() do
    quote do
      a = :ets.lookup(var!(table), :one)
      b = :ets.lookup(var!(table), :two)
      c = :ets.lookup(var!(table), :three)
      {a, b, c}
    end
  end

  test "No error test" do
    table = :ets.new(:side_effect_test, [])

    result =
      with_defer do
        set_ets()

        case System.fetch_env("never_real_ever_ever_ever") do
          {:ok, _value} ->
            throw_deferred({:error, "is that on purpose?"})

          _ ->
            :ok
        end
      end

    assert result == :ok
    {a, b, c} = get_ets()
    assert a != [{:one, 1}]
    assert b != [{:two, 2}]
    assert c != [{:three, 3}]
  end

  test "Side effects and early return" do
    table = :ets.new(:side_effect_test, [])

    result =
      with_defer do
        set_ets()
        throw_deferred(:early_exit)
        :ok
      end

    assert result == :early_exit

    {a, b, c} = get_ets()
    assert a == [{:one, 1}]
    assert b == [{:two, 2}]
    assert c == [{:three, 3}]
  end
end
