defmodule Kronky.ChangesetParser do
  @moduledoc """
  Converts an ecto changeset into a list of validation errors structs.
  Currently *does not* support nested errors
  """

  import Ecto.Changeset, only: [traverse_errors: 2]
  alias Kronky.ValidationMessage

  @doc "Extract a nested map of raw errors from a changeset

  For examples, please see the test cases in the github repo.
  "
  def messages_as_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, & &1)
  end

  @doc "Generate a list of `Kronky.ValidationMessage` structs from changeset errors

  For examples, please see the test cases in the github repo.
  "
  def extract_messages(changeset) do
    changeset
    |> traverse_errors(&construct_traversed_message/3)
    |> Enum.to_list()
    |> Enum.flat_map(&handle_nested_errors/1)
  end

  defp handle_nested_errors({parent_field, values}) when is_map(values) do
    Enum.flat_map(values, fn {field, value} ->
      {construct_field(parent_field, field), value}
      |> handle_nested_errors()
    end)
  end

  defp handle_nested_errors({parent_field, values}) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {%ValidationMessage{} = value, _index} ->
        [%{value | field: parent_field}]

      {many_values, index} ->
        many_values
        |> Enum.flat_map(fn {field, values} ->
          {construct_field(parent_field, field, index: index), values}
          |> handle_nested_errors()
        end)
    end)
  end

  defp handle_nested_errors({_field, values}), do: values

  defp construct_traversed_message(_changeset, field, {message, opts}) do
    construct_message(field, {message, opts})
  end

  defp construct_field(parent_field, field, options \\ []) do
    :kronky
    |> Application.get_env(:field_constructor)
    |> apply(:error, [parent_field, field, options])
  end

  @doc "Generate a single `Kronky.ValidationMessage` struct from a changeset.

  This method is designed to be used with `Ecto.Changeset.traverse_errors` to generate a map of structs.

  ## Examples
    ```
    error_map = Changeset.traverse_errors(fn(changeset, field, error) ->
      Kronky.ChangesetParser.construct_message(field, error)
    end)
    error_list = Enum.flat_map(error_map, fn({_, messages}) -> messages end)

    ```
  "
  def construct_message(field, error_tuple)

  def construct_message(field, {message, opts}) do
    %ValidationMessage{
      code: to_code({message, opts}),
      field: construct_field(field, nil),
      key: field,
      template: message,
      message: interpolate_message({message, opts}),
      options: tidy_opts(opts)
    }
  end

  defp tidy_opts(opts) do
    Keyword.drop(opts, [:validation, :max, :is, :min, :code])
  end

  @doc """
  Inserts message variables into message.

  ## Examples

      iex> interpolate_message({"length should be between %{one} and %{two}", [one: "1", two: "2", three: "3"]})
      "length should be between 1 and 2"

  """
  # Code Taken from the Pheonix DataCase.on_errors/1 boilerplate"
  def interpolate_message({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      key_pattern = "%{#{key}}"

      if String.contains?(acc, key_pattern) do
        String.replace(acc, key_pattern, to_string(value))
      else
        acc
      end
    end)
  end

  @doc """
  Generate unique code for each validation type.

  Expects an array of validation options such as those supplied
  by `Ecto.Changeset.traverse_errors/2`, with the addition of a message key containing the message string.
  Messages are required for several validation types to be identified.

  ## Supported

  - :cast - generated by `Ecto.Changeset.cast/3`
  - :association - generated by `Ecto.Changeset.assoc_constraint/3`, `Ecto.Changeset.cast_assoc/3`, `Ecto.Changeset.put_assoc/3`,  `Ecto.Changeset.cast_embed/3`, `Ecto.Changeset.put_embed/3`
  - :acceptance - generated by `Ecto.Changeset.validate_acceptance/3`
  - :confirmation - generated by `Ecto.Changeset.validate_confirmation/3`
  - :length - generated by `Ecto.Changeset.validate_length/3` when the `:is` option fails validation
  - :min - generated by `Ecto.Changeset.validate_length/3` when the `:min` option fails validation
  - :max - generated by `Ecto.Changeset.validate_length/3` when the `:max` option fails validation
  - :less_than_or_equal_to - generated by `Ecto.Changeset.validate_length/3` when the `:less_than_or_equal_to` option fails validation
  - :less_than - generated by `Ecto.Changeset.validate_length/3` when the `:less_than` option fails validation
  - :greater_than_or_equal_to - generated by `Ecto.Changeset.validate_length/3` when the `:greater_than_or_equal_to` option fails validation
  - :greater_than - generated by `Ecto.Changeset.validate_length/3` when the `:greater_than` option fails validation
  - :equal_to - generated by `Ecto.Changeset.validate_length/3` when the `:equal_to` option fails validation
  - :exclusion - generated by `Ecto.Changeset.validate_exclusion/4`
  - :inclusion - generated by `Ecto.Changeset.validate_inclusion/4`
  - :required - generated by `Ecto.Changeset.validate_required/3`
  - :subset - generated by `Ecto.Changeset.validate_subset/4`
  - :unique - generated by `Ecto.Changeset.unique_constraint/3`
  - :foreign -  generated by `Ecto.Changeset.foreign_key_constraint/3`
  - :no_assoc_constraint -  generated by `Ecto.Changeset.no_assoc_constraint/3`
  - :unknown - supplied when validation cannot be matched. This will also match any custom errors added through
  `Ecto.Changeset.add_error/4`, `Ecto.Changeset.validate_change/3`, and `Ecto.Changeset.validate_change/4`

  """
  def to_code({message, opts}) do
    opts
    |> Enum.into(%{message: message})
    |> do_to_code
  end

  defp do_to_code(%{code: code}), do: code
  defp do_to_code(%{validation: :cast}), do: :cast
  defp do_to_code(%{validation: :required}), do: :required
  defp do_to_code(%{validation: :format}), do: :format
  defp do_to_code(%{validation: :inclusion}), do: :inclusion
  defp do_to_code(%{validation: :exclusion}), do: :exclusion
  defp do_to_code(%{validation: :subset}), do: :subset
  defp do_to_code(%{validation: :acceptance}), do: :acceptance
  defp do_to_code(%{validation: :confirmation}), do: :confirmation
  defp do_to_code(%{validation: :length, is: _}), do: :length
  defp do_to_code(%{validation: :length, min: _}), do: :min
  defp do_to_code(%{validation: :length, max: _}), do: :max

  defp do_to_code(%{validation: :number, message: message}) do
    cond do
      String.contains?(message, "less than or equal to") -> :less_than_or_equal_to
      String.contains?(message, "greater than or equal to") -> :greater_than_or_equal_to
      String.contains?(message, "less than") -> :less_than
      String.contains?(message, "greater than") -> :greater_than
      String.contains?(message, "equal to") -> :equal_to
      true -> :unknown
    end
  end

  defp do_to_code(%{message: "is invalid", type: _}), do: :association

  defp do_to_code(%{message: "has already been taken"}), do: :unique
  defp do_to_code(%{message: "does not exist"}), do: :foreign
  defp do_to_code(%{message: "is still associated with this entry"}), do: :no_assoc

  defp do_to_code(_unknown) do
    :unknown
  end
end
