defmodule CoAP.Parser do
  use CoAP.Common

  def parse(binary) do
    %CoAP.Message{} |> parse_header(binary) |> CoAP.Message.invert_options
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
