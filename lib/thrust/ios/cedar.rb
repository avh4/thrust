class Thrust::IOS::Cedar

  def self.run(out, build_configuration, target, sdk, os, device, build_dir, app_config)
    if os == 'macosx'
      build_path = File.join(build_dir, build_configuration)
      app_dir = File.join(build_path, target)
      Thrust::Executor.check_command_for_failure("DYLD_FRAMEWORK_PATH=#{build_path.inspect} #{app_dir}")
    else
      simulator_binary = app_config['sim_binary']
      app_executable = File.join(build_dir, "#{build_configuration}-#{os}", "#{target}.app")

      if simulator_binary =~ /waxim%/
        Thrust::Executor.check_command_for_failure(%Q[#{simulator_binary} -s #{sdk} -f #{device} -e CFFIXED_USER_HOME=#{Dir.tmpdir} -e CEDAR_HEADLESS_SPECS=1 -e CEDAR_REPORTER_CLASS=CDRDefaultReporter #{app_executable}])
      elsif simulator_binary =~ /ios-sim$/
        Thrust::Executor.check_command_for_failure(%Q[#{simulator_binary} launch #{app_executable} --sdk #{sdk} --family #{device} --retina --tall --setenv CFFIXED_USER_HOME=#{Dir.tmpdir} --setenv CEDAR_HEADLESS_SPECS=1 --setenv CEDAR_REPORTER_CLASS=CDRDefaultReporter])
      else
        out.puts "Unknown binary for running specs: '#{simulator_binary}'"
        false
      end
    end
  end
end