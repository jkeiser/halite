require 'spec_helper'
require 'halite/converter/libraries'

describe Halite::Converter::Libraries do

  describe '#generate' do
    let(:data) { '' }
    let(:entry_point) { false }
    let(:cookbook_dependencies) { [] }
    subject { described_class.generate(double(name: 'mygem', cookbook_dependencies: cookbook_dependencies.map {|dep| Halite::Dependencies::Dependency.new(dep, nil, :dependencies) }), data, entry_point) }

    context 'with a single require' do
      let(:data) { "x = 1\nrequire 'mygem/version'\n" }
      it { is_expected.to eq <<-EOH }
if ENV['HALITE_LOAD']; x = 1
require_relative 'mygem__version'
end
EOH
    end # /context with a single require

    context 'with two requires' do
      let(:data) { "require 'mygem/foo/bar'\nrequire 'another'" }
      it { is_expected.to eq <<-EOH }
if ENV['HALITE_LOAD']; require_relative 'mygem__foo__bar'
require 'another'
end
EOH
    end # /context with two requires

    context 'with an entry point' do
      let(:data) { "x = 1\nrequire 'mygem/version'\n" }
      let(:entry_point) { true }
      it { is_expected.to eq <<-EOH }
ENV['HALITE_LOAD'] = '1'; begin; x = 1
require_relative 'mygem__version'
ensure; ENV.delete('HALITE_LOAD'); end
EOH
    end # /context with an entry point

    context 'with a big script' do
      let(:data) { <<-EOH }
require 'mygem/something'
require 'mygem/utils'
require 'activesupport' # ಠ_ಠ
class Resource
  attribute :source
end
EOH
      it { is_expected.to eq <<-EOH }
if ENV['HALITE_LOAD']; require_relative 'mygem__something'
require_relative 'mygem__utils'
require 'activesupport' # ಠ_ಠ
class Resource
  attribute :source
end
end
EOH
    end # /context with a big script

    context 'with external dependencies' do
      let(:cookbook_dependencies) { ['other'] }
      let(:data) { <<-EOH }
require 'mygem/something'
require 'mygem/utils'
require "mygem"
require 'other'
class Resource
  attribute :source
end
EOH
      it { is_expected.to eq <<-EOH }
if ENV['HALITE_LOAD']; require_relative 'mygem__something'
require_relative 'mygem__utils'
require_relative 'mygem'
require_relative '../../other/libraries/other'
class Resource
  attribute :source
end
end
EOH
    end # /context with a big script
  end # /describe #generate

  describe '#write' do
    let(:library_files) { [] }
    let(:output) { [] }
    let(:spec) do
      spec = double(name: 'mygem')
      allow(spec).to receive(:each_library_file) do |&block|
        library_files.each {|path| block.call(File.join('/source', path), path) }
      end
      spec
    end
    before do
      first = true
      library_files.each do |path|
        input_sentinel = double("content of #{path}")
        output_sentinel = double("generated output for #{path}")
        allow(IO).to receive(:read).with(File.join('/source', path)).and_return(input_sentinel)
        allow(described_class).to receive(:generate).with(spec, input_sentinel, first).and_return(output_sentinel)
        first = false
        output << output_sentinel
      end
      allow(File).to receive(:directory?).and_return(false) # Always blank
    end

    context 'with a single file' do
      let(:library_files) { ['mygem.rb'] }

      it 'writes a single file' do
        expect(Dir).to receive(:mkdir).with('/test/libraries')
        expect(IO).to receive(:write).with('/test/libraries/mygem.rb', output[0])
        described_class.write(spec, '/test')
      end
    end # /context with a single file

    context 'with multiple files' do
      let(:library_files) { ['mygem.rb', 'mygem/one.rb', 'mygem/two.rb'] }

      it 'writes multiple files' do
        expect(Dir).to receive(:mkdir).with('/test/libraries')
        expect(IO).to receive(:write).with('/test/libraries/mygem.rb', output[0])
        expect(IO).to receive(:write).with('/test/libraries/mygem__one.rb', output[1])
        expect(IO).to receive(:write).with('/test/libraries/mygem__two.rb', output[2])
        described_class.write(spec, '/test')
      end
    end # /context with multiple files

    context 'with an explicit entry point name' do
      let(:library_files) { ['mygem.rb', 'other.rb'] }

      it 'selects the correct entry point' do
        expect(Dir).to receive(:mkdir).with('/test/libraries')
        expect(IO).to receive(:write).with('/test/libraries/mygem.rb', output[0])
        expect(IO).to receive(:write).with('/test/libraries/other.rb', output[1])
        described_class.write(spec, '/test', 'mygem')
      end
    end # /context with an explicit entry point name

    context 'with an explicit entry point name ending in .rb' do
      let(:library_files) { ['mygem.rb', 'other.rb'] }

      it 'selects the correct entry point' do
        expect(Dir).to receive(:mkdir).with('/test/libraries')
        expect(IO).to receive(:write).with('/test/libraries/mygem.rb', output[0])
        expect(IO).to receive(:write).with('/test/libraries/other.rb', output[1])
        described_class.write(spec, '/test', 'mygem.rb')
      end
    end # /context with an explicit entry point name

  end # /describe #write
end
