defmodule Algae do

  @type ast() :: {atom(), any(), any()}

  @doc """
  --- Id --

  defmodule Id do
    defdata do: id :: any()
  end

  --- Sum ---

  defmodule Either do
    defsum do
      defdata Left  :: any()
      defdata Right :: any()
    end
  end

  defmodule Either do
    defdata do: Left :: any() | Right :: any()
  end

  --- Product --

  defmodule Rectangle do
    data do: width :: number(), height :: number()
  end

  -- Both --

  data Stree a = Tip | Node (Stree a) a (Stree a)
  defmodule Stree do
    defdata do
      Tip :: any() | Node :: (left :: t()), (middle = 42 :: any()), (right :: t())
    end
  end

  defmodule Stree do
    defsum do
      defdata Tip :: any()

      defproduct Node do
        left :: Stree.t()
        middle = 42 :: any()
        right :: Stree.t()
      end
    end
  end
  """
  defmacro defdata(ast) do
    caller_module = __CALLER__.module

    case ast do
      {:::, _, [module_ctx, {:none, _, _} = type_ctx]} ->
        caller_module
        |> modules(module_ctx)
        |> data_ast(type_ctx)

      {:::, _, [{:=, _, [module_ctx, default_value]}, type]} ->
        caller_module
        |> modules(module_ctx)
        |> data_ast(default_value, type)

      {:::, _, [module_ctx, type]} ->
        caller_module
        |> modules(module_ctx)
        |> data_ast(default_value(type), type)

      {outer_type, _, _} = type when is_atom(outer_type) ->
        data_ast(caller_module, type)

      [do: {:__block__, _, lines}] ->
        data_ast(lines)

      [do: line] ->
        data_ast([line])
    end
  end

  defmacro defdata(module_ctx, do: body) do
    module_name =
      __CALLER__.module
      |> modules(module_ctx)
      |> Module.concat()

    inner =
      body
      |> case do
           {:__block__, _, lines} -> lines
           line -> List.wrap(line)
      end
      |> data_ast()

    quote do
      defmodule unquote(module_name) do
        unquote(inner)
      end
    end
  end

  @doc """
  Construct a data type AST
  """
  @spec data_ast(module() | [module()], ast()) :: ast()
  def data_ast(lines) when is_list(lines) do
    {field_values, field_types, typespecs} =
      Enum.reduce(lines, {[], [], []},
        fn(line, {value_acc, type_acc, typespec_acc}) ->
          case line do
            {:::, _, [{:=, _, [{field, _, _}, default_value]}, type]} ->
              {
                [{field, default_value} | value_acc],
                [{field, type} | type_acc],
                [type | typespec_acc]
              }

            {:::, _, [{field, _, _}, type]} ->
              {
                [{field, nil} | value_acc],
                [{field, type} | type_acc],
                [type | typespec_acc]
              }
          end
        end)

    {constructor_args, constructor_mapping} =
      Enum.reduce(field_values, {[], []},
        fn({field, default}, {acc_arg, acc_mapping}) ->
          arg = {field, [], Elixir}

          new_args    = [{:\\, [], [arg, default]} | acc_arg]
          new_mapping = [{field, arg} | acc_mapping]

          {new_args, new_mapping}
      end)

    quote do
      @type t :: %__MODULE__{
        unquote_splicing(field_types)
      }

      defstruct unquote(field_values)

      @doc "Positional constructor, with args in the same order as they were defined in"
      @spec new(unquote_splicing(typespecs)) :: t()
      def new(unquote_splicing(constructor_args)) do
        struct(__MODULE__, unquote(constructor_mapping))
      end
    end
  end

  def data_ast(modules, {:none, _, _}) do
    full_module = Module.concat(modules)

    quote do
      defmodule unquote(full_module) do
        @type t :: %unquote(full_module){}

        defstruct []

        @doc "Default #{__MODULE__} struct"
        @spec new() :: t()
        def new, do: struct(__MODULE__)
      end
    end
  end

  def data_ast(caller_module, type) do
    field =
      caller_module
      |> Module.split()
      |> List.last()
      |> String.downcase()
      |> String.to_atom()

    default = default_value(type)

    quote do
      @type t :: %unquote(caller_module){
        unquote(field) => unquote(type)
      }

      defstruct [{unquote(field), unquote(default)}]

      @doc "Default #{__MODULE__} struct"
      @spec new() :: t()
      def new, do: struct(__MODULE__)

      @doc "Constructor helper for piping"
      @spec new(unquote(type)) :: t()
      def new(field), do: struct(__MODULE__, [unquote(field), field])
    end
  end

  @spec data_ast([module()], any(), ast()) :: ast()
  def data_ast(name, default, type_ctx) do
    full_module = Module.concat(name)

    field =
      name
      |> List.last()
      |> Atom.to_string()
      |> String.downcase()
      |> String.trim_leading("elixir.")
      |> String.to_atom()

    quote do
      defmodule unquote(full_module) do
        @type t :: %unquote(full_module){
          unquote(field) => unquote(type_ctx)
        }

        defstruct [{unquote(field), unquote(default)}]

        @doc "Default #{__MODULE__} struct. Value defaults to #{inspect unquote(default)}."
        @spec new() :: t()
        def new, do: struct(__MODULE__)

        @doc "Helper for initializing struct with a specific value"
        @spec new(unquote(type_ctx)) :: t()
        def new(value), do: struct(__MODULE__, [{unquote(field), value}])
      end
    end
  end

  @doc """
  Generate the AST for a sum type definition
  """
  @spec defsum([do: {:__block__, [any()], ast()}]) :: ast()
  defmacro defsum(do: {:__block__, _, parts} = block) do
    types = or_types(parts, __CALLER__.module)

    quote do
      @type t :: unquote(types)
      unquote(block)
    end
  end

  @spec or_types([ast()], module()) :: [ast()]
  def or_types([head | tail], module_ctx) do
    Enum.reduce(tail, call_type(head, module_ctx), fn(module, acc) ->
      {:|, [], [call_type(module, module_ctx), acc]}
    end)
  end

  @spec modules(module(), [module()]) :: [module()]
  def modules(top, module_ctx), do: [top | extract_name(module_ctx)]

  @spec call_type(module(), [module()]) :: ast()
  def call_type(new_module, module_ctx) do
    full_module = List.wrap(module_ctx) ++ extract_part_name(new_module)
    {{:., [], [{:__aliases__, [alias: false], full_module}, :t]}, [], []}
  end

  @spec extract_part_name({:defdata, any(), [{:::, any(), [any()]}]})
     :: [module()]
  def extract_part_name({:defdata, _, [{:::, _, [body, _]}]}) do
    body
    |> case do
      {:=, _, [inner_module_ctx, _]} -> inner_module_ctx
      outer_module_ctx -> outer_module_ctx
    end
    |> List.wrap()
  end

  def extract_part_name({:defdata, _, [{:__aliases__, _, module}, _]}) do
    module
  end

  @spec extract_name({any(), any(), atom()} | [module()]) :: [module()]
  def extract_name({_, _, inner_name}), do: List.wrap(inner_name)
  def extract_name(module_chain) when is_list(module_chain), do: module_chain

  # credo:disable-for-lines:21 Credo.Check.Refactor.CyclomaticComplexity
  def default_type({{:., _, [_, :t]}, _, _} = struct_type), do: struct_type

  def default_value({type, _, _}) do
    case type do
      :float -> 0.0

      :number -> 0
      :integer -> 0

      :non_neg_integer -> 0
      :pos_integer -> 1

      :bitstring  -> ""
      :list -> []

      :map -> %{}

      :any -> nil
      atom -> atom
    end
  end
end
