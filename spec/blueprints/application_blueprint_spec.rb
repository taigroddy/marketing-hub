# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationBlueprint do
  let(:blueprint_class) do
    Class.new(ApplicationBlueprint) do
      fields :id, :name
    end
  end

  it 'inherits from Blueprinter::Base' do
    expect(ApplicationBlueprint < Blueprinter::Base).to be true
  end

  it 'serializes objects to JSON' do
    entity = Struct.new(:id, :name).new(123, 'Test Object')
    json = blueprint_class.render(entity)
    expect(JSON.parse(json)).to eq('id' => 123, 'name' => 'Test Object')
  end
end
