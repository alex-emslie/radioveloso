# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
        key      = SecureRandom.base58(24)
        data     = "Something else entirely!"
        checksum = Digest::MD5.base64digest(data)
        direct_upload = @service.direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

        uri = URI.parse direct_upload.url
        request = Net::HTTP::Put.new uri.request_uri
        request.body = data
        direct_upload.headers.each { |k, v| request.add_field k, v }
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request request
        end

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "signed URL generation" do
      url = @service.url(@key, expires_in: 5.minutes,
        disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws.com.*response-content-disposition=inline.*avatar\.png.*response-content-type=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], url
    end

    test "uploading with server-side encryption" do
      config  = SERVICE_CONFIGURATIONS.deep_merge(s3: { upload: { server_side_encryption: "AES256" } })
      service = ActiveStorage::Service.configure(:s3, config)

      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert_equal "AES256", service.bucket.object(key).server_side_encryption
      ensure
        service.delete key
      end
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
