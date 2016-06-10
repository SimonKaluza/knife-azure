#
# Author:: Nimisha Sharad (<nimisha.sharad@msystechnologies.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../unit/query_azure_mock')

describe Chef::Knife::AzurermBase, :windows_only do
  include AzureSpecHelper
  include QueryAzureMock

  class Chef
    class Knife
      class WindowsCredentialsClass < Knife
        include Azure::ARM::WindowsCredentials if Chef::Platform.windows?
      end
    end
  end

  before do
    @windows_credentials = Chef::Knife::WindowsCredentialsClass.new
  end

  context "token_details_for_windows" do
    it "should raise error if target doesn't exist" do
      allow(@windows_credentials).to receive(:target_name)
      expect {@windows_credentials.token_details_for_windows}.to raise_error(SystemExit)
    end

    it "should raise error if target is not in proper format" do
      # removing expiresOn field from target
      target = "AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/common::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:chirag.jog@outlook.com--0-2"
      translated_cred = {:TargetName => double(:read_wstring => target),
        :CredentialBlob => double(:get_bytes => "a:access_token::r:refresh_token")}
      allow(@windows_credentials).to receive(:target_name).and_return(target)
      allow(FFI::MemoryPointer).to receive(:new)
      allow(Azure::ARM::ReadCred::CREDENTIAL_OBJECT).to receive(:new).exactly(2).and_return(translated_cred)
      allow(@windows_credentials).to receive(:CredReadW)
      allow_any_instance_of(NilClass).to receive(:read_pointer)
      expect {@windows_credentials.token_details_for_windows}.to raise_error(SystemExit)
    end

    it "should parse the target and return a hash if target exists" do
      target = "AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/common::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::expiresOn:2016-06-07T13\\:16\\:34.877Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:chirag.jog@outlook.com--0-2"
      translated_cred = {:TargetName => double(:read_wstring => target),
        :CredentialBlob => double(:get_bytes => "a:access_token::r:refresh_token")}
      allow(@windows_credentials).to receive(:target_name).and_return(target)
      allow(FFI::MemoryPointer).to receive(:new)
      allow(Azure::ARM::ReadCred::CREDENTIAL_OBJECT).to receive(:new).exactly(2).and_return(translated_cred)
      allow(@windows_credentials).to receive(:CredReadW)
      allow_any_instance_of(NilClass).to receive(:read_pointer)
      credential = @windows_credentials.token_details_for_windows
      expect(credential[:tokentype]).to be == "Bearer"
      expect(credential[:user]).to be == "chirag.jog@outlook.com--0-2"
      expect(credential[:token]).to be == "access_token"
      expect(credential[:refresh_token]).to be == "refresh_token"
      expect(credential[:clientid]).to be == "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
      expect(credential[:expiry_time]).to be == "2016-06-07T13:16:34.877Z"
    end
  end

  context "target_name" do
    it "should raise error if Azure credentials are not found" do
      cmdkey_output = double(:stdout => "")
      allow_any_instance_of(Mixlib::ShellOut).to receive(:run_command).and_return(cmdkey_output)
      expect{@windows_credentials.target_name}.to raise_error(RuntimeError)
    end

    it "should fetch the credential ending with --0-2" do
      targets = "    Target: AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/6ea8098b-72a2-44a9-bdf4-9a01a5ba2727::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::expiresOn:2016-06-09T13\\:53\\:07.510Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:msdn2@opscode.com--0-2\n   Target:AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/abeb039a-5e53-40ee-b48f-0c99bdc99d15::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3600::expiresOn:2016-06-09T13\\:51\\:56.271Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:chirag.jog@outlook.com--0-2\n"
      cmdkey_output = double(:stdout => targets)
      allow_any_instance_of(Mixlib::ShellOut).to receive(:run_command).and_return(cmdkey_output)
      #target ending with --0-2
      latest_target = "AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/6ea8098b-72a2-44a9-bdf4-9a01a5ba2727::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::expiresOn:2016-06-09T13\\:53\\:07.510Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:msdn2@opscode.com--0-2"
      target_name = @windows_credentials.target_name
      expect(target_name).to be == latest_target
    end
  end

  context "latest_credential_target" do
    it "should raise error if no target is passed" do
      targets = []
      expect {@windows_credentials.latest_credential_target(targets)}.to raise_error(RuntimeError)
    end

    it "should return the target if a single target is passes" do
      targets = ["target"]
      latest_target = @windows_credentials.latest_credential_target(targets)
      expect(latest_target).to be == "target"
    end

    it "should remove 'Target:' and extra speces from the target string for single target" do
      targets = ["   Target:target   "]
      latest_target = @windows_credentials.latest_credential_target(targets)
      expect(latest_target).to be == "target"
    end

    it "should return the latest target when multiple targets are passed" do
      targets = ["    Target: AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/6ea8098b-72a2-44a9-bdf4-9a01a5ba2727::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::expiresOn:2016-06-09T13\\:53\\:07.510Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:msdn2@opscode.com--0-2",
        "    Target: AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/abeb039a-5e53-40ee-b48f-0c99bdc99d15::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3600::expiresOn:2016-06-09T13\\:51\\:56.271Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:chirag.jog@outlook.com--0-2"]
      target_name = "AzureXplatCli:target=_authority:https\\://login.microsoftonline.com/6ea8098b-72a2-44a9-bdf4-9a01a5ba2727::_clientId:04b07795-8ddb-461a-bbee-02f9e1bf7b46::expiresIn:3599::expiresOn:2016-06-09T13\\:53\\:07.510Z::identityProvider:live.com::isMRRT:true::resource:https\\://management.core.windows.net/::tokenType:Bearer::userId:msdn2@opscode.com--0-2"
      latest_target = @windows_credentials.latest_credential_target(targets)
      expect(latest_target).to be == target_name
    end
  end
end