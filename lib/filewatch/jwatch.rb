require 'logger'
require 'set'

#http://stackoverflow.com/questions/4487948/how-can-i-specify-a-local-gem-in-my-gemfile
module FileWatch
  class JWatch
    attr_accessor :logger
    import java.nio.file.WatchService
    import java.nio.file.FileSystems
    import java.nio.file.Path
    import java.nio.file.StandardWatchEventKinds

    public
    def initialize(opts = {})
      if opts[:logger]
        @logger = opts[:logger]
      else
        @logger = Logger.new(STDERR)
        @logger.level = Logger::DEBUG
      end
      @watching = Set.new
      @exclude = []
      @includes = Set.new
      @dirs = Set.new
      @to_monitor = [StandardWatchEventKinds::ENTRY_CREATE,
                    StandardWatchEventKinds::ENTRY_DELETE,
                    StandardWatchEventKinds::ENTRY_MODIFY]
      @file_system = FileSystems::default
      @watch_service = @file_system.new_watch_service
      
      # get the file system and start a service

                    
      #get directory junk
      # path = file_system.get_path(observed)
      # file = path.to_file
      # if file.is_directory
      #   path.register(watch_service, *to_monitor)
      # else #get the parent, which will be a directory
      #   path.get_parent.register(watch_service, *to_monitor)
      # end
      # 
      # loop do
      #   key = watch_service.take
      #   key.poll_events.each do |event| #why am i getting two events for each edit?
      #     next if event.kind == StandardWatchEventKinds::OVERFLOW
      #     file_name = event.context
      #     p event.kind.name()
      #     p file_name.to_s
      #   end
      #   valid = key.reset #if reset fails, this returns false
      #   break unless valid
      # end
      
    end # def initialize

    public
    def exclude(path)
      path.to_a.each { |p| @exclude << p }
    end

    public
    def watch(path)
      unless @watching.member?(path)
        @watching << path
        _discover_file(path)
      end

      return true
    end # def tail

    # Calls &block with params [event_type, path]
    # event_type can be one of:
    #   :create - file is created (new file after initial globs, start at 0)
    #   :modify - file is modified (size increases)
    #   :delete - file is deleted
    public
    def each(stat_interval, &block)
      @logger.debug  'Starting each'
      watch_key = @watch_service.poll stat_interval, java.util.concurrent.TimeUnit::SECONDS
      return true if watch_key.nil?
      
      watch_key.poll_events.each do |event|
        file_name = event.context.to_absolute_path
        @logger.debug event.kind.name
        @logger.debug file_name.to_s
        
        next if event.kind == StandardWatchEventKinds::OVERFLOW
        
        unless @includes.member?(file_name.to_s)
          if event.kind != StandardWatchEventKinds::ENTRY_CREATE
            next
          end
        end
        
        case event.kind
        when StandardWatchEventKinds::ENTRY_CREATE
          @logger.debug  "CREATE! #{file_name.to_s}"
          yield(:create, file_name.to_s)
          _discover_file(file_name.to_s)
        when StandardWatchEventKinds::ENTRY_DELETE
          @logger.debug  "DELETE! #{file_name.to_s}"
          yield(:delete, file_name.to_s)
        when StandardWatchEventKinds::ENTRY_MODIFY
          @logger.debug  "MODIFY! #{file_name.to_s}  "
          @logger.debug("#{file_name.to_s}: file grew")
          yield(:modify, file_name.to_s)
        else
          next
        end
      end
      watch_key.reset
    end # def each

    public
    def discover
      #No need to discover, we already have that automatically
    end

    public
    def subscribe(stat_interval = 1, discover_interval = 5, &block)
      #No need for discover interval - handled by the framework
      loop do
        @logger.debug 'subscribe loop'
        break unless each(stat_interval, &block)
        # sleep(stat_interval)
      end
    end # def subscribe

    private
    def _discover_file(path)
      @logger.debug  'discovering files'
      globbed_dirs = Dir.glob(path)
      @logger.debug("_discover_file_glob: #{path}: glob is: #{globbed_dirs}")
      if globbed_dirs.empty? && File.file?(path)
        globbed_dirs = [path]
        @logger.debug("_discover_file_glob: #{path}: glob is: #{globbed_dirs} because glob did not work")
      end
      globbed_dirs.each do |file|
        expanded_file = File.expand_path(file)
        java_path = @file_system.get_path(expanded_file).to_absolute_path
        java_path_dir = java_path.to_file.is_directory ? java_path : java_path.get_parent
        next if @includes.member?(expanded_file)
        
        @logger.debug("_discover_file: #{java_path.to_s}: new: #{expanded_file} (exclude is #{@exclude.inspect})")

        skip = false
        @exclude.each do |pattern|
          if File.fnmatch?(pattern, File.basename(expanded_file))
            @logger.debug("_discover_file: #{expanded_file}: skipping because it " +
                          "matches exclude #{pattern}")
            skip = true
            break
          end
        end
        next if skip
        
        #get it as a path
        @includes << java_path.to_s
        next if @dirs.member?(java_path_dir.to_s)
        
        @dirs << java_path_dir.to_s
        java_path_dir.register(@watch_service, *@to_monitor)
      end
      
      @logger.info(@dirs.inspect)
      @logger.info(@includes.inspect)
    end # def _discover_file
  end
end