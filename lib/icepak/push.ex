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
    hash = calculate_hash(hash_ref, full_path)

    combined_hashes =
      Enum.map(@combinations, fn {key, values} ->
        values = Enum.map(values, fn f -> Path.join(base_path, f) end)

        %{
          name: key,
          hash: calculate_hash(hash_ref, values)
        }
      end)

    [
      %{
        name: file,
        size: size,
        hash: hash,
        combined_hashes: combined_hashes
      },
      %{
        name: "lxd.tar.xz",
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
    hash = calculate_hash(hash_ref, Path.join(base_path, file))

    [
      %{
        name: file,
        size: size,
        hash: hash
      }
    ]
  end

  defp calculate_hash(hash_ref, files) when is_list(files) do
    files
    |> Enum.reduce(hash_ref, fn file, prev_ref ->
      file
      |> File.stream!([], 2048)
      |> Enum.reduce(prev_ref, fn chunk, ref ->
        :crypto.hash_update(ref, chunk)
      end)
    end)
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  defp calculate_hash(hash_ref, file) when is_binary(file) do
    file
    |> File.stream!([], 2048)
    |> Enum.reduce(hash_ref, fn chunk, prev_ref ->
      :crypto.hash_update(prev_ref, chunk)
    end)
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end
end
