module Win32
  class Service
    def self.exists?(file)
      return false
    end

    def self.status(svc)
      ServiceStub.new()
    end
  end
end

class ServiceStub
  @@stubbed_state = 'stopped'

  def current_state
    @@stubbed_state
  end
end

describe 'teamcity::agent_windows' do
  describe 'no attributes set' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'windows', version: '2008R2').converge(described_recipe)
    end

    it 'errors out when no server_url has been set' do
      expect { chef_run }.to raise_error(RuntimeError)
    end
  end

  describe 'server_url attribute set' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'windows', version: '2012R2') do |node|
        node.override['teamcity']['agents']['server_url'] = 'http://teamcity.example.com'
        node.override['java']['java_home'] = 'C:/Program Files/Java'
        node.override['teamcity']['agents']['name'] = 'TEST'
        node.default['teamcity']['agents']['user'] = 'teamcity'
        node.default['teamcity']['agents']['home'] = nil
        node.default['teamcity']['agents']['system_dir'] = '.'
        @home = node['teamcity']['agents']['home'] || File.join('', 'home', node['teamcity']['agents']['user'])
        @system_dir = File.expand_path node['teamcity']['agents']['system_dir'], @home
      end.converge(described_recipe)
    end

    let(:downloaded_zip_path) do
      # MD5('http://teamcity.example.com') == 695a5dd62c1bd0ffb5b45bbb8328ab84
      # /var/chef/cache/teamcity-agent-695a5dd62c1bd0ffb5b45bbb8328ab84.zip
      File.join(Chef::Config[:file_cache_path],
        'teamcity-agent-695a5dd62c1bd0ffb5b45bbb8328ab84.zip')
    end

    before(:each) do
      allow(File).to receive(:exists?)
        .with('/home/teamcity/bin')
        .and_return(false)
    end

    it 'does not error out when server_url has been set' do
      expect { chef_run }.to_not raise_error
    end

    it 'creates the agent install directory recursively' do
      expect(chef_run).to create_directory('/home/teamcity').with(recursive: true)
    end

    it 'downloads the agent zip file' do
      expect(chef_run).to create_remote_file_if_missing(downloaded_zip_path).with(
        source: 'http://teamcity.example.com/update/buildAgent.zip')
    end

    it 'unzips the agent zip file' do
      expect(chef_run).to unzip_windows_zipfile('/home/teamcity')
    end

    it 'create the buildagent.properties file' do
      expect(chef_run).to create_template('/home/teamcity/conf/buildAgent.properties').with(
        source: 'buildAgent.properties.erb')
    end

    it 'creates a the service wrapper conf' do
      expect(chef_run).to create_template('/home/teamcity/launcher/conf/wrapper.conf').with(
        source: 'wrapper.conf.erb',
        variables: { name: 'TEST', java_exe: 'C:/Program Files/Java/bin/java.exe' })
    end
  end
end
