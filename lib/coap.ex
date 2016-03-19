
defmodule CoAP.Codes do

  defmacro __using__(_) do
    quote do

      @version 1

      @types %{
        0 => :confirmable,
        1 => :non_confirmable,
        2 => :acknowledgement,
        3 => :reset
      }

      @classes %{
        0 => :request,
        2 => :success_response,
        4 => :client_error_response,
        5 => :server_error_response
      }

      @methods %{
        {0, 1} => :GET,
        {0, 2} => :POST,
        {0, 3} => :PUT,
        {0, 4} => :DELETE
      }

      @responses %{
        {2,  1} => :created,
        {2,  2} => :deleted,
        {2,  3} => :valid,
        {2,  4} => :changed,
        {2,  5} => :content,
        {4,  0} => :bad_request,
        {4,  1} => :unauthorized,
        {4,  2} => :bad_option,
        {4,  3} => :forbidden,
        {4,  4} => :not_found,
        {4,  5} => :method_not_allowed,
        {4,  6} => :not_acceptable,
        {4, 12} => :precondition_failed,
        {4, 13} => :request_entity_too_large,
        {4, 15} => :unsupported_content_format,
        {5,  0} => :internal_server_error,
        {5,  1} => :not_implemented,
        {5,  2} => :bad_gateway,
        {5,  3} => :service_unavailable,
        {5,  4} => :gateway_timeout,
        {5,  5} => :proxying_not_supported
      }

      @responses_reverse MapUtil.invert(@responses)

      @options %{
         1 => :if_match,
         3 => :uri_host,
         4 => :etag,
         5 => :if_none_match,
         7 => :uri_port,
         8 => :location_path,
        11 => :uri_path,
        12 => :content_format,
        14 => :max_age,
        15 => :uri_query,
        17 => :accept,
        20 => :location_query,
        35 => :proxy_uri,
        39 => :proxy_scheme,
        60 => :size1
      }

      @options_reverse MapUtil.invert(@options)

    end
  end

end

defmodule CoAP.Message do
  use CoAP.Codes

  defstruct header: nil, options: [], payload: <<>>

  def sort_options(msg) do
    update_in(msg.options, &Enum.sort_by(&1, fn opt -> opt.number end))
  end

  def empty?(%CoAP.Message{header: header}) do
    CoAP.Header.empty?(header)
  end

  def type(%CoAP.Message{header: header}) do
    CoAP.Header.type(header)
  end

  def class(%CoAP.Message{header: header}) do
    CoAP.Header.class(header)
  end

  def method(%CoAP.Message{header: header}) do
    CoAP.Header.method(header)
  end

  def code(%CoAP.Message{header: header}) do
    CoAP.Header.code(header)
  end

end

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

defmodule CoAP.Common do

  defmacro __using__(_) do
    quote do
      @payload_marker 0xff
      @extended_option_1_byte 13
      @extended_option_2_bytes 269
    end
  end

end

defmodule CoAP.Parser do
  use CoAP.Common

  def parse(binary) do
    %CoAP.Message{} |> parse_header(binary) |> CoAP.Message.sort_options
  end

  def parse_header(msg, header) do
    <<
      version :: unsigned-size(2),
      type :: unsigned-size(2),
      token_length :: unsigned-size(4),
      code_class :: unsigned-size(3),
      code_detail :: unsigned-size(5),
      message_id :: unsigned-size(16),
      token :: binary-size(token_length),
      rest :: binary
    >> = header

    if version != 1, do: raise "Unknown version"

    if token_length >= 9, do: raise "TKL #{token_length} is invalid"

    hdr = %CoAP.Header{
      version: version, type: type, code_class: code_class,
      code_detail: code_detail, message_id: message_id, token: token}

    put_in(msg.header, hdr) |> parse_options(rest)
  end

  def parse_options(msg, <<>>) do
    msg
  end

  def parse_options(msg, <<@payload_marker, payload :: binary>>) do
    parse_payload(msg, payload)
  end

  def parse_options(msg, option) do
    <<
      option_delta :: unsigned-size(4),
      option_length :: unsigned-size(4),
      left :: binary
    >> = option

    {option_delta, left} = extended_option_number(option_delta, left)
    {option_length, left} = extended_option_number(option_length, left)

    <<
      option_value :: binary-size(option_length),
      rest :: binary
    >> = left

    update = fn
      [] ->
        opt = %CoAP.Option{number: option_delta, value: option_value}
        [opt]
      opts = [previous | _] ->
        opt = %CoAP.Option{number: previous.number + option_delta, value: option_value}
        [opt | opts]
    end
    update_in(msg.options, update) |> parse_options(rest)
  end

  def parse_payload(msg, payload) do
    put_in(msg.payload, payload)
  end

  defp extended_option_number(number, left) do
    case number do
      13 ->
        <<extended_option :: unsigned-size(8), left :: binary>> = left
        {extended_option + @extended_option_1_byte, left}
      14 ->
        <<extended_option :: unsigned-size(16), left :: binary>> = left
        {extended_option + @extended_option_2_bytes, left}
      15 ->
        raise "Invalid option header value 15"
      n ->
        {n, left}
    end
  end

end

defmodule CoAP.Serializer do
  use CoAP.Common

  def serialize(msg) do
    opts = CoAP.Message.sort_options(msg).options
    serialize_header(msg.header) <> serialize_options(opts) <> serialize_payload(msg.payload)
  end

  def serialize_header(hdr) do
    <<
      hdr.version :: unsigned-size(2),
      hdr.type :: unsigned-size(2),
      byte_size(hdr.token) :: unsigned-integer-size(4),
      hdr.code_class :: unsigned-size(3),
      hdr.code_detail :: unsigned-size(5),
      hdr.message_id :: unsigned-size(16),
      hdr.token :: binary
    >>
  end

  def serialize_options(opts) do
    {opts_with_increment, _} =
      Enum.map_reduce(opts, 0, fn opt, offset ->
        increment = opt.number - offset
        {{increment, opt}, opt.number}
      end)

    for {inc, opt} <- opts_with_increment, into: <<>> do
      {option_delta, option_delta_ext} = extended_option_number(inc)
      {option_length, option_length_ext} = extended_option_number(byte_size opt.value)
      <<
        option_delta :: unsigned-size(4),
        option_length :: unsigned-size(4),
        option_delta_ext :: binary,
        option_length_ext :: binary,
        opt.value :: binary
      >>
    end
  end

  defp extended_option_number(number) do
    cond do
      number < 13 ->
        {number, <<>>}
      number <= 269 ->
        {13, <<number-13 :: unsigned-size(8)>>}
      true ->
        {14, <<number-269 :: unsigned-size(16)>>}
    end
  end

  def serialize_payload(<<>>) do
    <<>>
  end

  def serialize_payload(payload) do
    <<@payload_marker, payload :: binary>>
  end

end
