defmodule CoAP.Message.Test do
  use ExUnit.Case

  # binaries shameless copied from https://github.com/dustin/go-coap/blob/master/message_test.go
  test "handles messages with options" do
    msg = validate <<
      0x40, 0x01, 0x30, 0x39, 0x21, 0x03, 0x26, 0x77,
      0x65, 0x65, 0x74, 0x61, 0x67, 0xff,   ?h,   ?i>>

    assert CoAP.type(msg) == :confirmable
    assert CoAP.class(msg) == :request
    assert CoAP.method(msg) == :GET
    assert msg == %CoAP.Message{
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
  end

  # binaries shameless copied from https://github.com/dustin/go-coap/blob/master/message_test.go
  test "handles messages with large options" do
    msg = validate <<
      0x40, 0x01, 0x30, 0x39, 0xbd, 0x19, 0x74, 0x68, 0x69,
      0x73, 0x5f, 0x70, 0x61, 0x74, 0x68, 0x5f, 0x69, 0x73,
      0x5f, 0x6c, 0x6f, 0x6e, 0x67, 0x65, 0x72, 0x5f, 0x74,
      0x68, 0x61, 0x6e, 0x5f, 0x66, 0x69, 0x66, 0x74, 0x65,
      0x65, 0x6e, 0x5f, 0x62, 0x79, 0x74, 0x65, 0x73>>

    assert msg == %CoAP.Message{
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
  end

  test "handles messages with id" do
    msg = validate <<0x40, 0x01, 0x7d, 0x34, 0xbb, "temperature" :: binary>>

    assert msg == %CoAP.Message{
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
  end

  test "handles messages with payload" do
    msg = validate <<0x61, 0x69, 0x7d, 0x35, 0x41, 0xff, "22.3 C" :: binary>>

    assert msg == %CoAP.Message{
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
  end

  defp validate(data) do
    msg = CoAP.Parser.parse(data)
    assert CoAP.Serializer.serialize(msg) == data
    msg
  end

end
