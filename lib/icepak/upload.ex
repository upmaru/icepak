defmodule Icepak.Upload do
  alias Icepak.Polar

  require Logger

  def perform(items, options \\ []) do
    finch_name = Keyword.get(options, :finch, Icepak.Finch)

    uploadable_items =
      Enum.filter(items, fn item ->
        not is_nil(item.source)
      end)

    polar_client = Polar.authenticate()

    %{
      status: 200,
      body: %{
        "data" => %{
          "access_key_id" => access_key_id,
          "secret_access_key" => secret_access_key,
          "bucket" => bucket,
          "region" => region,
          "endpoint" => endpoint
        }
      }
    } = Polar.get_storage(polar_client)

    aws_client =
      access_key_id
      |> AWS.Client.create(secret_access_key, region)
      |> AWS.Client.put_endpoint(endpoint)
      |> AWS.Client.put_http_client({AWS.HTTPClient.Finch, [finch_name: finch_name]})

    aws_client =
      if aws_config = Application.get_env(:icepak, :aws) do
        %{aws_client | port: aws_config.port, proto: aws_config.proto}
      else
        aws_client
      end

    uploaded =
      Enum.map(uploadable_items, &handle_upload(&1, aws_client, bucket))

    if uploads_valid?(uploaded) do
      Logger.info("[Upload] All uploads are successful")
    else
      Logger.error("[Upload] Some uploads failed")
    end

    uploaded
  end

  @chunk_size 5_242_880

  def handle_upload(item, client, bucket) do
    {:ok,
     %{
       "InitiateMultipartUploadResult" => %{
         "UploadId" => upload_id
       }
     }, _} = AWS.S3.create_multipart_upload(client, bucket, item.path, %{})

    parts =
      item.source
      |> File.stream!([], @chunk_size)
      |> Stream.chunk_every(@chunk_size)
      |> Stream.with_index(1)
      |> Enum.map(fn {chunk, i} ->
        chunk = Enum.join(chunk)

        Logger.info("[Upload] Starting part #{i} of #{item.path}")

        {:ok, nil, %{headers: headers, status_code: 200}} =
          AWS.S3.upload_part(client, bucket, item.path, %{
            "Body" => chunk,
            "PartNumber" => i,
            "UploadId" => upload_id
          })

        {_, etag} = Enum.find(headers, fn {header, _} -> header in ["ETag", "etag"] end)

        %{"ETag" => etag, "PartNumber" => i}
      end)

    input = %{"CompleteMultipartUpload" => %{"Part" => parts}, "UploadId" => upload_id}

    Logger.info("[Upload] Done #{item.path}")

    AWS.S3.complete_multipart_upload(client, bucket, item.path, input)
  end

  defp uploads_valid?(uploads) do
    Enum.all?(uploads, fn {:ok, _, %{status_code: status}} -> status == 200 end)
  end
end
