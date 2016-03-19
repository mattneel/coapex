defmodule CoAP do
  use CoAP.Codes

  alias CoAP.{Message, Header}

  @type header :: Header.t

  @type msg :: Message.t

  @type code_pair :: {integer, integer}

  @type name :: atom

  @type value :: integer

  @spec version :: value
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

  @spec type(msg) :: name
  def type(%Message{header: header}) do
    type(header)
  end

  @spec type(header) :: name
  def type(%Header{type: type}) do
    @types[type]
  end

  @spec type(value) :: name
  def type(value) when is_integer(value) do
    @types[value]
  end

  @spec type(name) :: value
  def type(name) when is_atom(name) do
    @types_reverse[name]
  end

  @spec class(msg) :: name
  def class(%Message{header: header}) do
    class(header)
  end

  @spec class(header) :: name
  def class(%Header{code_class: code_class}) do
    @classes[code_class]
  end

  @spec method(msg) :: name
  def method(%Message{header: header}) do
    method(header)
  end

  @spec method(header) :: name
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

  @spec response_code(code_pair) :: name
  def response_code(code_pair = {_code_class, _code_detail}) do
    @responses[code_pair]
  end

  @spec response_code(name) :: code_pair
  def response_code(name) when is_atom(name) do
    @responses_reverse[name]
  end

  defp code_pair(header = %Header{}) do
    {header.code_class, header.code_detail}
  end

end