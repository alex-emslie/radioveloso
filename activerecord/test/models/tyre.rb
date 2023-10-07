# frozen_string_literal: true

class Tyre < ActiveRecord::Base
  belongs_to :car, optional: true

  def self.custom_find(id)
    find(id)
  end

  def self.custom_find_by(*args)
    find_by(*args)
  end
end
