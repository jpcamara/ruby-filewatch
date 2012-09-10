require "logger"

#http://stackoverflow.com/questions/4487948/how-can-i-specify-a-local-gem-in-my-gemfile
module FileWatch
  class JWatch
    def expirement
      # require 'java'
      import java.nio.file.WatchService
      import java.nio.file.FileSystems
      import java.nio.file.Path
      import java.nio.file.StandardWatchEventKinds
      # include_package "java.nio.file"
      file_system = FileSystems::default
      watch_service = file_system.new_watch_service
      path = file_system.get_path "/some_path"
      path.register(watch_service, StandardWatchEventKinds::ENTRY_CREATE)
      
      key = watch_service.take
      key.poll_events.each do |event|
        p event
      end
    end
    
    
    
    def self.java_7_available?
      begin
        require 'java'
        import java.nio.file.WatchService
        import java.nio.file.FileSystems
        true
      rescue LoadError => e
        false
      rescue => e
        false
      end
    end
  end
end

FileWatch::JWatch.new.expirement if FileWatch::JWatch.java_7_available?