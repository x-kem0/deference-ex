# Deference

[![Hex.pm](https://img.shields.io/hexpm/v/deference.svg)](https://hex.pm/packages/deference) 
<!-- [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/deference) -->

A function deferring library inspired by [zig](https://zig.guide/language-basics/defer/)!

The main purpose is chaining multiple API or operations which could fail for any number of reasons, while
also requiring cleanup operations to be performed. The most important bits are `with_defer/1`, `defer/1`, and `throw_deferred/1`.

Interface is *not* stable, but here's how to do it:

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

Deferred operations are collected and called in the reverse order they are called in.
In the case above, if the post failed to edit, then first it would call `API.Post.delete(post_id)`, then `API.User.delete("really_cool_username")`.
In case it's needed, `with_defer_fwd/1` allows you to call deferred functions in the order specified.

If `throw_deferred/1` is not called, then the block returns as normal, e.g:
```ex
with_defer do
  defer do
    :logger.error("this shouldn't happen!")
  end

  if 1 == 2 do
    throw_deferred()
  else
    :ok
  end
end
```
This will always resolve as `:ok` with no side effects. 

`throw_deferred/1` also allows you an early return path. Whatever term is provided will be the return for the whole block, defaulting to `:error`.
```ex
with_defer do
  # some stuff

  throw_deferred({:error, :hello})

  # some other stuff

  :ok
end
```
Will always evaluate as `{:error, :hello}` stopping execution at the throw