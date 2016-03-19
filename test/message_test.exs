# binaries shameless copied from https://github.com/dustin/go-coap/blob/master/message_test.go
defmodule CoAP.Message.Test do
  use ExUnit.Case
  use CoAP.Codes

  test "the truth" do
    data = <<0x40, 0x01, 0x30, 0x39, 0x21, 0x03, 0x26, 0x77,
             0x65, 0x65, 0x74, 0x61, 0x67, 0xff,   ?h,   ?i>>

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

  test "two" do
    data = <<0x40, 0x01, 0x30, 0x39, 0xbd, 0x19, 0x74, 0x68, 0x69,
             0x73, 0x5f, 0x70, 0x61, 0x74, 0x68, 0x5f, 0x69, 0x73,
             0x5f, 0x6c, 0x6f, 0x6e, 0x67, 0x65, 0x72, 0x5f, 0x74,
             0x68, 0x61, 0x6e, 0x5f, 0x66, 0x69, 0x66, 0x74, 0x65,
             0x65, 0x6e, 0x5f, 0x62, 0x79, 0x74, 0x65, 0x73>>

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
          %CoAP.Option{number: 11, value: "this_path_is_longer_than_fifteen_bytes"}
        ],
        payload: ""
      }

    assert msg == expected
    assert CoAP.Serializer.serialize(msg) == data
  end

  test "blah" do
    data = <<0x40, 0x01, 0x7d, 0x34, 0xbb, "temperature" :: binary>>

    msg = CoAP.Parser.parse(data)

    expected = %CoAP.Message{
      header: %CoAP.Header{
        version: 1,
        code_class: 0,
        code_detail: 1,
        message_id: 32052,
        token: "",
        type: 0
      },
      options: [
        %CoAP.Option{number: 11, value: "temperature"}
      ],
      payload: ""
    }

    assert msg == expected
  end

  test "bleh" do
    data = <<0x61, 0x69, 0x7d, 0x35, 0x41, 0xff, "22.3 C" :: binary>>

    msg = CoAP.Parser.parse(data)

    expected =
      %CoAP.Message{
        header: %CoAP.Header{
          version: 1,
          code_class: 3,
          code_detail: 9,
          message_id: 32053,
          token: "A",
          type: 2,
        },
        options: [],
        payload: "22.3 C"
      }

    assert msg == expected
  end

end
