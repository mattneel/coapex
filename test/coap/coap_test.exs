defmodule CoAP.Test do
  use ExUnit.Case

  test "adds no option if path is empty or /" do
    empty = CoAP.Message.empty

    assert CoAP.path(empty, "").options == []
    assert CoAP.path(empty, "/").options == []
  end

  test "sets a path on a message" do
    msg = CoAP.path(CoAP.Message.empty, "/hello/world")

    assert msg.options == [
      %CoAP.Option{number: 11, value: "hello"},
      %CoAP.Option{number: 11, value: "world"}]
  end

  test "removes old paths when setting" do
    msg = CoAP.path(CoAP.Message.empty, "/hello/world")
    msg = CoAP.path(msg, "/bye/universe")

    assert msg.options == [
      %CoAP.Option{number: 11, value: "bye"},
      %CoAP.Option{number: 11, value: "universe"}]
  end

  test "gets the path on a message" do
    msg = CoAP.path(CoAP.Message.empty, "/hello/world")

    assert CoAP.path(msg) == "/hello/world"
  end

  test "returns / on an empty path" do
    assert CoAP.path(CoAP.Message.empty) == "/"
  end

  test "returns default port when there is no option" do
    assert CoAP.port(CoAP.Message.empty) == 5683
  end

  test "sets a port" do
    msg = CoAP.port(CoAP.Message.empty, 12345)

    assert msg.options == [%CoAP.Option{number: 7, value: "09"}]
    assert CoAP.port(msg) == 12345
  end

end