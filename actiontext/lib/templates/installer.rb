# frozen_string_literal: true

require "pathname"
require "json"

APPLICATION_PACK_PATH = Pathname.new("app/javascript/packs/application.js")
JS_PACKAGE_PATH = Pathname.new("#{__dir__}/../../package.json")

JS_PACKAGE = JSON.load(JS_PACKAGE_PATH)
JS_DEPENDENCIES = JS_PACKAGE["peerDependencies"].dup.merge \
  JS_PACKAGE["name"] => "^#{JS_PACKAGE["version"]}"

say "Copying actiontext.scss to app/assets/stylesheets"
copy_file "#{__dir__}/actiontext.scss", "app/assets/stylesheets/actiontext.scss"

say "Copying fixtures to test/fixtures/action_text/rich_texts.yml"
copy_file "#{__dir__}/fixtures.yml", "test/fixtures/action_text/rich_texts.yml"

say "Copying blob rendering partial to app/views/active_storage/blobs/_blob.html.erb"
copy_file "#{__dir__}/../../app/views/active_storage/blobs/_blob.html.erb",
  "app/views/active_storage/blobs/_blob.html.erb"

say "Installing JavaScript dependencies"

begin
  exec "yarnpkg add #{JS_DEPENDENCIES.map { |name, version| "#{name}@#{version}" }.join(" ")}"
rescue Errno::ENOENT
  $stderr.puts "Yarn executable was not detected in the system."
  $stderr.puts "Download Yarn at https://yarnpkg.com/en/docs/install"
  exit 1
end

if APPLICATION_PACK_PATH.exist?
  JS_DEPENDENCIES.keys.each do |name|
    line = %[require("#{name}")]
    unless APPLICATION_PACK_PATH.read.include? line
      say "Adding #{name} to #{APPLICATION_PACK_PATH}"
      append_to_file APPLICATION_PACK_PATH, "\n#{line}"
    end
  end
end
