#!/usr/bin/ruby

require 'json'
require 'logger'
require 'thread'

# Default file names
INPUT_FILE = 'mixtape-data.json'
OUTPUT_FILE = 'output.json'
CHANGES_FILE = 'changes.json'

# Thread safe wrapper around object hash.
# Assumes each object has an integer id attribute.
# New id values get generated for the new objects added to the collection
class ObjectMap

  # +objects+ - object collection
  # +key_attrs+ - list of attribute names which form the key
  def initialize(objects, *key_attrs)
    @mutex = Mutex.new
    @id = objects.map{|o| o[:id].to_i}.max + 1
    @key_attrs = key_attrs

    @objects_map = Hash[objects.map{|o| [get_key_value(o), o]}]
  end

  def items
    @objects_map.values
  end

  def add(object)
    @mutex.synchronize do
      add_to_map(object, get_key_value(object) || @id.to_s)
    end
  end

  def delete(key)
    @objects_map.delete(key)
  end

  def get(key)
    @objects_map[key]
  end

  def get_or_create(object)
    key = get_key_value(object)

    if get(key).nil?
      @mutex.synchronize do
        if get(key).nil?
          add_to_map(object, key)
        end
      end
    end

    get(key)
  end

  private

  def get_key_value(object)
    if @key_attrs.length > 1
      Hash[@key_attrs.map{|k| [k, object[k]]}]
    else
      object[@key_attrs[0]]
    end
  end

  def add_to_map(object, key)
    object[:id] = @id.to_s
    @objects_map[key] = object
    @id += 1
  end
end

def read_command_line_args
  args = {}
  i = 0
  while i < ARGV.length
    if ARGV[i].start_with?('-')
      args[ARGV[i][1, ARGV[i].length - 1].to_sym] = ARGV[i + 1]
      i += 1
    end
    i += 1
  end
  args
end

def read_json_file(input_file_path)
  input_file = File.open(input_file_path)
  JSON.parse(input_file.read, {:symbolize_names => true})
end

def write_output(output_file_name)
  File.open(output_file_name, "w") do |f|
    f.write(JSON.pretty_generate({
        users: @users.items,
        playlists: @playlists.items,
        songs: @songs.items
                         })
    )
  end
end

def add_playlist(change)
  return if change[:songs].nil? || change[:songs].length == 0

  user = @users.get_or_create({name: change[:user]})
  @playlists.add({user_id: user[:id], song_ids: change[:songs].map{|s| @songs.get_or_create(s)[:id]} })
end

def remove_playlist(change)
  @playlists.delete(change[:playlist_id])
end

def add_song(change)
  playlist = @playlists.get(change[:playlist_id])
  return if playlist.nil?

  song = {artist: change[:artist], title: change[:title]}
  playlist[:song_ids] << @songs.get_or_create(song)[:id]
end

# Main loop for processing playlist changes
# 'action' attribute value should match the method name used to make the change
def process_change
  while (change = get_change)
    if self.respond_to?(change[:action], change)
      self.send(change[:action], change)
    else
      @logger.warn("Unknown change type: #{change[:action]}")
    end
  end
end

# Get next change from the queue
def get_change
  @change_mutex.synchronize do
    change = @changes[@change_indx]
    @change_indx += 1
    change
  end
end

begin
  @logger = Logger.new(STDOUT)

  args = read_command_line_args
  input_file_path = args[:input] || INPUT_FILE
  output_file_path = args[:output] || OUTPUT_FILE
  changes_file_path = args[:changes] || CHANGES_FILE
  thread_count = (args[:threads] || 1).to_i

  @logger.info "Input file: #{input_file_path}"
  @logger.info "Output file: #{output_file_path}"
  @logger.info  "Changes file: #{changes_file_path}"

  mixtape = read_json_file(input_file_path)

  @users = ObjectMap.new(mixtape[:users] || [], :name)
  @songs = ObjectMap.new(mixtape[:songs] || [], :artist, :title)
  @playlists = ObjectMap.new(mixtape[:playlists] || [], :id)

  @logger.info 'Reading changes...'
  changes = read_json_file(changes_file_path)
  @logger.info'Done'

  @changes = changes[:changes] || []
  @change_indx = 0

  @change_mutex = Mutex.new

  @logger.info "Processing #{@changes.length} changes..."
  Thread.abort_on_exception = true
  worker_threads = []
  thread_count.times do
    worker_threads << Thread.new {process_change}
  end
  worker_threads.each(&:join)
  @logger.info 'Done'

  @logger.info 'Saving result...'
  write_output(output_file_path)
  @logger.info 'Done'

rescue Exception => e
  @logger.error "Failed with: #{e}"
end