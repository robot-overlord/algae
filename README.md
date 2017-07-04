![](https://github.com/robot-overlord/algae/blob/master/brand/logo.png?raw=true)

[![Build Status](https://travis-ci.org/expede/algae.svg?branch=master)](https://travis-ci.org/expede/algae) [![Inline docs](http://inch-ci.org/github/expede/algae.svg?branch=master)](http://inch-ci.org/github/expede/algae) [![Deps Status](https://beta.hexfaktor.org/badge/all/github/expede/algae.svg)](https://beta.hexfaktor.org/github/expede/algae) [![hex.pm version](https://img.shields.io/hexpm/v/algae.svg?style=flat)](https://hex.pm/packages/algae) [![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](http://hexdocs.pm/algae/) [![license](https://img.shields.io/github/license/mashape/apistatus.svg?maxAge=2592000)](https://github.com/expede/algae/blob/master/LICENSE)

# TL;DR
Algae is a library for defining algebraic data types, and collection of common data structures.

# Quickstart
Add Algae to your list of dependencies in `mix.exs`:

```elixir

def deps do
  [{:algae, "~> 1.0"}]
end

```

# Product Builder
Build a product type

Includes:

* Struct
* Type definition
* Constructor function (for piping and defaults)
* Implicit defaults for simple values

## Definition

For convenveniece, several variants of the DSL are available.

### Standard

    defmodule Player do
      # =============== #
      # Data Definition #
      # =============== #

      defdata do
        name       :: String.t()
        hit_points :: non_neg_integer()
        experience :: non_neg_integer()
      end

      # =================== #
      #    Rest of Module   #
      # (business as usual) #
      # =================== #

      @spec attack(t(), t()) :: {t(), t()}
      def attack(%{experience: xp} = player, %{hit_points: hp} = target) do
        {
          %{player | experience: xp + 50},
          %{target | hit_points: hp - 10}
        }
      end
    end

    #=> %Player{name: "Sir Bob", hit_points: 10, experience: 500}

### Single Field Shorthand

Without any fields specified, Algae will default to a single field with
the same name as the module (essentially a "wrapper type"). You must still
provide the type for this field, however.

Embedded in another module:

    defmodule Id do
      defdata any()
    end

    %Id{}
    #=> %Id{id: nil}

Standalone:

    defdata Wrapper :: any()

    %Wrapper{}
    #=> %Wrapper{wrapper: nil}

## Constructor

A helper function, especially useful for piping. The order of arguments is
the same as the order that they are defined in.

    defmodule Person do
      defdata do
        name :: String.t()
        age  :: non_neg_integer()
      end
    end

    Person.new("Rachel Weintraub")
    #=> %Person{
    #     name: "Rachel Weintraub",
    #     age:  0
    #   }

### Constructor Defaults

Fields will automatically default to a sensible value (a typical "zero" for
that datatype). For example, `non_neg_integer()` will default to `0`,
and `String.t()` will default to `""`.

You may also overwrite these defaults with the `\\\\` syntax.

    defmodule Pet do
      defdata do
        name      :: String.t()
        leg_count :: non_neg_integer() \\\\ 4
      end
    end

    Pet.new("Crookshanks")
    #=> %Pet{
    #     name: "Crookshanks",
    #     leg_count: 4
    #   }

    Pet.new("Paul the Psychic Octopus", 8)
    #=> %Pet{
    #     name: "Paul the Psychic Octopus",
    #     leg_count: 8
    #   }

This overwriting syntax is _required_ for complex types:

    defdata Grocery do
      item :: {String.t(), integer(), boolean()} \\\\ {"Apple", 4, false}
    end

    Grocery.new()
    #=> %Grocery{
    #     item: {"Apple", 4, false}
    #   }

### Overwrite Constructor

The `new` constructor function may be overwritten.

    defmodule Constant do
      defdata :: fun() \\\\ fn _ -> nil end

      def new(value), do: %Constant{constant: fn _ -> value end}
    end

    fourty_two = Constant.new(42)
    fourty_two.constant.(33)
    #=> 42

## Empty Tag

An empty type (with no fields) is definable using the `none`() type

    defmodule Nothing do
      defdata :: none()
    end

    Nothing.new()
    #=> %Nothing{}

# Sum Builder

Build a sum (coproduct) type from product types

    defmodule Light do
      # ============== #
      # Sum Definition #
      # ============== #

      defsum do
        defdata Red    :: none()
        defdata Yellow :: none()
        defdata Green  :: none()
      end

      # =================== #
      #    Rest of Module   #
      # (business as usual) #
      # =================== #

      def from_number(1), do: %Light.Red{}
      def from_number(2), do: %Light.Yellow{}
      def from_number(3), do: %Light.Green{}
    end

    Light.new()
    #=> %Light.Red{}

## Embedded Products

Data with multiple fileds can be defined directly as part of a sum

    defmodule Pet do
      defsum do
        defdata Cat do
          name :: String.t()
          claw_sharpness :: String.t()
        end

        defdata Dog do
          name :: String.t()
          bark_loudness :: non_neg_integer()
        end
      end
    end

## Default Constructor

The first `defdata`'s constructor will be the default constructor for the sum

    defmodule Maybe do
      defsum do
        defdata Nothing :: none()
        defdata Just    :: any()
      end
    end

    Maybe.new()
    #=> %Maybe.Nothing{}

## Tagged Unions

Sums join existing types with tags: new types to help distibguish the context
that they are in (the sum type)

    defdata Book  :: String.t() \\\\ "War and Peace"
    defdata Video :: String.t() \\\\ "2001: A Space Odyssey"

    defmodule Media do
      defsum do
        defdata Paper :: Book.t()
        defdata Film  :: Video.t() \\\\ Video.new("A Clockwork Orange")
      end
    end

    media = Media.new()
    #=> %Paper{
    #      paper: %Book{
    #        book: "War and Peace"
    #      }
    #   }
