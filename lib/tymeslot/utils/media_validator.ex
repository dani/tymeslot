defmodule Tymeslot.Utils.MediaValidator do
  @moduledoc """
  Utility for validating media files (images and videos) using magic bytes.
  """

  @doc """
  Validates if a binary is a supported image format using ExImageInfo.
  """
  def valid_image?(binary) when is_binary(binary) do
    case ExImageInfo.info(binary) do
      {mime, _width, _height, _type} when is_binary(mime) -> true
      _ -> false
    end
  end

  def valid_image?(_), do: false

  @doc """
  Validates if a binary is a supported video format using magic bytes.
  Supports MP4, WebM/MKV, and AVI.
  """
  def valid_video?(binary) when is_binary(binary) do
    # We only need the first 16 bytes for magic byte validation
    header = binary_part(binary, 0, min(byte_size(binary), 16))
    is_video_header?(header)
  end

  def valid_video?(_), do: false

  # MP4 / MOV: ftyp at offset 4
  defp is_video_header?(<<_::binary-size(4), "ftyp", _rest::binary>>), do: true
  
  # WebM / MKV: 1A 45 DF A3
  defp is_video_header?(<<0x1A, 0x45, 0xDF, 0xA3, _rest::binary>>), do: true
  
  # AVI: RIFF .... AVI 
  defp is_video_header?(<<"RIFF", _::binary-size(4), "AVI ", _rest::binary>>), do: true
  
  # MPEG Transport Stream: 0x47
  defp is_video_header?(<<0x47, _rest::binary>>), do: true

  # MPEG Program Stream: 00 00 01 BA or 00 00 01 B3
  defp is_video_header?(<<0x00, 0x00, 0x01, 0xBA, _rest::binary>>), do: true
  defp is_video_header?(<<0x00, 0x00, 0x01, 0xB3, _rest::binary>>), do: true

  # Flash Video: FLV
  defp is_video_header?(<<"FLV", _rest::binary>>), do: true

  defp is_video_header?(_), do: false

  @doc """
  Validates if a file at the given path is a supported image format.
  """
  def valid_image_file?(path) when is_binary(path) do
    with {:ok, file} <- File.open(path, [:read, :binary]),
         binary when is_binary(binary) <- IO.binread(file, 2048),
         :ok <- File.close(file) do
      valid_image?(binary)
    else
      _ -> false
    end
  end

  @doc """
  Validates if a file at the given path is a supported video format.
  """
  def valid_video_file?(path) when is_binary(path) do
    with {:ok, file} <- File.open(path, [:read, :binary]),
         binary when is_binary(binary) <- IO.binread(file, 2048),
         :ok <- File.close(file) do
      valid_video?(binary)
    else
      _ -> false
    end
  end

  @doc """
  Validates if a binary is either a valid image or a valid video.
  """
  def valid_media?(binary) do
    valid_image?(binary) || valid_video?(binary)
  end
end
