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
      number < 269 ->
        {13, <<number - 13 :: unsigned-size(8)>>}
      true ->
        {14, <<number - 269 :: unsigned-size(16)>>}
    end
  end

  def serialize_payload(<<>>) do
    <<>>
  end

  def serialize_payload(payload) do
    <<@payload_marker, payload :: binary>>
  end

end
