require 'rack/directory'
require 'rack/lint'
require 'rack/mock'

describe Rack::Directory do
  DOCROOT = File.expand_path(File.dirname(__FILE__)) unless defined? DOCROOT
  FILE_CATCH = proc{|env| [200, {'Content-Type'=>'text/plain', "Content-Length" => "7"}, ['passed!']] }
  app = Rack::Lint.new(Rack::Directory.new(DOCROOT, FILE_CATCH))

  should "serve directory indices" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/")

    res.should.be.ok
    res.should =~ /<html><head>/
  end

  should "pass to app if file found" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/test")

    res.should.be.ok
    res.should =~ /passed!/
  end

  should "serve uri with URL encoded filenames" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/%63%67%69/") # "/cgi/test"

    res.should.be.ok
    res.should =~ /<html><head>/

    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/%74%65%73%74") # "/cgi/test"

    res.should.be.ok
    res.should =~ /passed!/
  end

  should "fix CVE-2026-25500" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/")

    res.should.be.ok
    res.body.should.include('<html><head>')
    res.body.should.include("href='./cgi")
  end

  should "not allow directory traversal" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/../test")

    res.should.be.forbidden

    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/%2E%2E/test")

    res.should.be.forbidden
  end

  should "not allow directory traversal via root prefix bypass" do
    Dir.mktmpdir do |dir|
      root = File.join(dir, "root")
      outside = "#{root}_test"
      FileUtils.mkdir_p(root)
      FileUtils.mkdir_p(outside)
      FileUtils.touch(File.join(outside, "test.txt"))

      traversal_app = Rack::Directory.new(root)
      res = Rack::MockRequest.new(traversal_app).get("/../#{File.basename(outside)}/")

      res.should.be.forbidden
    end
  end

  should "not allow dir globs" do
    Dir.mktmpdir do |dir|
      weirds = "uploads/.?/.?"
      full_dir = File.join(dir, weirds)
      FileUtils.mkdir_p full_dir
      FileUtils.touch File.join(dir, "secret.txt")
      second_app = Rack::Directory.new(File.join(dir, "uploads"))
      res = Rack::MockRequest.new(second_app).get("/.%3F")
      res.body.should.not.include "secret.txt"
    end
  end

  should "404 if it can't find the file" do
    res = Rack::MockRequest.new(Rack::Lint.new(app)).
      get("/cgi/blubb")

    res.should.be.not_found
  end

  should "uri escape path parts" do # #265, properly escape file names
    mr = Rack::MockRequest.new(Rack::Lint.new(app))

    res = mr.get("/cgi/test%2bdirectory")

    res.should.be.ok
    res.body.should =~ %r[/cgi/test%2Bdirectory/test%2Bfile]

    res = mr.get("/cgi/test%2bdirectory/test%2bfile")
    res.should.be.ok
  end

  should "correctly escape script name" do
    app2 = Rack::Builder.new do
      map '/script-path' do
        run app
      end
    end

    mr = Rack::MockRequest.new(Rack::Lint.new(app2))

    res = mr.get("/script-path/cgi/test%2bdirectory")

    res.should.be.ok
    res.body.should =~ %r[/script-path/cgi/test%2Bdirectory/test%2Bfile]

    res = mr.get("/script-path/cgi/test%2bdirectory/test%2bfile")
    res.should.be.ok
  end

  should "handle root paths containing regex metacharacters" do
    Dir.mktmpdir do |tmpdir|
      # Create a directory with a name that contains regex metacharacters:
      root = File.join(tmpdir, "plus+root")
      FileUtils.mkdir(root)

      # Create a file in the directory:
      File.open(File.join(root, "file.txt"), "w") { |f| f.write("test") }

      # Make a request to the directory app:
      app = Rack::Lint.new(Rack::Directory.new(root))
      res = Rack::MockRequest.new(app).get("/")
      res.should.be.ok

      # This should not leak the root directory:
      res.body.should.not.include root
      res.body.should.not.include Rack::Utils.escape_html(tmpdir)

      # This is always okay:
      res.body.should.include "file.txt"
    end
  end
end
