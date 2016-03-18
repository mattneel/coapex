

defmodule CoAP do

end

defmodule CoAP.Message do
  defstruct header: nil, options: [], payload: <<>>

  def type(msg) do
    case msg.header.type do
      0 -> :confirmable
      1 -> :non_confirmable
      2 -> :acknowledgement
      3 -> :reset
    end
  end

  def class(msg) do
    case msg.header.code_class do
      0 -> :request
      2 -> :success_response
      4 -> :client_error_response
      5 -> :server_error_response
    end
  end

  def method(msg) do
    case {msg.header.code_class, msg.header.code_detail} do
      {0, 1} -> :GET
      {0, 2} -> :POST
      {0, 3} -> :PUT
      {0, 4} -> :DELETE
      _ -> :unknown
    end
  end

  def code(msg) do
    "#{msg.header.code_class}.#{msg.header.code_detail}"
  end

  def empty?(msg) do
    msg.header.code_class == 0 and msg.header.code_detail == 0
  end

  def sort_options(msg) do
    update_in(msg.options, &Enum.sort_by(&1, fn opt -> opt.number end))
  end

end

defmodule CoAP.Header do
  defstruct version: 0, type: 0, code_class: 0, code_detail: 0, message_id: 0, token: <<>>
end

defmodule CoAP.Option do
  defstruct number: 0, value: <<>>
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

  def serialize_payload(payload) do
    <<@payload_marker, payload :: binary>>
  end

end
