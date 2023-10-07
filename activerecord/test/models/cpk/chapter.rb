# frozen_string_literal: true

module Cpk
  class Chapter < ActiveRecord::Base
    self.table_name = :cpk_chapters
    # explicit definition is to allow schema definition to be simplified
    # to be shared between different databases
    self.primary_key = [:author_id, :id]

    belongs_to :book, query_constraints: [:author_id, :book_id], optional: true
  end
end
