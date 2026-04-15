defmodule Deference do
  defmacro defer(do: func) do
    quote do
      var!(deference_lib_rollbacks) = [
        fn -> unquote(func) end | var!(deference_lib_rollbacks)
      ]
    end
  end

  defmacro throw_deferred(value \\ :error) do
    quote do
      throw({:deference_lib_rollback, unquote(value), var!(deference_lib_rollbacks)})
    end
  end

  defmacro p_with_defer(forward, expr) do
    quote do
      try do
        var!(deference_lib_rollbacks) = []
        unquote(expr)
      catch
        {:deference_lib_rollback, value, rollbacks} ->
          unquote(
            if forward do
              quote do
                for rb <- rollbacks |> Enum.reverse() do
                  rb.()
                end
              end
            else
              quote do
                for rb <- rollbacks do
                  rb.()
                end
              end
            end
          )

          quote do
            unquote(value)
          end
      end
    end
  end

  defmacro with_defer(do: expr) do
    quote do
      p_with_defer(false, unquote(expr))
    end
  end

  defmacro with_defer_fwd(do: expr) do
    quote do
      p_with_defer(true, unquote(expr))
    end
  end
end
