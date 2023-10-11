defmodule MonitorTest do
  use ExUnit.Case
  doctest Monitor

  test "greets the world" do
    assert Monitor.hello() == :world
  end
end
