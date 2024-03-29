defmodule Icepak.Item do
  @derive Jason.Encoder

  defstruct name: "",
            file_type: "",
            size: 0,
            hash: "",
            path: "",
            source: nil,
            is_metadata: false,
            combined_hashes: []

  @combinations %{
    "combined_squashfs_sha256" => ["incus.tar.xz", "rootfs.squashfs"],
    "combined_disk-kvm-img_sha256" => ["incus.tar.xz", "disk.qcow2"]
  }

  @file_types %{
    "rootfs.squashfs" => "squashfs",
    "disk.qcow2" => "disk-kvm.img"
  }

  defmodule Hash do
    defstruct [:name, :hash]

    @type t :: %__MODULE__{
            name: String.t(),
            hash: String.t()
          }
  end

  @type t :: %__MODULE__{
          name: String.t(),
          file_type: String.t(),
          size: integer(),
          hash: String.t(),
          path: String.t(),
          source: String.t() | nil,
          is_metadata: boolean(),
          combined_hashes: [
            Hash.t()
          ]
        }

  def prepare("incus.tar.xz" = file, %{base_path: base_path, storage_path: storage_path}) do
    hash_ref = :crypto.hash_init(:sha256)
    full_path = Path.join(base_path, file)
    %{size: size} = File.stat!(full_path)

    storage_path = Path.join(storage_path, file)

    hash =
      full_path
      |> calculate_hash(hash_ref)
      |> finalize_hash()

    combined_hashes =
      @combinations
      |> Enum.filter(fn {_name, values} ->
        Enum.all?(values, fn f -> File.exists?(Path.join(base_path, f)) end)
      end)
      |> Enum.map(fn {key, values} ->
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
      %__MODULE__{
        name: file,
        file_type: "incus.tar.xz",
        size: size,
        hash: hash,
        path: storage_path,
        source: full_path,
        is_metadata: true,
        combined_hashes: combined_hashes
      },
      %__MODULE__{
        name: "lxd.tar.xz",
        file_type: "lxd.tar.xz",
        size: size,
        hash: hash,
        path: storage_path,
        is_metadata: true,
        combined_hashes: combined_hashes
      }
    ]
  end

  def prepare(file, %{base_path: base_path, storage_path: storage_path}) do
    hash_ref = :crypto.hash_init(:sha256)
    full_path = Path.join(base_path, file)
    %{size: size} = File.stat!(full_path)

    storage_path = Path.join(storage_path, file)

    hash =
      full_path
      |> calculate_hash(hash_ref)
      |> finalize_hash()

    file_type = Map.fetch!(@file_types, file)

    [
      %__MODULE__{
        name: file,
        file_type: file_type,
        size: size,
        hash: hash,
        path: storage_path,
        source: full_path
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
