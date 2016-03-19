defmodule OKServer do
  use CoAP.Server

  def start_link do
    CoAP.Server.start_link(__MODULE__, [])
  end

  def init([]) do
    log "Server starting..."
    {:ok, :nada}
  end

  def handle_confirmable(message, from, :nada) do
    log "Received from #{inspect from} confirmable #{inspect message}"
    {:noreply, :nada}
  end

  def handle_other(message, from, :nada) do
    log "Received from #{inspect from} #{inspect message}"
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
    # IO.puts(entry)
  end

end

defmodule OKClient do

  def request do
    {:ok, client} = CoAP.Client.start_link
    CoAP.Client.request(client, {127,0,0,1}, 3535, %CoAP.Message{
      header: %CoAP.Header{
        type: 0,
        code_class: 0,
        code_detail: 1
      }
    })
  end

end
