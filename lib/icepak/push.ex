defmodule Icepak.Push do
  @combinations %{
    "combined_squashfs_sha256" => ["incus.tar.xz", "rootfs.squashfs"]
  }

  def perform(options) do
    base_path = Path.expand(Keyword.fetch!(options, :path))

    File.ls!(base_path)
    |> Enum.flat_map(&prepare_item(&1, base_path))
    |> IO.inspect()
  end

  defp prepare_item("incus.tar.xz" = file, base_path) do
    hash_ref = :crypto.hash_init(:sha256)
    full_path = Path.join(base_path, file)
    %{size: size} = File.stat!(full_path)

    hash =
      full_path
      |> calculate_hash(hash_ref)
      |> finalize_hash()

    combined_hashes =
      Enum.map(@combinations, fn {key, values} ->
        files = Enum.map(values, fn f -> Path.join(base_path, f) end)

        %{
          name: key,
          hash:
            files
            |> Enum.reduce(hash_ref, &calculate_hash/2)
            |> finalize_hash()
        }
      end)

    [
      %{
        name: file,
        file_type: "incus.tar.xz",
        size: size,
        hash: hash,
        combined_hashes: combined_hashes
      },
      %{
        name: "lxd.tar.xz",
        file_type: "lxd.tar.xz",
        size: size,
        hash: hash,
        combined_hashes: combined_hashes
      }
    ]
  end

  defp prepare_item("rootfs.squashfs" = file, base_path) do
    hash_ref = :crypto.hash_init(:sha256)
    full_path = Path.join(base_path, file)
    %{size: size} = File.stat!(full_path)

    hash =
      full_path
      |> calculate_hash(hash_ref)
      |> finalize_hash()

    [
      %{
        name: "root.squashfs",
        file_type: "squashfs",
        size: size,
        hash: hash
      }
    ]
  end

  defp calculate_hash(file, hash_ref) do
    file
    |> File.stream!([], 2048)
    |> Enum.reduce(hash_ref, fn chunk, prev_ref ->
      :crypto.hash_update(prev_ref, chunk)
    end)
  end

  defp finalize_hash(hash) do
    hash
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end
end
