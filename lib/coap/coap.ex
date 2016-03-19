defmodule CoAP do
  use CoAP.Codes

  alias CoAP.{Message, Header}

  @type header :: Header.t

  @type msg :: Message.t

  @spec version :: integer
  def version do
    @version
  end

  @spec empty?(msg) :: boolean
  def empty?(%Message{header: header}) do
    empty?(header)
  end

  @spec empty?(header) :: boolean
  def empty?(header = %Header{}) do
    code_pair(header) == {0, 0}
  end

  @spec type(msg) :: atom
  def type(%Message{header: header}) do
    type(header)
  end

  @spec type(header) :: atom
  def type(%Header{type: type}) do
    @types[type]
  end

  @spec type(number :: integer) :: atom
  def type(number) when is_integer(number) do
    @types[number]
  end

  @spec type(name :: atom) :: integer
  def type(name) when is_atom(name) do
    @types_reverse[name]
  end

  @spec class(msg) :: atom
  def class(%Message{header: header}) do
    class(header)
  end

  @spec class(header) :: atom
  def class(%Header{code_class: code_class}) do
    @classes[code_class]
  end

  @spec method(msg) :: atom
  def method(%Message{header: header}) do
    method(header)
  end

  @spec method(header) :: atom
  def method(header = %Header{}) do
    @methods[code_pair(header)]
  end

  @spec code_string(msg) :: char_list
  def code_string(%Message{header: header}) do
    code_string(header)
  end

  @spec code_string(header) :: char_list
  def code_string(header = %Header{}) do
    :io.format "~B.~2..0B", Tuple.to_list(code_pair(header))
  end

  @spec response_code(value :: {integer, integer}) :: atom
  def response_code(value = {code_class, code_detail}) when is_integer(code_class) and is_integer(code_detail) do
    @responses[value]
  end

  @spec response_code(name :: atom) :: {integer, integer}
  def response_code(name) when is_atom(name) do
    @responses_reverse[name]
  end

  defp code_pair(header = %Header{}) do
    {header.code_class, header.code_detail}
  end

end