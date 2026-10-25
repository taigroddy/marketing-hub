# frozen_string_literal: true

class ConfirmationsController < ApplicationController
  def show
    @token = params[:token]
  end
end
