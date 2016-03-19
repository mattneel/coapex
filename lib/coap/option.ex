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

end
