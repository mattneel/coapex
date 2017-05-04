defmodule UDP.State do
  defstruct socket: nil, events: nil
end

defmodule UDP do
  use GenServer

  alias :gen_udp, as: GenUDP

  @defaults [port: 3535, handlers: [], udp_options: [:inet6]]

  @type udp :: pid

  @type msg :: CoAP.Message.t

  @type address :: :inet.ip_address | :inet.hostname

  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}

  @spec start_link(options :: {atom, term}) :: on_start
  def start_link(options) do
    options = is_list(options) && options || []
    options = Keyword.merge(@defaults, options)
    GenServer.start_link(__MODULE__, options)
  end

  def init(options) do
    for handler <- options[:handlers],
      do: listen(self, handler)

    with {:ok, socket} <- GenUDP.open(options[:port], options[:udp_options]),
         {:ok, events} <- GenEvent.start_link,
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
    GenEvent.notify(state.events, {:datagram, {self, address, port, :binary.list_to_bin msg}})
    {:noreply, state}
  end

  @spec send(udp, address, port :: :inet.port_number, msg) :: :ok | {:error, term}
  def send(udp, address, port, msg) do
    GenServer.call(udp, {:send, address, port, msg})
  end

  @spec send(udp, uri :: char_list, msg) :: :ok | {:error, term}
  def send(udp, uri, msg) do
    parsed_uri = URI.parse(uri)
    send(udp, String.to_atom(parsed_uri.host), parsed_uri.port, msg)
  end

  @spec listen(udp, handler :: pid) :: {:ok, reference} | {:error, term}
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

  def handle_event(datagram = {:datagram, _data}, handler) do
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
