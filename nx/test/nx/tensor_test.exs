defmodule Nx.TensorTest do
  use ExUnit.Case, async: true

  defmodule ProcessBackend do
    @behaviour Nx.Backend
    defstruct [:key]

    funs = Nx.Backend.behaviour_info(:callbacks) -- [from_binary: 3, backend_deallocate: 1]

    for {fun, arity} <- funs do
      args = Macro.generate_arguments(arity, __MODULE__)

      def unquote(fun)(unquote_splicing(args)) do
        raise "not supported"
      end
    end

    def from_binary(tensor, binary, opts) do
      key = Keyword.fetch!(opts, :key)
      Process.put(key, binary)
      put_in(tensor.data, %__MODULE__{key: key})
    end

    def backend_deallocate(%Nx.Tensor{data: %__MODULE__{key: key}}) do
      if Process.delete(key) do
        :ok
      else
        :already_deallocated
      end
    end
  end

  describe "tensor" do
    test "transfers existing tensor" do
      Nx.tensor(Nx.tensor([1, 2, 3]), backend: ProcessBackend, backend_options: [key: :example])
      assert Process.get(:example) == <<1::64-native, 2::64-native, 3::64-native>>
    end

    test "transfers new tensor" do
      Nx.tensor([1, 2, 3], backend: ProcessBackend, backend_options: [key: :example])
      assert Process.get(:example) == <<1::64-native, 2::64-native, 3::64-native>>
    end
  end

  describe "backend_transfer" do
    test "transfers existing tensor" do
      Nx.tensor([1, 2, 3]) |> Nx.backend_transfer(ProcessBackend, key: :example)
      assert Process.get(:example) == <<1::64-native, 2::64-native, 3::64-native>>
    end
  end

  describe "backend_deallocate" do
    test "deallocates existing tensor" do
      t = Nx.tensor([1, 2, 3]) |> Nx.backend_transfer(ProcessBackend, key: :example)
      assert Process.get(:example) == <<1::64-native, 2::64-native, 3::64-native>>
      assert Nx.backend_deallocate(t) == :ok
      refute Process.get(:example)
      assert Nx.backend_deallocate(t) == :already_deallocated
    end
  end

  describe "tuples" do
    test "on backend_transfer" do
      assert Nx.backend_transfer({Nx.tensor(1), 2}) == {Nx.tensor(1), Nx.tensor(2)}
    end

    test "on backend_deallocate" do
      assert Nx.backend_deallocate({Nx.tensor(1), 2}) == {:ok, :ok}
    end
  end
end
