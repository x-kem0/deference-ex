defmodule Deference.Impl do
  @moduledoc false

  @meta_key :__deference_lib_meta__
  @idx_key :__deference_lib_idx__
  @stack_key :__deference_lib_stack__

  def get_stack() do
    Process.get(@stack_key, [])
  end

  def push_stack() do
    idx = Process.get(@idx_key, 0)
    stack = Process.get(@stack_key, [])
    Process.put(@stack_key, [idx | stack])
    Process.put(@idx_key, idx + 1)
  end

  def pop_stack() do
    case Process.get(@stack_key, []) do
      [_idx] ->
        clear_stack()

      [idx | tail] ->
        erase_meta(idx)
        Process.put(@stack_key, tail)
    end
  end

  def get_meta(idx) do
    meta = Process.get(@meta_key, %{})
    Map.get(meta, idx, %{defer: [], errdefer: []})
  end

  def put_meta(idx, data) do
    stack_meta =
      Process.get(@meta_key, %{})
      |> Map.put(idx, data)

    Process.put(
      @meta_key,
      stack_meta
    )
  end

  def erase_meta(idx) do
    stack_meta =
      Process.get(@meta_key, %{})
      |> Map.drop([idx])

    Process.put(
      @meta_key,
      stack_meta
    )
  end

  def clear_stack() do
    Process.put(@stack_key, [])
    Process.put(@meta_key, %{})
    Process.put(@idx_key, 0)
  end

  def current_stack_idx do
    case get_stack() do
      [] ->
        raise "Attempted to get defer stack in empty scope; are you using with_defer/1 ?"

      [idx | _] ->
        idx
    end
  end

  def get_defers do
    idx = current_stack_idx()
    meta = get_meta(idx)
    meta.defer
  end

  def get_err_defers do
    idx = current_stack_idx()
    meta = get_meta(idx)
    meta.errdefer
  end

  def put_defer(deferred) do
    idx = current_stack_idx()
    meta = get_meta(idx)

    put_meta(
      idx,
      %{
        defer: [deferred | meta.defer],
        errdefer: meta.errdefer
      }
    )

    :ok
  end

  def put_err_defer(deferred) do
    idx = current_stack_idx()
    meta = get_meta(idx)

    put_meta(
      idx,
      %{
        defer: meta.defer,
        errdefer: [deferred | meta.errdefer]
      }
    )

    :ok
  end

  def run_err_defers(fwd) do
    dfs = get_err_defers()

    dfs =
      if fwd do
        dfs |> Enum.reverse()
      else
        dfs
      end

    for {df, file, line} <- dfs do
      try do
        df.()
      rescue
        _e ->
          :logger.warning("err_defer failed: #{file}:#{line}")
      end
    end
  end

  def run_defers(fwd) do
    dfs = get_defers()

    dfs =
      if fwd do
        dfs |> Enum.reverse()
      else
        dfs
      end

    for {df, file, line} <- dfs do
      try do
        df.()
      rescue
        _e ->
          :logger.warning("defer failed: #{file}:#{line}")
      end
    end
  end
end
