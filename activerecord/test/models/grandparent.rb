# frozen_string_literal: true

class Grandparent < ActiveRecord::Base
  has_one :parent, inverse_of: :grandparent, autosave: true
end
