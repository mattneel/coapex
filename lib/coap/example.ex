defmodule OKServer do
  use CoAP.Server

  def start_link do
    CoAP.Server.start_link(__MODULE__, [])
  end

  def init([]) do
    log "Server starting..."
    {:ok, :nada}
  end

  def handle_confirmable(msg, from, :nada) do
    log "Received from #{inspect from} confirmable #{inspect msg}"

    response = CoAP.Message.ack(msg)
      |> CoAP.code(:ok)

    case CoAP.path(msg) do
      "/observe" ->
        fun = fn
          :start -> {response, 0}
          10 -> :end
          n -> observe(msg, n)
        end
        {:reply_async, fun, :nada}
      _ ->
        {:reply, response, :nada}
    end
  end

  defp observe(msg, n) do
    log "Observe #{n}"
    response = CoAP.Message.empty
      |> CoAP.type(:non_confirmable)
      |> CoAP.code(:ok)
      |> CoAP.token(msg.header.token)
      |> CoAP.add_option(CoAP.option(:observe, n))
      |> CoAP.payload(<<?A + n>>)

    :timer.sleep(500)
    {response, n + 1}
  end

  def handle_other(msg, from, :nada) do
    log "Received from #{inspect from} #{inspect msg}"
    {:noreply, :nada}
  end

  def handle_invalid(error, from, :nada) do
    log "Error #{inspect error} from #{inspect from}"
    {:noreply, :nada}
  end

  def handle_info(info, :nada) do
    log "Info #{inspect info}"
    {:noreply, :nada}
  end

  def terminate(reason, :nada) do
    log "Terminate with reason #{inspect reason}"
  end

  def code_change(old_vsn, :nada, _extra) do
    log "Update code from #{old_vsn}"
    {:ok, :nada}
  end

  defp log(_entry) do
    # IO.puts(_entry)
  end

end

defmodule OKClient do

  def request(server_address \\ {127,0,0,1}, server_port \\ 5683) do
    {:ok, client} = CoAP.Client.start_link

    root_request = CoAP.Message.empty
      |> CoAP.type(:confirmable)
      |> CoAP.code(:GET)

    IO.inspect CoAP.Client.request(client, server_address, server_port, root_request)

    observe_request = CoAP.Message.empty
      |> CoAP.type(:confirmable)
      |> CoAP.code(:GET)
      |> CoAP.token("my-token")
      |> CoAP.path("/observe")
      |> CoAP.add_option(CoAP.option(:observe))

    IO.inspect CoAP.Client.request(client, server_address, server_port, observe_request)

    for pair <- CoAP.Client.listen(client) |> Stream.take(10) do
      IO.inspect pair
    end

    :ok
  end

end
