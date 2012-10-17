#
# Cookbook Name:: gsearch
# Recipe:: default
#
# Copyright 2012, UTL
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

### This recipe assumes that solr has been installed and attributes are defined
### It also assumes that the gsearch install is being done for Islandora 12.2

include_recipe "ark"

ark 'genericsearch' do
  version "2.2"
  url "http://#{node['repo_server']}/gsearch/genericsearch-2.2.zip"
  creates 'fedoragsearch.war'
  path "#{node['tomcat']['webapp_dir']}"
  checksum 'e54080df7eb5929aeeb31f035c208e5a97750b5878c08b589261fe5d4c81f37a'
  action :cherry_pick
  notifies :restart, resources(:service => "tomcat"), :immediately
end

####unfortunately we have to wait here for tomcat to populate the war, need to do this better
#execute "wait_for_tomcat" do
#  command "sleep 10"
#  action :run
#end

### create the config dir for Solr / GSearch
directory "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config" do
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0755"
  action :create
  retries 10
  retry_delay 10
end

### update the contents from configDemoOnSolr into config
bash "copy_config" do
  user "tomcat6"
  group "tomcat6"
  cwd "/tmp"
  code <<-EOH
  cp -prt #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/configDemoOnSolr/*
  #sleep 3
  EOH
  not_if "test -f #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/fedoragsearch.properties"
end

### template fedoragsearch.perperties
template "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/fedoragsearch.properties" do
  source "fedoragsearch.properties.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
  retries 10
  retry_delay 10
end

### create the gsearch_solr dir for Solr / GSearch
directory "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/repository/#{node['gsearch']['repo_name']}" do
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0755"
  action :create
end

### update the contents from Demo dir into node['gsearch']['repo_name']
bash "copy_repo" do
  user "tomcat6"
  group "tomcat6"
  cwd "/tmp"
  code <<-EOH
  cp -prt #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/repository/#{node['gsearch']['repo_name']} #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/repository/DemoAtDtu/*
  #sleep 3
  EOH
  not_if "test -f #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/repository/#{node['gsearch']['repo_name']}/repository.properties"
end

### template repository.perperties
template "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/repository/#{node['gsearch']['repo_name']}/repository.properties" do
  source "repository.properties.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
  retries 10
  retry_delay 10
end

### create the gsearch_solr index directory
directory "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/#{node['gsearch']['repo_name']}" do
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0755"
  action :create
end

### update the contents from Demo dir into node['gsearch']['repo_name']
bash "copy_index" do
  user "tomcat6"
  group "tomcat6"
  cwd "/tmp"
  code <<-EOH
  cp -prt #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/#{node['gsearch']['repo_name']} #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/DemoOnSolr/*
  #sleep 3
  EOH
  not_if "test -f #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/#{node['gsearch']['repo_name']}/index.properties"
end

### template repository.perperties
template "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/#{node['gsearch']['repo_name']}/index.properties" do
  source "index.properties.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
  retries 10
  retry_delay 10
end

### create the config/updater directory
directory "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/updater/BasicUpdaters" do
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0755"
  recursive true
  action :create
end

## place updaters.properties, which doesn't need editing
cookbook_file "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/updater/BasicUpdaters/updater.properties" do
  source "updater.properties"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0644"
end

### template schema.xml
template "#{node[:tomcat][:base]}/solr/conf/schema.xml" do
  source "solr-gsearch.schema.xml.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
end

### template solrconfig.xml
template "#{node[:tomcat][:base]}/solr/conf/solrconfig.xml" do
  source "solr-gsearch.solrconfig.xml.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
end

### put the 5 xslts into #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/rest/
%w{ demoBrowseIndexToHtml  demoGetIndexInfoToHtml  demoGetRepositoryInfoToHtml  demoGfindObjectsToHtml  demoUpdateIndexToHtml }.each do |xsltfile|
  template "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/rest/#{xsltfile}.xslt" do
    source "#{xsltfile}.xslt.erb"
    owner "#{node['tomcat']['user']}"
    group "#{node['tomcat']['user']}"
    mode 0644
    notifies :restart, resources(:service => "tomcat")
  end
end

### get rid of old lucene files in #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/lib
%w{ core demos highlighter }.each do |deleteme|
  file "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/lib/lucene-#{deleteme}-2.4.0.jar" do
    action :delete
  end  
end

### copy in the new lucene 2.9.3 jars
%w{ analyzers highlighter misc snowball core memory queries spellchecker }.each do |lucenecopy|
  execute "copy_#{lucenecopy}" do
    command "cp -pf #{node['tomcat']['webapp_dir']}/solr/WEB-INF/lib/lucene-#{lucenecopy}-2.9.3.jar #{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/lib/"
    creates "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/lib/lucene-#{lucenecopy}-2.9.3.jar"
    action :run
    notifies :restart, resources(:service => "tomcat")
  end  
end

## place demoFoxmlToSolr.xslt, which doesn't need editing
cookbook_file "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/config/index/#{node['gsearch']['repo_name']}/demoFoxmlToSolr.xslt" do
  source "demoFoxmlToSolr.xslt"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0644"
  notifies :restart, resources(:service => "tomcat")
end

### template log4j.xml
template "#{node['tomcat']['webapp_dir']}/fedoragsearch/WEB-INF/classes/log4j.xml" do
  source "log4j.xml.erb"
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode 0644
  notifies :restart, resources(:service => "tomcat")
end
