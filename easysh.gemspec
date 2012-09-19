Gem::Specification.new do |s|
    s.name = 'easysh'
    s.version = '0.1.2'
    s.summary = 'Make shell task easier for ruby script.'
    s.description = 'Synatactic sugars about shell executables, redirects and pipes'
    s.authors = ["Wu Jun"]
    s.email = 'quark@zju.edu.cn'
    s.homepage = 'https://github.com/quark-zju/easysh'
    s.require_paths = ['lib']
    s.files = Dir['lib/*{,/*}']
    s.test_files = Dir['test/*']
end
