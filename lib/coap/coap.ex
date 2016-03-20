defmodule CoAP do
  use CoAP.Codes

  alias CoAP.{Message, Header, Option}

  @type header :: Header.t

  @type msg :: Message.t

  @type option :: Option.t

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

  @spec path(msg) :: char_list
  def path(msg) do
    "/" <> Enum.join(get_option_values(msg, :uri_path), "/")
  end

  @spec path(msg, uri_path :: char_list) :: msg
  def path(msg, uri_path) do
    current_without_uri = all_options_but(msg, :uri_path)
    new_options = uri_path
      |> String.split("/", trim: true)
      |> Enum.map(fn part -> option(:uri_path, part) end)
    put_in(msg.options, current_without_uri ++ new_options)
  end

  @spec path(msg) :: integer
  def port(msg) do
    case get_option_values(msg, :uri_port) do
      [] -> @coap_port
      [first | _] -> first
    end
  end

  @spec port(msg, value) :: msg
  def port(msg, value) do
    new_options = [option(:uri_port, value) | all_options_but(msg, :uri_port)]
    put_in(msg.options, new_options)
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
    to_string :io_lib.format "~B.~2..0B", Tuple.to_list(code_pair(header))
  end

  @spec response_code(code_pair) :: name
  def response_code(code_pair = {_code_class, _code_detail}) do
    @responses[code_pair]
  end

  @spec response_code(name) :: code_pair
  def response_code(name) when is_atom(name) do
    @responses_reverse[name]
  end

  @spec option_value(option) :: integer | binary | char_list
  def option_value(%Option{number: number, value: value}) do
    case @option_formats[@options[number]] do
      :opaque -> value
      :string -> to_string value
        :uint -> :binary.decode_unsigned value
       :empty -> <<>>
       :mixed -> value
    end
  end

  @spec option(name, content :: integer | binary | char_list) :: option
  def option(name, opt_value \\ <<>>) do
    %Option{
      number: @options_reverse[name],
      value: encode_option_value(@option_formats[name], opt_value)
    }
  end

  defp encode_option_value(format, opt_value) do
    case format do
      :opaque -> to_string opt_value
      :string -> to_string opt_value
        :uint -> :binary.encode_unsigned opt_value
       :empty -> <<>>
       :mixed -> cond do
          is_integer(opt_value) -> encode_option_value(:uint, opt_value)
          is_binary(opt_value) -> opt_value
          true -> to_string opt_value
        end
    end
  end

  @spec header(type_name :: name, code_name :: name, token :: binary, message_id :: non_neg_integer) :: header
  def header(type_name, code_name, token \\ <<>>, message_id \\ 0) do
    type = @types_reverse[type_name]
    {code_class, code_detail} = @methods_reverse[code_name] || @responses_reverse[code_name]
    %Header{
      type: type,
      code_class: code_class,
      code_detail: code_detail,
      message_id: message_id,
      token: token
    }
  end

  @spec message(header, options :: [option], payload :: binary) :: msg
  def message(header, options \\ [], payload \\ <<>>) do
    %Message {
      header: header,
      options: options,
      payload: payload
    }
  end

  defp get_option_values(%Message{options: options}, name) do
    uri_value = @options_reverse[name]
    options
      |> Enum.filter(fn opt -> opt.number == uri_value end)
      |> Enum.map(&option_value/1)
  end

  defp all_options_but(%Message{options: options}, name) do
    option_number = @options_reverse[name]
    Enum.filter(options, fn opt -> opt.number != option_number end)
  end

  defp code_pair(header = %Header{}) do
    {header.code_class, header.code_detail}
  end

end