require 'spec_helper'
require 'cfn-nag/cfn_nag_config'
require 'cfn-nag/cfn_nag'

describe CfnNag do
  before(:all) do
    CfnNagLogging.configure_logging(debug: false)
    @cfn_nag = CfnNag.new(config: CfnNagConfig.new)
  end

  context 'lambda permission with some out of the ordinary items', :lambda do
    it 'flags a warning' do
      template_name = 'json/lambda_permission/lambda_with_wildcard_principal_and_non_invoke_function_permission.json'

      expected_aggregate_results = [
        {
          filename: test_template_path(template_name),
          file_results: {
            failure_count: 3,
            violations: [
              IamRolePassRoleWildcardResourceRule.new.violation(%w[LambdaExecutionRole], [50], ["resource"]),
              IamRoleWildcardActionOnPermissionsPolicyRule.new.violation(%w[LambdaExecutionRole], [50], ["resource"]),
              IamRoleWildcardResourceOnPermissionsPolicyRule.new.violation(%w[LambdaExecutionRole], [50], ["resource"]),
              LambdaFunctionInsideVPCRule.new.violation(%w[AppendItemToListFunction], [4], ["resource"]),
              LambdaPermissionWildcardPrincipalRule.new.violation(%w[lambdaPermission], [24], ["resource"])
            ]
          }
        }
      ]

      actual_aggregate_results = @cfn_nag.audit_aggregate_across_files input_path: test_template_path(template_name)
      expect(actual_aggregate_results).to eq expected_aggregate_results
    end
  end

  # the heavy lifting for dealing with globals is down in cfn-model.  just make sure we've got a good version
  # of the parser that doesn't blow up
  context 'serverless function with globals', :lambda do
    it 'parses properly' do
      template_name = 'yaml/sam/globals.yml'
      actual_aggregate_results = @cfn_nag.audit_aggregate_across_files input_path: test_template_path(template_name)
      expect(actual_aggregate_results[0][:file_results][:failure_count]).to eq 0
    end

    it 'makes globals available as a top-level hash' do
      template_name = 'yaml/sam/globals.yml'
      cfn_model = CfnParser.new.parse read_test_template(template_name)
      globals = cfn_model.globals

      expect(globals).to_not be_nil
      expect(globals['Function'].timeout).to eq 30
    end
  end

  context 'serverless function with implicit API', :lambda do
    it 'parses properly' do
      template_name = 'yaml/sam/serverless_rest_api_with_basepathmapping.yml'
      actual_aggregate_results = @cfn_nag.audit_aggregate_across_files input_path: test_template_path(template_name)
      expect(actual_aggregate_results[0][:file_results][:failure_count]).to eq 2
      violations = actual_aggregate_results[0][:file_results][:violations].select do |violation|
        violation.type == 'FAIL'
      end
      expect(violations.map(&:id)).to eq %w[F38 F3]
    end
  end
end
