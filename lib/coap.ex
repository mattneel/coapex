

defmodule CoAP do

end

defmodule CoAP.Message do
  defstruct header: nil, options: [], payload: <<>>
end

defmodule CoAP.Header do
  defstruct version: 0, type: 0, code_class: 0, code_detail: 0, message_id: 0, token: <<>>
end

defmodule CoAP.Option do
  defstruct number: 0, value: <<>>
end

defmodule CoAP.Parser do

  @payload_marker 0xff

  def parse(binary) do
    %CoAP.Message{} |> parse_header(binary)
  end

  def parse_header(msg, header) do
    <<
      version :: unsigned-size(2),
      type :: unsigned-size(2),
      token_length :: unsigned-integer-size(4),
      code_class :: unsigned-size(3),
      code_detail :: unsigned-size(5),
      message_id :: unsigned-size(16),
      token :: binary-size(token_length),
      rest :: binary
    >> = header

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

    {option_delta, left} = extended_option_header(option_delta, left)
    {option_length, left} = extended_option_header(option_length, left)

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

  defp extended_option_header(option_value, left) do
    case option_value do
      13 ->
        <<extended_option_delta :: unsigned-size(8), left :: binary>> = left
        {extended_option_delta + 13, left}
      14 ->
        <<extended_option_delta :: unsigned-size(16), left :: binary>> = left
        {extended_option_delta + 269, left}
      15 ->
        raise "Invalid option header value 15"
      n ->
        {n, left}
    end
  end

end

