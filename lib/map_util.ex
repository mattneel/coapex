defmodule MapUtil do

  def invert(map) do
    Map.new(map, fn {k, v} -> {v, k} end)
  end

end