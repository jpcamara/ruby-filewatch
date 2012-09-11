require "logger"

#http://stackoverflow.com/questions/4487948/how-can-i-specify-a-local-gem-in-my-gemfile
module FileWatch
  class Monitor
    
    
    def expirement(observed = '.')
      # require 'java'
      import java.nio.file.WatchService
      import java.nio.file.FileSystems
      import java.nio.file.Path
      import java.nio.file.StandardWatchEventKinds
	  
      # get the file system and start a service
      file_system = FileSystems::default
      watch_service = file_system.new_watch_service
      to_monitor = [StandardWatchEventKinds::ENTRY_CREATE,
                    StandardWatchEventKinds::ENTRY_DELETE,
                    StandardWatchEventKinds::ENTRY_MODIFY]
                    
      #get directory junk
      path = file_system.get_path(observed)
      file = path.to_file
      if file.is_directory
        path.register(watch_service, *to_monitor)
      else #get the parent, which will be a directory
        path.get_parent.register(watch_service, *to_monitor)
      end
      
      loop do
        key = watch_service.take
        key.poll_events.each do |event| #why am i getting two events for each edit?
          next if event.kind == StandardWatchEventKinds::OVERFLOW
          file_name = event.context
          p event.kind.name()
          p file_name.to_s
        end
        valid = key.reset #if reset fails, this returns false
        break unless valid
      end
    end
    
    def self.java_7_available?
      begin
        require 'java'
        import java.nio.file.WatchService
        import java.nio.file.FileSystems
        true
      rescue LoadError => e
        p e.message
        false
      rescue => e
        p e.message
        false
      end
    end
  end
end

#FileWatch::WatchFile.new.expirement if FileWatch::WatchFile.java_7_available?