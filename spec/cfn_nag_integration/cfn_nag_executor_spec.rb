# frozen_string_literal: true
require 'spec_helper'
require 'cfn-nag/cfn_nag_logging'
require 'cfn-nag/cfn_nag_executor'

describe CfnNagExecutor do
  # Method of suppressing stderr and stdout was found on StackOverflow here:
  # https://stackoverflow.com/a/22777806
  original_stderr = nil
  original_stdout = nil

  before(:all) do
    CfnNagLogging.configure_logging(debug: false)
    @default_cli_options = {
      allow_suppression: true,
      debug: false,
      isolate_custom_rule_exceptions: false,
      print_suppression: false,
      rule_directory: nil,
      template_pattern: '..*\.json|..*\.yaml|..*\.yml|..*\.template',
      output_format: 'json',
      rule_repository: []
    }

    original_stderr = $stderr  # capture previous value of $stderr
    original_stdout = $stdout  # capture previous value of $stdout
    $stderr = StringIO.new     # assign a string buffer to $stderr
    $stdout = StringIO.new     # assign a string buffer to $stdout
    # $stderr.string             # return the contents of the string buffer if needed
    # $stdout.string             # return the contents of the string buffer if needed
  end

  after(:all) do
    $stderr = original_stderr  # restore $stderr to its previous value
    $stdout = original_stdout  # restore $stdout to its previous value
  end

  context 'single file cfn_nag with fail on warnings' do
    it 'returns a nonzero exit code' do
      test_file = 'spec/test_templates/yaml/ec2_subnet/ec2_subnet_map_public_ip_on_launch_true_boolean.yml'

      cli_options = @default_cli_options.clone
      cli_options[:fail_on_warnings] = true
      expect(Options).to receive(:file_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:argf_read).and_return(IO.read(test_file))
      expect(cfn_nag_executor).to receive(:argf_close).and_return(nil)
      expect(cfn_nag_executor).to receive(:argf_finished?).and_return(false, true)
      expect(cfn_nag_executor).to receive(:argf_filename).and_return(test_file)

      result = cfn_nag_executor.scan(options_type: 'file')
      expect(result).to eq 1
    end
  end

  context 'multi file cfn_nag with fail on warnings' do
    it 'returns a nonzero exit code' do
      test_file1 = 'spec/test_templates/yaml/ec2_subnet/ec2_subnet_map_public_ip_on_launch_true_boolean.yml'
      test_file2 = 'spec/test_templates/yaml/ec2_subnet/ec2_subnet_map_public_ip_on_launch_true_boolean.yml'

      cli_options = @default_cli_options.clone
      cli_options[:fail_on_warnings] = true
      expect(Options).to receive(:file_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:argf_read).and_return(IO.read(test_file1), IO.read(test_file2))
      expect(cfn_nag_executor).to receive(:argf_close).and_return(nil, nil)
      expect(cfn_nag_executor).to receive(:argf_finished?).and_return(false, false, true)
      expect(cfn_nag_executor).to receive(:argf_filename).and_return(test_file1, test_file2)

      result = cfn_nag_executor.scan(options_type: 'file')
      expect(result).to eq 2
    end
  end

  context 'single file cfn_nag' do
    it 'returns a successful zero exit code' do
      test_file = 'spec/test_templates/yaml/ec2_subnet/ec2_subnet_map_public_ip_on_launch_true_boolean.yml'

      expect(Options).to receive(:file_options).and_return(@default_cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:argf_read).and_return(IO.read(test_file))
      expect(cfn_nag_executor).to receive(:argf_close).and_return(nil)
      expect(cfn_nag_executor).to receive(:argf_finished?).and_return(false, true)
      expect(cfn_nag_executor).to receive(:argf_filename).and_return(test_file)

      result = cfn_nag_executor.scan(options_type: 'file')

      expect(result).to eq 0
    end
  end

  context 'single UTF-8 file cfn_nag' do
    test_file = 'spec/test_templates/yaml/template_with_non-US-ASCII_characters.yml'

    it 'returns a successful zero exit code when read with UTF-8 encoding' do
      expect(Options).to receive(:file_options).and_return(@default_cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:argf_read).and_return(IO.read(test_file, encoding: Encoding::UTF_8))
      expect(cfn_nag_executor).to receive(:argf_close).and_return(nil)
      expect(cfn_nag_executor).to receive(:argf_finished?).and_return(false, true)
      expect(cfn_nag_executor).to receive(:argf_filename).and_return(test_file)

      result = cfn_nag_executor.scan(options_type: 'file')

      expect(result).to eq 0
    end

    it 'returns a non-zero exit code when read with US-ASCII encoding' do
      expect(Options).to receive(:file_options).and_return(@default_cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:argf_read).and_return(IO.read(test_file, encoding: Encoding::US_ASCII))
      expect(cfn_nag_executor).to receive(:argf_close).and_return(nil)
      expect(cfn_nag_executor).to receive(:argf_finished?).and_return(false, true)
      expect(cfn_nag_executor).to receive(:argf_filename).and_return(test_file)

      result = cfn_nag_executor.scan(options_type: 'file')

      expect(result).to eq 1
    end
  end

  # this one triggers a trollop 'system exit' mid-flow :(
  context 'no input path specified' do
    it 'throws error on nil input_path' do
      expect {
        cfn_nag_executor = CfnNagExecutor.new

        _ = cfn_nag_executor.scan(options_type: 'scan')
      }.to raise_error(SystemExit)
    end
  end

  context 'input path specified with neptune directory', :poo do
    it 'records three failures' do
      cli_options = @default_cli_options.clone
      cli_options[:input_path] = 'spec/test_templates/json/neptune'
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 3
    end
  end

  context 'input path specified with fail on warnings' do
    it 'records four failures' do
      cli_options = @default_cli_options.clone
      cli_options[:input_path] = 'spec/test_templates/yaml/ec2_subnet'
      cli_options[:fail_on_warnings] = true
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 4
    end
  end

  context 'invalid value provided for output type' do
    it 'dies at validate_opts' do
      cli_options = @default_cli_options.clone
      cli_options[:output_format] = 'invalid'
      expect(Options).to receive(:scan_options).and_return(cli_options)

      expect {
        cfn_nag_executor = CfnNagExecutor.new

        _ = cfn_nag_executor.scan(options_type: 'scan')
      }.to raise_error(SystemExit)
    end
  end

  context 'use profile, deny list, and parameter path options' do
    it 'raises a TypeError once it tries to read the invalid files' do
      cli_options = @default_cli_options.clone
      cli_options[:deny_list_path] = 'spec/cfn_nag_integration/test_path.txt'
      cli_options[:parameter_values_path] = 'spec/cfn_nag_integration/test_path.txt'
      cli_options[:profile_path] = 'spec/cfn_nag_integration/test_path.txt'
      expect(Options).to receive(:scan_options).and_return(cli_options)

      expect {
        cfn_nag_executor = CfnNagExecutor.new

        _ = cfn_nag_executor.scan(options_type: 'scan')
      }.to raise_error(TypeError)
    end
  end

  context 'with deny list and blacklist path options' do
    it 'loads the deny list path within config' do
      cli_options = @default_cli_options.clone
      cli_options[:profile_path] = 'spec/cfn_nag_integration/test_path.txt'
      cli_options[:deny_list_path] = 'spec/cfn_nag_integration/example_deny_list.yaml'
      cli_options[:blacklist_path] = 'spec/cfn_nag_integration/example_blacklist.yaml'
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      expect(cfn_nag_executor).to receive(:read_conditionally).with('spec/cfn_nag_integration/example_deny_list.yaml').and_return('DummyDenyList')
      expect(cfn_nag_executor).not_to receive(:read_conditionally).with('spec/cfn_nag_integration/example_blacklist.yaml')
      expect(CfnNagConfig).to receive(:new).with(hash_including(deny_list_definition: 'DummyDenyList')).and_call_original

      expect(cfn_nag_executor).to receive(:execute_aggregate_scan).and_return(0)

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 0
    end
  end

  context 'with deprecated blacklist path options' do
    it 'loads the deny list path within config' do
      cli_options = @default_cli_options.clone
      cli_options[:profile_path] = 'spec/cfn_nag_integration/test_path.txt'
      cli_options[:blacklist_path] = 'spec/cfn_nag_integration/example_deny_list.yaml'
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new
      allow(cfn_nag_executor).to receive(:read_conditionally).and_call_original
      expect(cfn_nag_executor).to receive(:read_conditionally).with('spec/cfn_nag_integration/example_deny_list.yaml').and_return('DummyDenyList')
      expect(CfnNagConfig).to receive(:new).with(hash_including(deny_list_definition: 'DummyDenyList')).and_call_original

      expect(cfn_nag_executor).to receive(:execute_aggregate_scan).and_return(0)

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 0
    end
  end

  context 'invalid Options types' do
    it 'raises errors' do
      expect {Options.for('invalid')}.to raise_error(RuntimeError)
    end
  end

  context 'multi file cfn_nag with ignore fatal' do
    it 'returns failed result' do
      cli_options = @default_cli_options.clone
      cli_options[:input_path] = 'spec/test_templates/yaml/ignore_fatal'
      cli_options[:ignore_fatal] = true
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 1
    end
  end

  context 'multi file cfn_nag not ignornig fatal errors' do
    it 'returns two failed results' do
      cli_options = @default_cli_options.clone
      cli_options[:input_path] = 'spec/test_templates/yaml/ignore_fatal'
      cli_options[:ignore_fatal] = false
      expect(Options).to receive(:scan_options).and_return(cli_options)

      cfn_nag_executor = CfnNagExecutor.new

      result = cfn_nag_executor.scan(options_type: 'scan')

      expect(result).to eq 2
    end
  end
end
