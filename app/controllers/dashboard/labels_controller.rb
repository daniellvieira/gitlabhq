# frozen_string_literal: true

class Dashboard::LabelsController < Dashboard::ApplicationController
  feature_category :issue_tracking

  def index
    respond_to do |format|
      format.json { render json: LabelSerializer.new.represent_appearance(labels) }
    end
  end

  def labels
    finder_params = { project_ids: projects.select(:id) }
    labels = LabelsFinder.new(current_user, finder_params).execute

    GlobalLabel.build_collection(labels)
  end
end
