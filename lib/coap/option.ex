defmodule CoAP.Option do
  use CoAP.Codes

  defstruct number: 0, value: <<>>

  def to_name(%CoAP.Option{number: number}) do
    @options[number]
  end

  def to_number(name) do
    @options_reverse[name]
  end

  def from_name(name, value \\ <<>>) do
    %CoAP.Option{number: to_number(name), value: value}
  end

  def critical?(option) do
    flags(option).critical
  end

  def unsafe?(option) do
    flags(option).unsafe
  end

  def flags(option) do
    <<
      _ :: size(3),
      no_cache_key :: size(3),
      unsafe :: size(1),
      critical :: size(1)
    >> = <<option.number>>

    %{
      critical: critical != 0,
      elective: critical == 0,
      unsafe: unsafe != 0,
      safe_to_forward: unsafe == 0,
      no_cache_key: no_cache_key
    }
  end

end
