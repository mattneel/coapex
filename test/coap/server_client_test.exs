defmodule CoAP.ServerClient.Test do
  use ExUnit.Case

  test "server handles message sent by client" do
    {:ok, _server} = OKServer.start_link
    {:ok, client} = CoAP.Client.start_link

    {:ok, response} = CoAP.Client.request(client, {127,0,0,1}, 5683,
      CoAP.message(
        CoAP.header(:confirmable, :GET, "oi")))

    assert CoAP.code_string(response) == "2.00"
    assert CoAP.type(response) == :acknowledgement
    assert response.header.token == "oi"
  end

end