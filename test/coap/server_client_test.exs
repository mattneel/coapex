defmodule CoAP.ServerClient.Test do
  use ExUnit.Case

  test "server handles message sent by client" do
    {:ok, _server} = OKServer.start_link

    {:ok, client} = CoAP.Client.start_link
    {:ok, response} = CoAP.Client.request(client, {127,0,0,1}, 3535,
      CoAP.message(
        CoAP.header(:confirmable, :GET, "oi")))

    %CoAP.Message{
      header: %CoAP.Header{
        type: 0,
        code_class: 0,
        code_detail: 1,
        token: "oi"
      }
    }

    assert CoAP.empty? response
    assert CoAP.type(response) == :acknowledgement
    assert response.header.token == "oi"
  end

end