require 'spec_helper'

describe BitbucketServer::Client do
  let(:options) { { base_uri: 'https://test:7990', user: 'bitbucket', password: 'mypassword' } }
  let(:project) { 'SOME-PROJECT' }
  let(:repo_slug) { 'my-repo' }

  subject { described_class.new(options) }

  describe '#pull_requests' do
    let(:path) { "/projects/#{project}/repos/#{repo_slug}/pull-requests?state=ALL" }

    it 'requests a collection' do
      expect(BitbucketServer::Paginator).to receive(:new).with(anything, path, :pull_request)

      subject.pull_requests(project, repo_slug)
    end

    it 'throws an exception when connection fails' do
      allow(BitbucketServer::Collection).to receive(:new).and_raise(OpenSSL::SSL::SSLError)

      expect { subject.pull_requests(project, repo_slug) }.to raise_error(described_class::ServerError)
    end
  end

  describe '#activities' do
    let(:path) { "/projects/#{project}/repos/#{repo_slug}/pull-requests/1/activities" }

    it 'requests a collection' do
      expect(BitbucketServer::Paginator).to receive(:new).with(anything, path, :activity)

      subject.activities(project, repo_slug, 1)
    end
  end

  describe '#repo' do
    let(:path) { "/projects/#{project}/repos/#{repo_slug}" }
    let(:url) { "https://test:7990/rest/api/1.0/projects/SOME-PROJECT/repos/my-repo" }

    it 'requests a specific repository' do
      stub_request(:get, url)

      subject.repo(project, repo_slug)

      expect(WebMock).to have_requested(:get, url)
    end
  end

  describe '#repos' do
    let(:path) { "/repos" }

    it 'requests a collection' do
      expect(BitbucketServer::Paginator).to receive(:new).with(anything, path, :repo)

      subject.repos
    end
  end

  describe '#create_branch' do
    let(:branch) { 'test-branch' }
    let(:sha) { '12345678' }
    let(:url) { 'https://test:7990/rest/api/1.0/projects/SOME-PROJECT/repos/my-repo/branches' }

    it 'requests Bitbucket to create a branch' do
      stub_request(:post, url)

      subject.create_branch(project, repo_slug, branch, sha)

      expect(WebMock).to have_requested(:post, url)
    end
  end

  describe '#delete_branch' do
    let(:branch) { 'test-branch' }
    let(:sha) { '12345678' }
    let(:url) { 'https://test:7990/rest/branch-utils/1.0/projects/SOME-PROJECT/repos/my-repo/branches' }

    it 'requests Bitbucket to create a branch' do
      stub_request(:delete, url)

      subject.delete_branch(project, repo_slug, branch, sha)

      expect(WebMock).to have_requested(:delete, url)
    end
  end
end
