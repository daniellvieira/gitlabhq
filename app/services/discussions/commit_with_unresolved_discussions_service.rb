module Discussions
  class CommitWithUnresolvedDiscussionsService < Discussions::BaseService
    def execute(merge_request)
      @merge_request = merge_request

      cached_commit || create_commit
    end

    private

    def update_actions
      @update_actions ||= UpdateActions.new(@merge_request)
    end

    def cache_key
      @cache_key ||= [
        'merge-request',
        @merge_request.id,
        'update-actions',
        update_actions.cache_key
      ]
    end

    def cached_commit
      return if Rails.env.development?

      commit_sha = Rails.cache.read(cache_key)
      commit_sha && project.commit(commit_sha)
    end

    def create_commit
      return unless @merge_request.source_branch_exists?

      commit_sha = repository.multi_action(
        @merge_request.author,
        branch_name: nil, # We just want a commit, not a branch
        message: commit_message,
        start_branch_name: @merge_request.source_branch,
        start_project: @merge_request.source_project,
        actions: update_actions.actions
      )
      return unless commit_sha

      Rails.cache.write(cache_key, commit_sha)

      project.commit(commit_sha)
    end

    def commit_message
      <<~MSG
        FIXME: Add code comments for unresolved discussions

        This patch adds a code comment for every unresolved discussion on the
        latest version of the diff of #{@merge_request.to_reference(full: true)}.

        This commit was automatically generated by GitLab. Don't forget to
        remove it from the merge request source branch before it is merged.
      MSG
    end
  end
end
