# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::BaseController, type: :controller do
  controller(Api::BaseController) do
    def success_action
      render_success({ message: 'ok' })
    end

    def failure_action
      render_failure('invalid data')
    end

    def record_not_found_action
      raise ActiveRecord::RecordNotFound, 'Item with ID 999 not found'
    end

    def param_missing_action
      params.require(:name)
    end
  end

  before do
    routes.draw do
      get 'success_action' => 'api/base#success_action'
      get 'failure_action' => 'api/base#failure_action'
      get 'record_not_found_action' => 'api/base#record_not_found_action'
      post 'param_missing_action' => 'api/base#param_missing_action'
    end
  end

  describe '#render_success' do
    it 'renders JSON with success: true and data' do
      get :success_action
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']).to eq({ 'message' => 'ok' })
      expect(json['errors']).to be_nil
    end
  end

  describe '#render_failure' do
    it 'renders JSON with success: false and errors' do
      get :failure_action
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['data']).to be_nil
      expect(json['errors']).to eq('invalid data')
    end
  end

  describe 'centralized rescue_from' do
    it 'rescues ActiveRecord::RecordNotFound with 404' do
      get :record_not_found_action
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['errors']).to eq(I18n.t('errors.not_found'))
    end

    it 'rescues ActionController::ParameterMissing with 400' do
      post :param_missing_action
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['errors']).to include('param is missing')
    end
  end
end
