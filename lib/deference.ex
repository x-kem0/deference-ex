defmodule Deference do
  import Deference.Impl

  @moduledoc """
  A function deferring library inspired by [zig](https://zig.guide/language-basics/defer/)!

  ```ex
  import Deference

  def example() do
    with_defer do

      {:ok, user_id} =
        API.User.create("really_cool_username", "really_cool_password")

      err_defer do
        API.User.delete("really_cool_username")
      end

      post_id =
        API.Post.create("really_cool_username", "hello")
        |> case do
          {:ok, post_id} -> post_id
          {:error, _reason} ->
            # can't post, no reason to keep the user around
            throw_err({:error, :failed_to_post})
        end

      err_defer do
        API.Post.delete(post_id)
      end

      API.Post.edit(post_id, "hello\nedit: wow i didn't expect this to blow up")
        |> case do
        {:ok, post_id} -> :ok
        {:error, _reason} ->
          # failed to edit post, bail!
          throw_err({:error, :failed_to_edit_post})
      end

    end
  end
  ```

  See the [Github page](https://github.com/x-kem0/deference-ex) for more examples

  """

  @error_key :__deference_lib_error__

  @doc """
  Stop function execution and run all deferred functions, returns the provided value or `:error` by default

  This function must be within a `with_defer/1` block.
  """
  defmacro throw_err(value \\ :error) do
    quote do
      throw({unquote(@error_key), unquote(value)})
    end
  end

  @doc """
  Start a new deferral block

  `rescue` may also be used for exception handling:
  ```ex
  with_defer do
    ...
  rescue
    _ -> :ok
  end
  ```
  """
  defmacro with_defer(opts, clauses) do
    fwd = Keyword.get(opts, :fwd, false)
    safe = Keyword.get(opts, :safe, false)

    expr = Keyword.get(clauses, :do)
    resc = Keyword.get(clauses, :rescue)

    if expr == nil do
      raise CompileError,
        description: "with_defer must have a do clause",
        file: __CALLER__.file,
        line: __CALLER__.line
    end

    if safe and resc != nil do
      raise CompileError,
        description: "with_defer cannot take both a safe option and a rescue clause",
        file: __CALLER__.file,
        line: __CALLER__.line
    end

    ast =
      quote do
        push_stack()

        try do
          unquote(expr)
        rescue
          e ->
            run_err_defers(unquote(fwd))
            reraise e, __STACKTRACE__
        catch
          {unquote(@error_key), value} ->
            run_err_defers(unquote(fwd))
            value

          v ->
            v
        after
          run_defers(unquote(fwd))
          pop_stack()
        end
      end

    cond do
      resc != nil ->
        quote do
          try do
            unquote(ast)
          rescue
            unquote(resc)
          end
        end

      safe ->
        quote do
          try do
            unquote(ast)
          rescue
            _ -> {:error, :exception}
          end
        end

      true ->
        ast
    end
  end

  defmacro with_defer(clauses) do
    quote do
      with_defer([], unquote(clauses))
    end
  end

  @doc """
  Defer an expression to run after any exiting `with_defer/1` under *any* condition, error or not.
  """
  defmacro defer(do: expr) do
    %{file: file, line: line} = __CALLER__

    quote do
      put_defer({fn -> unquote(expr) end, unquote(file), unquote(line)})
    end
  end

  @doc """
  Defer an expression to run after any exiting `with_defer/1` by either an exception or via `throw_err/1`
  """
  defmacro err_defer(do: expr) do
    %{file: file, line: line} = __CALLER__

    quote do
      put_err_defer({fn -> unquote(expr) end, unquote(file), unquote(line)})
    end
  end
end
