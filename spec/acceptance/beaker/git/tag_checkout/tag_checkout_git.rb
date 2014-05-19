test_name 'C3443 - checkout a tag (git protocol)'

# Globals
repo_name = 'testrepo_tag_checkout'
tag = '0.0.2'

hosts.each do |host|
  tmpdir = host.tmpdir('vcsrepo')
  step 'setup - create repo' do
    install_package(host, 'git')
    my_root = File.expand_path(File.join(File.dirname(__FILE__), '../../../..'))
    scp_to(host, "#{my_root}/acceptance/files/create_git_repo.sh", tmpdir)
    on(host, "cd #{tmpdir} && ./create_git_repo.sh")
  end
  step 'setup - start git daemon' do
    install_package(host, 'git-daemon')
    on(host, "git daemon --base-path=#{tmpdir}  --export-all --reuseaddr --verbose --detach")
  end

  teardown do
    on(host, "rm -fr #{tmpdir}")
    on(host, 'pkill -9 git-daemon')
  end

  step 'get tag sha from repo' do
    on(host, "git --git-dir=#{tmpdir}/testrepo.git rev-list HEAD | tail -1") do |res|
      @sha = res.stdout.chomp
    end
  end

  step 'checkout a tag with puppet' do
    pp = <<-EOS
    vcsrepo { "#{tmpdir}/#{repo_name}":
      ensure => present,
      source => "git://#{host}/testrepo.git",
      provider => git,
      revision => '#{tag}',
    }
    EOS

    apply_manifest_on(host, pp)
    apply_manifest_on(host, pp)
  end

  step "verify checkout out tag is #{tag}" do
    on(host, "ls #{tmpdir}/#{repo_name}/.git/") do |res|
      fail_test('checkout not found') unless res.stdout.include? "HEAD"
    end

    on(host,"git --git-dir=#{tmpdir}/#{repo_name}/.git name-rev HEAD") do |res|
      fail_test('tag not found') unless res.stdout.include? "#{tag}"
    end
  end

end