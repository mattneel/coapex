defmodule CoAP.Header do
  use CoAP.Codes

  defstruct version: @version, type: 0, code_class: 0, code_detail: 0, message_id: 0, token: <<>>

  def empty?(header) do
    code_pair(header) == {0, 0}
  end

  def type(%CoAP.Header{type: type}) do
    @types[type]
  end

  def class(%CoAP.Header{code_class: code_class}) do
    @classes[code_class]
  end

  def method(header) do
    @methods[code_pair(header)]
  end

  def code(header) do
    :io.format "~B.~2..0B", Tuple.to_list(code_pair(header))
  end

  defp code_pair(%CoAP.Header{code_class: code_class, code_detail: code_detail}) do
    {code_class, code_detail}
  end

end
