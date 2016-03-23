defmodule CoAP.Client.State do

  defstruct udp: nil, sender_m_id: %{}, m_id_sender: %{}, last_id: -1, messages: nil

end

defmodule CoAP.Client do
  use GenServer

  @max_message_id 65536

  @max_retransmit 3

  @ack_timeout 1000

  @defaults [
    port: 0]

  @type client :: pid

  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}

  @type address :: :inet.ip_address | :inet.hostname

  @type udp_port :: :inet.port_number

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
    with {:ok, messages} <- GenEvent.start_link,
      {:ok, udp} <- UDP.start_link(port: opts[:port])
    do
      UDP.listen(udp)
      {:ok, %CoAP.Client.State{
        udp: udp,
        messages: messages
      }}
    end
  end

  def handle_cast({:request, to, msg, task}, state) do
    message_id = state.last_id + 1
    msg = put_in(msg.header.message_id, rem(message_id, @max_message_id))

    {:ok, sender} = CoAP.Client.Sender.start_link(state.udp, to, msg, task)
    :erlang.monitor(:process, sender)

    new_state = %{state |
      last_id: message_id,
      sender_m_id: Map.put(state.sender_m_id, sender, message_id),
      m_id_sender: Map.put(state.m_id_sender, message_id, sender)
    }

    {:noreply, new_state}
  end

  def handle_info({:datagram, {_udp, address, port, data}}, state) do
    try do
      msg = CoAP.Parser.parse(data)
      message_id = msg.header.message_id
      from = {address, port}
      case state.m_id_sender[message_id] do
        nil ->
          GenEvent.notify(state.messages, {from, msg})
        sender ->
          GenServer.cast(sender, {:message, from, msg})
      end
    rescue
      _e -> {}
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, pid, _}, state) do
    case state.sender_m_id[pid] do
      nil ->
        {:noreply, state}
      message_id ->
        new_state = %{state |
          sender_m_id: Map.delete(state.sender_m_id, pid),
          m_id_sender: Map.delete(state.m_id_sender, message_id)
        }
        {:noreply, new_state}
    end
  end

  def handle_call(:listener, _from, state) do
    {:reply, GenEvent.stream(state.messages), state}
  end

  @spec request(client, address, port :: udp_port, msg, timeout) :: {:ok, msg} | {:error, term}
  def request(client, address, port, msg, timeout \\ :infinity) do
    task = self
    monitor_ref = :erlang.monitor(:process, client)
    GenServer.cast(client, {:request, {address, port}, msg, task})
    response =
      receive do
        {:DOWN, _ref, :process, ^client, _reason} -> {:error, :client_closed}
        result -> result
      after
        timeout -> {:error, :timeout}
      end
    :erlang.demonitor(monitor_ref)
    response
  end

  @spec listen(client) :: GenEvent.Stream.t
  def listen(client) do
    GenServer.call(client, :listener)
  end

end

defmodule CoAP.Client.Sender.State do

  defstruct first: true, udp: nil, to: nil, msg: nil, task: nil, counter: 0, timeout: 0

end

defmodule CoAP.Client.Sender do
  use GenServer

  alias CoAP.Client.Sender.State

  @max_retransmit 3

  @ack_timeout 1000

  def start_link(udp, to, msg, task) do
    initial_timeout = trunc(@ack_timeout + :random.uniform * @ack_timeout)
    state = %State{
      udp: udp,
      to: to,
      msg: msg,
      task: task,
      timeout: initial_timeout
    }
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    GenServer.cast(self, :start)
    {:ok, state}
  end

  def handle_cast(:start, state) do
    send(state)
  end

  def handle_cast({:message, from, msg}, state = %State{to: to}) when from == to do
    send state.task, {:ok, msg}
    {:stop, :normal, state}
  end

  def handle_cast({:message, _from, _msg}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    send(state)
  end

  defp send(state = %State{counter: @max_retransmit}) do
    send state.task, {:error, :timeout}
    {:stop, :normal, state}
  end

  defp send(state) do
    case udp_send(state.udp, state.to, state.msg) do
      :ok ->
        new_state =
          if state.first do
            put_in(state.first, false)
          else
            %{state |
              counter: state.counter + 1,
              timeout: state.timeout * 2
            }
          end
        {:noreply, new_state, new_state.timeout}
      err ->
        send state.task, err
        {:stop, :normal, state}
    end
  end

  defp udp_send(udp, {to_addr, to_port}, request) do
    try do
      data = CoAP.Serializer.serialize(request)
      UDP.send(udp, to_addr, to_port, data)
    rescue
      e -> {:error, e}
    end
  end

end