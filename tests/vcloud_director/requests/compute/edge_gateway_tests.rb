Shindo.tests('Compute::VcloudDirector | edge gateway requests', ['vclouddirector']) do

  FIREWALL_RULE_ID = '9999'

  @new_edge_gateway_configuration = {
    :FirewallService =>
      {
        :IsEnabled => "true",
        :DefaultAction => "allow",
        :LogDefaultAction => "false",
        :FirewallRule => [
          {
            :IsEnabled => "false",
            :MatchOnTranslate => "false",
            :Id => FIREWALL_RULE_ID,
            :Policy => "drop",
            :Description => "generated from edge_gateway_tests",
            :Protocols => {
              :Tcp => "true"
            },
            :Port => "3412",
            :DestinationPortRange => "3412",
            :DestinationIp => "internal",
            :SourcePort => "3412",
            :SourceIp => "internal",
            :SourcePortRange => "3412",
            :EnableLogging => "false"
          }
        ]
      }
  }


  @service = Fog::Compute::VcloudDirector.new
  @org = VcloudDirector::Compute::Helper.current_org(@service)

  tests('Get first vDC') do
    link = @org[:Link].detect do |l|
      l[:type] == 'application/vnd.vmware.vcloud.vdc+xml'
    end
    @vdc_id = link[:href].split('/').last
  end

  tests('#get_org_vdc_gateways').data_matches_schema(VcloudDirector::Compute::Schema::QUERY_RESULT_RECORDS_TYPE) do
    begin
      @edge_gateways = @service.get_org_vdc_gateways(@vdc_id).body
    rescue Fog::Compute::VcloudDirector::Unauthorized # bug, may be localised
      retry
    end
    @edge_gateways
  end

  @edge_gateways[:EdgeGatewayRecord].each do |result|
    tests("each EdgeGatewayRecord").
      data_matches_schema(VcloudDirector::Compute::Schema::QUERY_RESULT_EDGE_GATEWAY_RECORD_TYPE) { result }
  end

  tests('#get_edge_gateway').data_matches_schema(VcloudDirector::Compute::Schema::GATEWAY_TYPE) do
    @edge_gateway_id = @edge_gateways[:EdgeGatewayRecord].first[:href].split('/').last
    @orginal_gateway_conf = @service.get_edge_gateway(@edge_gateway_id).body
  end

  tests('#configure_edge_gateway_services') do

    rule = @orginal_gateway_conf[:Configuration][:EdgeGatewayServiceConfiguration][:FirewallService][:FirewallRule].find { |rule| rule[:Id] == FIREWALL_RULE_ID }
    raise('fail fast if our test firewall rule already exists - its likely left over from a broken test run') if rule

    response = @service.post_configure_edge_gateway_services(@edge_gateway_id, @new_edge_gateway_configuration)
    @service.process_task(response.body)

    tests('#check for new firewall rule').returns(@new_edge_gateway_configuration[:FirewallService][:FirewallRule]) do
      edge_gateway = @service.get_edge_gateway(@edge_gateway_id).body
      edge_gateway[:Configuration][:EdgeGatewayServiceConfiguration][:FirewallService][:FirewallRule]
    end

    tests('#remove the firewall rule added by test').returns(nil) do
      response = @service.post_configure_edge_gateway_services(@edge_gateway_id,
                                                               @orginal_gateway_conf[:Configuration][:EdgeGatewayServiceConfiguration])
      @service.process_task(response.body)
      edge_gateway = @service.get_edge_gateway(@edge_gateway_id).body
      edge_gateway[:Configuration][:EdgeGatewayServiceConfiguration][:FirewallService][:FirewallRule].find { |rule| rule[:Id] == FIREWALL_RULE_ID }
    end
end

  tests('Retrieve non-existent edge gateway').raises(Fog::Compute::VcloudDirector::Forbidden) do
    begin
      @service.get_edge_gateway('00000000-0000-0000-0000-000000000000')
    rescue Fog::Compute::VcloudDirector::Unauthorized # bug, may be localised
      retry
    end
  end

  tests('Configure non-existent edge gateway').raises(Fog::Compute::VcloudDirector::Forbidden) do
    begin
      @service.post_configure_edge_gateway_services('00000000-0000-0000-0000-000000000000', {})
    rescue Fog::Compute::VcloudDirector::Unauthorized # bug, may be localised
      retry
    end
  end

end
