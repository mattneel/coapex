defmodule CoAP.Message.Test do
  use ExUnit.Case

  test "the truth" do
    msg = <<0x40, 0x1, 0x30, 0x39, 0x21, 0x3,
      0x26, 0x77, 0x65, 0x65, 0x74, 0x61, 0x67,
      0xff, ?h, ?i>>

    parsed = CoAP.Parser.parse(msg)

    expected =
      %CoAP.Message{
        header: %CoAP.Header{
          version: 1,
          code_class: 0,
          code_detail: 1,
          message_id: 12345,
          token: "",
          type: 0
        },
        options: [
          %CoAP.Option{number: 2, value: <<3>>},
          %CoAP.Option{number: 4, value: "weetag"}
        ],
        payload: "hi"
      }

    assert parsed == expected
    assert CoAP.Serializer.serialize(parsed) == msg
  end

end
