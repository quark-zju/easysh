Gem::Specification.new do |s|
    s.name = 'easysh'
    s.version = '0.1.0'
    s.summary = 'Make shell task easier for ruby script.'
    s.description = 'Synatactic sugars about shell executables, redirects and pipes'
    s.authors = ["Wu Jun"]
    s.email = 'quark@zju.edu.cn'
    s.homepage = 'https://github.com/quark-zju/easyshell'
    s.require_paths = ['lib']
    s.files = Dir['lib/*{,/*}']
    s.test_files = Dir['test/*']
end
