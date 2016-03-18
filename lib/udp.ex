
# {:ok, udp} = UDP.start_link(port: 3535, handlers: [])
# UDP.listen(udp)

# {:ok, udp} = UDP.start_link(port: 3536, handlers: [])
# UDP.send(udp, {127,0,0,1}, 3535, "hello")

defmodule UDP.State do
  defstruct socket: nil, events: nil
end

defmodule UDP do
  use GenServer

  alias :gen_udp, as: GenUDP

  @defaults [port: 3535, handlers: []]

  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  def init(options) do
    for handler <- options[:handlers],
      do: listen(self, handler)

    with {:ok, socket} <- GenUDP.open(options[:port]),
         {:ok, events} <- GenEvent.start_link([]),
         do: {:ok, %UDP.State{socket: socket, events: events}}
  end

  def handle_call({:send, address, port, msg}, _from, state) do
    confirmation = GenUDP.send(state.socket, address, port, msg)
    {:reply, confirmation, state}
  end

  def handle_call({:listen, handler}, _from, state) do
    ref = make_ref
    reply =
      case GenEvent.add_handler(state.events, {UDP.Handler, ref}, handler) do
        :ok -> {:ok, ref}
        error -> error
      end
    {:reply, reply, state}
  end

  def handle_info({:udp, _port_id, address, port, msg}, state) do
    GenEvent.notify(state.events, {:datagram, {self, address, port, msg}})
    {:noreply, state}
  end

  def send(udp, address, port, msg) do
    GenServer.call(udp, {:send, address, port, msg})
  end

  def listen(udp, handler \\ self) when is_pid(handler) do
    GenServer.call(udp, {:listen, handler})
  end

end

defmodule UDP.Handler do
  use GenEvent

  def init(handler) do
    :erlang.monitor(:process, handler)
    {:ok, handler}
  end

  def handle_event({:datagram, datagram}, handler) do
    send handler, datagram
    {:ok, handler}
  end

  def handle_info({:DOWN, _, _, pid, _}, handler) when pid == handler do
    :remove_handler
  end

  def handle_info(_, handler) do
    {:ok, handler}
  end

end
