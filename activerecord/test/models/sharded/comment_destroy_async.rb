# frozen_string_literal: true

module Sharded
  class CommentDestroyAsync < ActiveRecord::Base
    self.table_name = :sharded_comments
    query_constraints :blog_id, :id

    belongs_to :blog_post, dependent: :destroy_async, query_constraints: [:blog_id, :blog_post_id], class_name: "Sharded::BlogPostDestroyAsync", optional: true
    belongs_to :blog_post_by_id, class_name: "Sharded::BlogPostDestroyAsync", foreign_key: :blog_post_id, optional: true
    belongs_to :blog, optional: true
  end
end
