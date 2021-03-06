defmodule Cadet.Course do
  @moduledoc """
  Course context contains domain logic for Course administration
  management such as discussion groups and materials
  """
  use Cadet, :context

  import Ecto.Query

  alias Cadet.{Accounts, Accounts.User}
  alias Cadet.Course.{Group, Sourcecast, SourcecastUpload}

  @upload_file_roles ~w(admin staff)a
  @get_overviews_role ~w(staff admin)a

  @doc """
  Get a group based on the group name or create one if it doesn't exist
  """
  @spec get_or_create_group(String.t()) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t()}
  def get_or_create_group(name) when is_binary(name) do
    Group
    |> where(name: ^name)
    |> Repo.one()
    |> case do
      nil ->
        %Group{}
        |> Group.changeset(%{name: name})
        |> Repo.insert()

      group ->
        {:ok, group}
    end
  end

  @doc """
  Updates a group based on the group name or create one if it doesn't exist
  """
  @spec insert_or_update_group(map()) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t()}
  def insert_or_update_group(params = %{name: name}) when is_binary(name) do
    Group
    |> where(name: ^name)
    |> Repo.one()
    |> case do
      nil ->
        Group.changeset(%Group{}, params)

      group ->
        Group.changeset(group, params)
    end
    |> Repo.insert_or_update()
  end

  @doc """
  Returns a list of groups containing information on the each group's id, avenger name and group name
  """
  @type group_overview :: %{id: integer, avenger_name: String.t(), name: String.t()}

  @spec get_group_overviews(%User{}) :: [group_overview]
  def get_group_overviews(_user = %User{role: role}) do
    if role in @get_overviews_role do
      overviews =
        Group
        |> Repo.all()
        |> Enum.map(fn group_info -> get_group_info(group_info) end)

      {:ok, overviews}
    else
      {:error, {:unauthorized, "Unauthorized"}}
    end
  end

  defp get_group_info(group_info) do
    %{
      id: group_info.id,
      avenger_name: Accounts.get_user(group_info.leader_id).name,
      name: group_info.name
    }
  end

  # @doc """
  # Reassign a student to a discussion group
  # This will un-assign student from the current discussion group
  # """
  # def assign_group(leader = %User{}, student = %User{}) do
  #   cond do
  #     leader.role == :student ->
  #       {:error, :invalid}

  #     student.role != :student ->
  #       {:error, :invalid}

  #     true ->
  #       Repo.transaction(fn ->
  #         {:ok, _} = unassign_group(student)

  #         %Group{}
  #         |> Group.changeset(%{})
  #         |> put_assoc(:leader, leader)
  #         |> put_assoc(:student, student)
  #         |> Repo.insert!()
  #       end)
  #   end
  # end

  # @doc """
  # Remove existing student from discussion group, no-op if a student
  # is unassigned
  # """
  # def unassign_group(student = %User{}) do
  #   existing_group = Repo.get_by(Group, student_id: student.id)

  #   if existing_group == nil do
  #     {:ok, nil}
  #   else
  #     Repo.delete(existing_group)
  #   end
  # end

  # @doc """
  # Get list of students under staff discussion group
  # """
  # def list_students_by_leader(staff = %User{}) do
  #   import Cadet.Course.Query, only: [group_members: 1]

  #   staff
  #   |> group_members()
  #   |> Repo.all()
  #   |> Repo.preload([:student])
  # end

  @doc """
  Upload a sourcecast file
  """
  def upload_sourcecast_file(uploader = %User{role: role}, attrs = %{}) do
    if role in @upload_file_roles do
      changeset =
        %Sourcecast{}
        |> Sourcecast.changeset(attrs)
        |> put_assoc(:uploader, uploader)

      Repo.insert(changeset)
    else
      {:error, {:forbidden, "User is not permitted to upload"}}
    end
  end

  @doc """
  Delete a sourcecast file
  """
  def delete_sourcecast_file(_deleter = %User{role: role}, id) do
    if role in @upload_file_roles do
      sourcecast = Repo.get(Sourcecast, id)
      SourcecastUpload.delete({sourcecast.audio, sourcecast})
      Repo.delete(sourcecast)
    else
      {:error, {:forbidden, "User is not permitted to delete"}}
    end
  end
end
