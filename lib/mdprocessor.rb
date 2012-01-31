
require 'json'
require 'pathname'
require 'rake'
require 'rake/task'
require 'redcarpet'
require 'yaml'

class HTMLWithPants < Redcarpet::Render::HTML
  include Redcarpet::Render::SmartyPants
end


module Tutorial
  module Content

    # This defines a task to compile a directory of source Markdown files into
    # a JSON file to use with the tutorial viewer/reader.
    #
    # Metadata is in YAML. 
    #
    # The primary file expects these metadata:
    #
    # * title (string title of the tutorial);
    # * version (string version);
    # * chapters (list of strings, files for the chapters, relative to the
    # primary file).
    #
    # The chapter files expect these metadata:
    #
    # * title (string title of the chapter);
    # * full (optional, true if the this is a full-page view, i.e., no REPL or
    # sandbox);
    # * sections (list of strings, files for the sections, relative to the
    # chapter file).
    #
    # The section files expect these metadata:
    #
    # * title (string title of the section);
    # * full (optional, true if the this is a full-page view, i.e., no REPL or
    # sandbox).
    #
    def self.compile(name, json_file, src_files, *args)
      args = args || []
      args.insert 0, name

      body = proc {
        srcs = src_files.map do |src|
          puts "compiling source file #{src}"
          Compiler.new(src).to_h
        end

        puts "writing #{json_file}"
        File.open(json_file, 'w') do |f|
          f.write("window.#{name} = ")
          JSON.dump(srcs[0], f)
        end
      }

      Rake::Task.define_task(*args, &body)
    end

    class Compiler
      attr_accessor :primary

      def initialize(primary_file)
        @primary = primary_file
        @markdown = Redcarpet::Markdown.new(HTMLWithPants,
                                            :fenced_code_blocks => true)
      end

      def split_file(filename)
        lines = IO.readlines(filename)
        split_at = lines.index { |line| line.strip.empty? }
        yaml_lines = lines[0, split_at]
        md_lines = lines[split_at + 1, lines.length]
        [yaml_lines.join(), md_lines.join()]
      end

      def parse_yaml(data)
        YAML.load(data)
      end

      def parse_md(data)
        @markdown.render(data)
      end

      def read_file(filename)
        pathname = Pathname.new(filename)
        if !pathname.absolute?
          pathname = Pathname.pwd.join(pathname)
        end
        puts "Reading #{pathname.to_s}..."

        yaml, md = split_file(pathname.to_s)

        meta = parse_yaml(yaml)
        contents = parse_md(md)

        populate_meta(meta, contents)
        add_children(meta, 'chapters', pathname.dirname)
        add_children(meta, 'sections', pathname.dirname)

        meta
      end

      def populate_meta(meta, contents)
        meta[:content] = contents
      end

      def add_children(meta, key, base_dir)
        if meta.has_key?(key)
          child_files = meta[key]
          i = 0
          meta[key] = child_files.map do |child_file|
            child_path = base_dir.join(child_file)

            child_meta = read_file(child_path.to_s)

            i += 1
            child_meta['n'] = i

            child_meta
          end
        end
      end

      # This returns the Hash for this.
      def to_h
        read_file(@primary)
      end
    end
  end
end

