defmodule CrexTest do
  use ExUnit.Case
  doctest Crex

  test "greets the world" do
    assert Crex.hello() == :world
  end
end
