defmodule Deference do
  @moduledoc """
  A function deferring library inspired by [zig](https://zig.guide/language-basics/defer/)!

  ```ex
  import Deference

  def example() do
    with_defer do

      {:ok, user_id} =
        API.User.create("really_cool_username", "really_cool_password")

      defer do
        API.User.delete("really_cool_username")
      end

      post_id =
        API.Post.create("really_cool_username", "hello")
        |> case do
          {:ok, post_id} -> post_id
          {:error, _reason} ->
            # can't post, no reason to keep the user around
            throw_deferred({:error, :failed_to_post})
        end

      defer do
        API.Post.delete(post_id)
      end

      API.Post.edit(post_id, "hello\nedit: wow i didn't expect this to blow up")
        |> case do
        {:ok, post_id} -> :ok
        {:error, _reason} ->
          # failed to edit post, bail!
          throw_deferred({:error, :failed_to_edit_post})
      end

    end
  end
  ```

  See the [Github page](https://github.com/x-kem0/deference-ex) for more examples

  """

  @doc """
  Defer functions for use upon `throw_deferred/1`

  This function must be within a `with_defer/1` block.
  """
  defmacro defer(do: func) do
    quote do
      var!(deference_lib_rollbacks) = [
        fn -> unquote(func) end | var!(deference_lib_rollbacks)
      ]
    end
  end

  @doc """
  Stop function execution and run all deferred functions, returns the provided value or `:error` by default

  This function must be within a `with_defer/1` block.
  """
  defmacro throw_deferred(value \\ :error) do
    quote do
      throw({:deference_lib_rollback, unquote(value), var!(deference_lib_rollbacks)})
    end
  end

  @doc false
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

  @doc """
  Starts a deferred function block.
  """
  defmacro with_defer(do: expr) do
    quote do
      p_with_defer(false, unquote(expr))
    end
  end

  @doc """
  Reverse execution order of `with_defer/1`
  """
  defmacro with_defer_fwd(do: expr) do
    quote do
      p_with_defer(true, unquote(expr))
    end
  end
end
