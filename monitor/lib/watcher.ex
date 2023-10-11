defmodule Monitor.Watcher do
  use GenServer
  require Logger

  @polling_frequency_ms 5_000
  @number_of_blocks_for_confirmation 0

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      last_confirmed_block_number: 1,
      highest_block: 0
    }

    Process.send_after(self(), :poll, @polling_frequency_ms)
    {:ok, state}
  end

  @doc """
  This handler will first poll the chain for the latest block number, check which blocks are confirmed but have not
  been proved yet, then run a proof for them and upload it to S3.
  """
  @impl true
  def handle_info(
        :poll,
        state = %{
          last_confirmed_block_number: last_confirmed_block_number
        }
      ) do
    Process.send_after(self(), :poll, @polling_frequency_ms)
    current_block_height = 0

    Logger.info("Current block height: #{current_block_height}")

    result = Verifier.add(1, 5)
    Logger.info("Got result from Rust: #{result}")

    {:noreply,
     %{
       state
       | last_confirmed_block_number: last_confirmed_block_number
     }}
  end
end
