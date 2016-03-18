defmodule CoAP.Message.Test do
  use ExUnit.Case

  test "the truth" do
    data = <<0x40, 0x1, 0x30, 0x39, 0x21, 0x3,
      0x26, 0x77, 0x65, 0x65, 0x74, 0x61, 0x67,
      0xff, ?h, ?i>>

    msg = CoAP.Parser.parse(data)

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


    assert CoAP.Message.type(msg) == :confirmable
    assert CoAP.Message.class(msg) == :request
    assert CoAP.Message.method(msg) == :GET
    assert msg == expected
    assert CoAP.Serializer.serialize(msg) == data
  end

end
