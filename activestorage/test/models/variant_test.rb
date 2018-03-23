# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_support/testing/method_call_assertions"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  test "resized variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100").processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100", monochrome: true).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end

  test "center-weighted crop of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(combine_options: {
      gravity: "center",
      resize: "100x100^",
      crop: "100x100+0+0",
    }).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 100, image.height
  end

  test "resized variation of PSD blob" do
    blob = create_file_blob(filename: "icon.psd", content_type: "image/vnd.adobe.photoshop")
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.service_url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of ICO blob" do
    blob = create_file_blob(filename: "favicon.ico", content_type: "image/vnd.microsoft.icon")
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.service_url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "optimized variation of GIF blob" do
    blob = create_file_blob(filename: "image.gif", content_type: "image/gif")

    assert_nothing_raised do
      blob.variant(layers: "Optimize").processed
    end
  end

  test "variation of invariable blob" do
    assert_raises ActiveStorage::InvariableError do
      create_file_blob(filename: "report.pdf", content_type: "application/pdf").variant(resize: "100x100")
    end
  end

  test "service_url doesn't grow in length despite long variant options" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(font: "a" * 10_000).processed
    assert_operator variant.service_url.length, :<, 525
  end

  test "urls allow for custom options" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "600x600")

    options = [
      variant.key,
      expires_in: blob.service.url_expires_in,
      disposition: :inline,
      content_type: blob.content_type,
      filename: blob.filename,
      thumb_size: "300x300",
      thumb_mode: "crop"
    ]
    assert_called_with(blob.service, :url, options) do
      variant.service_url(thumb_size: "300x300", thumb_mode: "crop")
    end
  end
end
