# frozen_string_literal: true

class ActiveStorage::TransformJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :exponentially_longer

  def perform(blob, transformations)
    blob.variant(transformations).process
  end
end
