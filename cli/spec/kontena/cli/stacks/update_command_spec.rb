require_relative "../../../spec_helper"
require "kontena/cli/stacks/update_command"

describe Kontena::Cli::Stacks::UpdateCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['stack-name'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['stack-name'])
    end

    it 'sends stack to master' do
      stack = {
        'name' => 'stack-a',
        'services' => []
      }
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-a', stack
      )
      subject.run(['stack-a'])
    end

    it 'allows to override stack name' do
      stack = {
        'name' => 'stack-a',
        'services' => []
      }
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      stack_b = stack
      stack_b[:name] = 'stack-b'
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-b', stack
      )
      subject.run(['stack-b'])
    end
  end
end
