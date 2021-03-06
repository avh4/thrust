class Thrust::IOS::XCodeTools
  ProvisioningProfileNotFound = Class.new(StandardError)

  def self.build_configurations(project_name) #TODO:  Backfill a test
    output = Thrust::Executor.capture_output_from_system("xcodebuild -project #{project_name}.xcodeproj -list")
    match = /Build Configurations:(.+?)\n\n/m.match(output)
    if match
      match[1].strip.split("\n").map { |line| line.strip }
    else
      []
    end
  end

  def initialize(out, build_configuration, build_directory, project_name)
    @out = out
    @git = Thrust::Git.new(out)
    @build_configuration = build_configuration
    @build_directory = build_directory
    @project_name = project_name
  end

  def change_build_number(build_number)
    Thrust::Executor.system_or_exit "agvtool new-version -all '#{build_number}'"
    @git.checkout_file('*.xcodeproj')
  end

  def cleanly_create_ipa(target, app_name, signing_identity, provision_search_query = nil)
    clean_build
    kill_simulator
    build_target(target, 'iphoneos')
    create_ipa(app_name, signing_identity, provision_search_query)
  end

  def build_configuration_directory
    "#{@build_directory}/#{@build_configuration}-iphoneos"
  end

  def clean_build
    @out.puts 'Cleaning...'
    run_xcode('clean')
    FileUtils.rm_rf(build_configuration_directory)
  end

  def clean_and_build_target(target, build_sdk)
    clean_build
    build_target(target, build_sdk)
  end

  private

  def build_target(target, build_sdk)
    @out.puts "Building..."
    run_xcode('build', build_sdk, target)
  end

  def kill_simulator
    @out.puts('Killing simulator...')
    Thrust::Executor.system %q[killall -m -KILL "gdb"]
    Thrust::Executor.system %q[killall -m -KILL "otest"]
    Thrust::Executor.system %q[killall -m -KILL "iPhone Simulator"]
  end

  def provision_path(provision_search_query)
    provision_search_path = File.expand_path("~/Library/MobileDevice/Provisioning Profiles/")
    command = %Q(grep -rl "#{provision_search_query}" "#{provision_search_path}")
    paths = `#{command}`.split("\n")
    paths.first or raise(ProvisioningProfileNotFound, "\nCouldn't find provisioning profiles matching #{provision_search_query}.\n\nThe command used was:\n\n#{command}")
  end

  def create_ipa(app_name, signing_identity, provision_search_query)
    @out.puts 'Packaging...'
    ipa_filename = "#{build_configuration_directory}/#{app_name}.ipa"
    cmd = [
        "xcrun",
        "-sdk iphoneos",
        "-v PackageApplication",
        "'#{build_configuration_directory}/#{app_name}.app'",
        "-o '#{ipa_filename}'",
        "--sign '#{signing_identity}'",
        "--embed '#{provision_path(provision_search_query)}'"
    ].join(' ')
    Thrust::Executor.system_or_exit(cmd)
    ipa_filename
  end


  def run_xcode(build_command, sdk = nil, target = nil)
    target_flag = target ? "-target #{target}" : "-alltargets"
    sdk_flag = sdk ? "-sdk #{sdk}" : ''

    Thrust::Executor.system_or_exit(
        [
            'set -o pipefail &&',
            'xcodebuild',
            "-project #{@project_name}.xcodeproj",
            target_flag,
            "-configuration #{@build_configuration}",
            sdk_flag,
            "#{build_command}",
            "SYMROOT=#{@build_directory.inspect}",
            '2>&1',
            "| grep -v 'backing file'"
        ].join(' '),
        output_file("#{@build_configuration}-#{build_command}")
    )
  end

  def output_file(target)
    output_dir = if ENV['IS_CI_BOX']
                   ENV['CC_BUILD_ARTIFACTS']
                 else
                   File.exists?(@build_directory) ? @build_directory : FileUtils.mkdir_p(@build_directory)
                 end

    File.join(output_dir, "#{target}.output").tap { |file| @out.puts "Output: #{file}" }
  end
end
