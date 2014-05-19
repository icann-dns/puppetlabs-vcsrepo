test_name 'C3488 - checkout as a group (ssh protocol, scp syntax)'

# Globals
repo_name = 'testrepo_group_checkout'
group = 'mygroup'

hosts.each do |host|
  tmpdir = host.tmpdir('vcsrepo')
  step 'setup - create repo' do
    install_package(host, 'git')
    my_root = File.expand_path(File.join(File.dirname(__FILE__), '../../../..'))
    scp_to(host, "#{my_root}/acceptance/files/create_git_repo.sh", tmpdir)
    on(host, "cd #{tmpdir} && ./create_git_repo.sh")
  end
  step 'setup - establish ssh keys' do
    # create ssh keys
    on(host, 'ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ""')

    # copy public key to authorized_keys
    on(host, 'echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config')
    on(host, 'chown -R root:root /root/.ssh')
  end

  step 'setup - create group' do
    apply_manifest_on(host, "group { '#{group}': ensure => present, }")
  end

  teardown do
    on(host, "rm -fr #{tmpdir}")
    apply_manifest_on(host, "file{'/root/.ssh/id_rsa': ensure => absent, force => true }")
    apply_manifest_on(host, "file{'/root/.ssh/id_rsa.pub': ensure => absent, force => true }")
    apply_manifest_on(host, "group { '#{group}': ensure => absent, }")
  end

  step 'checkout as a group with puppet (scp syntax)' do
    pp = <<-EOS
    vcsrepo { "#{tmpdir}/#{repo_name}":
      ensure => present,
      source => "root@#{host}:#{tmpdir}/testrepo.git",
      provider => git,
      group => '#{group}',
    }
    EOS

    apply_manifest_on(host, pp)
    apply_manifest_on(host, pp)
  end

  step "verify git checkout is own by group #{group}" do
    on(host, "ls #{tmpdir}/#{repo_name}/.git/") do |res|
      fail_test('checkout not found') unless res.stdout.include? "HEAD"
    end

    on(host, "stat --format '%U:%G' #{tmpdir}/#{repo_name}/.git/HEAD") do |res|
      fail_test('checkout not owned by group') unless res.stdout.include? ":#{group}"
    end
  end

end