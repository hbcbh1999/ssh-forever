module SecureShellForever
  class << self
    def run(login, options = {})
      unless File.exists?(public_key_path)
        STDERR.puts "You do not appear to have a public key. I expected to find one at #{public_key_path}\n"
        STDERR.print "Would you like me to generate one? [Y/n]"
        result = STDIN.gets.strip
        unless result == '' or result == 'y' or result == 'Y'
          flunk %Q{Fair enough, I'll be off then. You can generate your own by hand using\n\n\tssh-keygen -t rsa}
        end
        generate_public_key
      end
      
      args = [
          ' ',
          ("-p #{options[:port]}" if options[:port] =~ /^\d+$/)
        ].compact.join(' ')
        
      puts "Copying your public key to the remote server. Prepare to enter your password for the last time."
      `ssh #{login}#{args} "#{remote_command}"`
      puts "Success. From now on you can just use plain old 'ssh'. Logging you in..."
      exec "ssh #{login}#{args}"
    end

    def remote_command
      commands = []
      commands << 'mkdir -p ~/.ssh'
      commands << 'chmod 700 ~/.ssh'
      commands << 'touch ~/.ssh/authorized_keys'
      commands << 'chmod 700 ~/.ssh/authorized_keys'
      commands << "echo #{key} >> ~/.ssh/authorized_keys"
      commands.join(' && ')
    end

    def key
      `cat #{public_key_path}`.strip
    end
    
    def generate_public_key
      silence_stream(STDOUT) do
        silence_stream(STDERR) do
          pipe = IO.popen('ssh-keygen -t rsa', 'w')
          6.times do
            pipe.puts "\n"
          end
        end
      end
      Process.wait
      flunk("Oh dear. I was unable to generate your public key. Run the command 'ssh-keygen -t rsa' manually to find out why.") unless $? == 0
    end
    
    def flunk(message)
      STDERR.puts message
      exit 1
    end
    
    def public_key_path
      File.expand_path('~/.ssh/id_rsa.pub')
    end
    
    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
    end
  end
end