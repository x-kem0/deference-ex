defmodule DeferenceTest do
  use ExUnit.Case
  import Deference
  doctest Deference

  defp side_effect_ets_setup() do
    :ets.new(__MODULE__, [:named_table])
  end

  defp put_ets(key, value) do
    :ets.insert(__MODULE__, {key, value})
  end

  defp get_ets(key) do
    :ets.lookup(__MODULE__, key)
    |> case do
      [{^key, value}] -> value
      _ -> nil
    end
  end

  test "No defer test" do
    result =
      with_defer do
        :ok
      end

    assert result == :ok
  end

  test "Regular defer, no error" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:check, :ok)
        end

        :ok
      end

    assert result == :ok
    assert get_ets(:check) == :ok
  end

  test "Regular defer, no error, early return" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:check, :ok)
        end

        throw(:early)

        :ok
      end

    assert result == :early
    assert get_ets(:check) == :ok
  end

  test "Regular defer, error" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:check, :ok)
        end

        throw_err()

        :ok
      end

    assert result == :error
    assert get_ets(:check) == :ok
  end

  test "Regular defer, exception + exception in deferred function" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:check, :ok)
        end

        defer do
          raise "Abort"
        end

        raise "Abort"

        :ok
      rescue
        _ ->
          :exception
      end

    assert result == :exception
    assert get_ets(:check) == :ok
  end

  test "Err defer, no error" do
    side_effect_ets_setup()

    put_ets(:check, :ok)

    result =
      with_defer do
        err_defer do
          put_ets(:check, :not_ok)
        end

        :ok
      end

    assert result == :ok
    assert get_ets(:check) == :ok
  end

  test "Err defer, no error, early return" do
    side_effect_ets_setup()

    put_ets(:check, :ok)

    result =
      with_defer do
        err_defer do
          put_ets(:check, :not_ok)
        end

        throw(:early)

        :ok
      end

    assert result == :early
    assert get_ets(:check) == :ok
  end

  test "Err defer, error" do
    side_effect_ets_setup()

    result =
      with_defer do
        err_defer do
          put_ets(:check, :ok)
        end

        throw_err()

        :ok
      end

    assert result == :error
    assert get_ets(:check) == :ok
  end

  test "Err defer, exception" do
    side_effect_ets_setup()

    result =
      with_defer do
        err_defer do
          put_ets(:check, :ok)
        end

        raise "Abort"

        :ok
      rescue
        _ -> :exception
      end

    assert result == :exception
    assert get_ets(:check) == :ok
  end

  test "Err defer, exception + exception in deferred function" do
    side_effect_ets_setup()

    result =
      with_defer do
        err_defer do
          put_ets(:check, :ok)
        end

        err_defer do
          raise "Abort"
        end

        raise "Abort"

        :ok
      rescue
        _ -> :exception
      end

    assert result == :exception
    assert get_ets(:check) == :ok
  end

  test "Nested deferrals" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:d1, :ok)
        end

        err_defer do
          put_ets(:d2, :ok)
        end

        result_nested =
          with_defer do
            defer do
              put_ets(:d3, :ok)
            end

            err_defer do
              put_ets(:d4, :ok)
            end

            throw_err(:ok)
          end

        assert result_nested == :ok
        assert get_ets(:d1) != :ok
        assert get_ets(:d2) != :ok
        assert get_ets(:d3) == :ok
        assert get_ets(:d4) == :ok

        throw_err(:ok)
      end

    assert result == :ok
    assert get_ets(:d1) == :ok
    assert get_ets(:d2) == :ok
  end

  test "Nested deferrals, exception" do
    side_effect_ets_setup()

    result =
      with_defer do
        defer do
          put_ets(:d1, :ok)
        end

        err_defer do
          put_ets(:d2, :ok)
        end

        with_defer do
          defer do
            put_ets(:d3, :ok)
          end

          err_defer do
            put_ets(:d4, :ok)
          end

          raise "Abort"
        end
      rescue
        _ -> :exception
      end

    assert result == :exception
    assert get_ets(:d1) == :ok
    assert get_ets(:d2) == :ok
    assert get_ets(:d3) == :ok
    assert get_ets(:d4) == :ok
  end

  test "Procedurally generated deferrals (out of scope)" do
    side_effect_ets_setup()
    put_ets(:value, 0)

    with_defer do
      for _ <- 0..999 do
        defer do
          put_ets(:value, get_ets(:value) + 1)
        end
      end
    end

    assert get_ets(:value) == 1000
  end

  test "Regular deferral direction" do
    side_effect_ets_setup()
    put_ets(:value, 0)

    # verify normal
    with_defer do
      for i <- 0..999 do
        defer do
          v = get_ets(:value)
          put_ets("#{i}", v)
          put_ets(:value, v + 1)
        end
      end
    end

    # verify fwd
    put_ets(:value, 0)

    for i <- 0..999 do
      assert get_ets("#{i}") == 999 - i
    end

    with_defer fwd: true do
      for i <- 0..999 do
        defer do
          v = get_ets(:value)
          put_ets("#{i}", v)
          put_ets(:value, v + 1)
        end
      end
    end

    for i <- 0..999 do
      assert get_ets("#{i}") == i
    end
  end

  test "Error deferral direction" do
    side_effect_ets_setup()
    put_ets(:value, 0)

    # verify normal
    with_defer do
      for i <- 0..999 do
        err_defer do
          v = get_ets(:value)
          put_ets("#{i}", v)
          put_ets(:value, v + 1)
        end
      end

      throw_err(:ok)
    end

    # verify fwd
    put_ets(:value, 0)

    for i <- 0..999 do
      assert get_ets("#{i}") == 999 - i
    end

    with_defer fwd: true do
      for i <- 0..999 do
        err_defer do
          v = get_ets(:value)
          put_ets("#{i}", v)
          put_ets(:value, v + 1)
        end
      end

      throw_err(:ok)
    end

    for i <- 0..999 do
      assert get_ets("#{i}") == i
    end
  end

  test "Safe flag" do
    side_effect_ets_setup()

    result =
      with_defer safe: true do
        defer do
          put_ets(:check, :ok)
        end

        raise "Abort"
      end

    assert get_ets(:check) == :ok
    assert result == {:error, :exception}
  end

  test "Runtime exception for invalid use outside of with_defer" do
    try do
      defer do
        :logger.error("this is not supposed to happen")
      end
    rescue
      _ -> :ok
    end
  end

  test "Safe/rescue in same with_defer block" do
    assert_raise CompileError,
                 ~r/with_defer cannot take both a safe option and a rescue clause/,
                 fn ->
                   ast =
                     quote do
                       with_defer safe: true do
                         :ok
                       rescue
                         _ -> :ok
                       end
                     end

                   Code.eval_quoted(ast, [], __ENV__)
                 end
  end

  test "No do clause" do
    assert_raise CompileError,
                 ~r/with_defer must have a do clause/,
                 fn ->
                   ast =
                     quote do
                       with_defer([])
                     end

                   Code.eval_quoted(ast, [], __ENV__)
                 end
  end
end
