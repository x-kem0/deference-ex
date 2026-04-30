# Deference

[![Hex.pm](https://img.shields.io/hexpm/v/deference.svg)](https://hex.pm/packages/deference) 
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/deference)

A function deferring library inspired by [zig](https://zig.guide/language-basics/defer/)!

The main purpose is chaining operations which could fail for any number of reasons, while
also requiring cleanup operations to be performed. The most important bits are `with_defer/1`, `defer/1`, `err_defer/1`, and `throw_err/1`.

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

Deferred operations are collected and called in the reverse order they are specified in, and they come in two flavors: Error defers and standard defers.
Error defers are only called if `throw_err/1` is called or an exception occurs within the `with_defer` block. Standard defers are *always* called, even when the `with_defer` block exits normally.
In the case above, if the post failed to edit, then first it would call `API.Post.delete(post_id)`, then `API.User.delete("really_cool_username")`.

If `throw_err/1` is not called, then the block returns as normal, e.g:
```ex
with_defer do
  defer do
    :logger.error("this shouldn't happen!")
  end

  if 1 == 2 do
    throw_err()
  else
    :ok
  end
end
```
This will always resolve as `:ok` with no side effects. 

`throw_err/1` also allows you an early return path. Whatever term is provided will be the return for the whole block, defaulting to `:error`.
```ex
with_defer do
  # some stuff

  throw_err({:error, :hello})

  # some other stuff

  :ok
end
```
Will always evaluate as `{:error, :hello}` stopping execution at the throw

A regular `throw/1` will return early as well, but without executing `err_defer`'d statements.

Some options are provided for convenience:
- a `rescue` clause can be provided directly in `with_defer`:
```ex
with_defer do
  raise "Abort"
rescue
  _ -> :saved
end

```

- `fwd` will call deferred functions in the order they were specified:
  ```ex
  with_defer fwd: true do
    defer do
      :logger.debug("1")
    end
    defer do
      :logger.debug("2")
    end
    defer do
      :logger.debug("3")
    end
  end
  ```
  will result in 1, 2, 3 being logged.

- `safe` will wrap the block in a try/call block, killing any exceptions:
  ```ex
  with_defer safe: true do
    raise "Abort"
  end
  ```
  will return `{:error, :exception}`
  
  I don't recommend using this, but it's there! Instead, consider providing a rescue clause.