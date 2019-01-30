# frozen_string_literal: true

# Take a signed permanent reference for a blob and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob references, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::BlobsController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob

  def show
    unless Rails.env.test? && ActiveStorage.disable_cache_for_tests
      expires_in ActiveStorage.service_urls_expire_in
    end
    redirect_to @blob.service_url(disposition: params[:disposition])
  end
end
