defmodule CoAP.Client.State do

  defstruct udp: nil, requests: %{}, last_id: -1

end

defmodule CoAP.Client do
  use GenServer

  @max_message_id 65536

  @defaults [
    port: 0]

  @type client :: pid

  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}

  @type address :: :inet.ip_address | :inet.hostname

  @type msg :: CoAP.Message.t

  @spec start_link :: on_start
  def start_link do
    start_link([])
  end

  @spec start_link([atom: any]) :: on_start
  def start_link(opts) do
    opts = Keyword.merge(@defaults, is_list(opts) && opts || [])
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    with {:ok, udp} <- UDP.start_link(port: opts[:port]) do
      UDP.listen(udp)
      {:ok, %CoAP.Client.State{udp: udp}}
    end
  end

  def handle_cast({:request, to, msg, task}, state) do
    message_id = state.last_id + 1
    msg = update_in(msg.header.message_id, fn _ -> rem(message_id, @max_message_id) end)
    case udp_send(state.udp, to, msg) do
      :ok ->
        updated_requests = Map.put(state.requests, message_id, {to, msg, task})
        new_state = %{state |
          last_id: message_id,
          requests: updated_requests
        }
        {:noreply, new_state}
      err ->
        send task, err
        {:noreply, state}
    end
  end

  def handle_cast({:message, from, msg}, state) do
    message_id = msg.header.message_id
    case state.requests[message_id] do
      {^from, _request, task} ->
        updated_requests = Map.delete(state.requests, message_id)
        send task, {:ok, msg}
        new_state = %{state |
          requests: updated_requests
        }
        {:noreply, new_state}
      _ ->
        {:noreply, state}
    end

  end

  def handle_cast({:invalid, _e, _from}, state) do
    IO.puts :invalid
    {:noreply, state}
  end

  def handle_info({:datagram, {_udp, address, port, data}}, state) do
    from = {address, port}
    try do
      msg = CoAP.Parser.parse(data)
      GenServer.cast(self, {:message, from, msg})
    rescue
      e -> GenServer.cast(self, {:invalid, from, e})
    end
    {:noreply, state}
  end

  defp udp_send(udp, {to_addr, to_port}, request) do
    try do
      data = CoAP.Serializer.serialize(request)
      UDP.send(udp, to_addr, to_port, data)
    rescue
      e -> {:error, e}
    end
  end

  @spec request(client, address, port :: :inet.port_number, msg, timeout) :: {:ok, msg} | {:error, term}
  def request(client, address, port, msg, timeout \\ 5000) do
    task = self
    GenServer.cast(client, {:request, {address, port}, msg, task})
    receive do
      {:DOWN, _ref, :process, ^client, _reason} -> {:error, :client_closed}
      result -> result
    after
      timeout -> {:error, :timeout}
    end
  end

end
