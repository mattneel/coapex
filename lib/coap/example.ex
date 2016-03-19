defmodule OKServer do
  use CoAP.Server

  def start_link do
    CoAP.Server.start_link(__MODULE__, [])
  end

  def init([]) do
    IO.puts "Server starting..."
    {:ok, :nada}
  end

  def handle_confirmable(message, from, :nada) do
    IO.puts "Received from #{inspect from} confirmable #{inspect message}"
    {:noreply, :nada}
  end

  def handle_other(message, from, :nada) do
    IO.puts "Received from #{inspect from} #{inspect message}"
    {:noreply, :nada}
  end

  def handle_invalid(error, from, :nada) do
    IO.puts("Error #{inspect error} from #{inspect from}")
    {:noreply, :nada}
  end

  def handle_info(info, :nada) do
    IO.puts("Info #{inspect info}")
    {:noreply, :nada}
  end

  def terminate(reason, :nada) do
    IO.puts("Terminate with reason #{inspect reason}")
  end

  def code_change(old_vsn, :nada, _extra) do
    IO.puts("Update code from #{old_vsn}")
    {:ok, :nada}
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
