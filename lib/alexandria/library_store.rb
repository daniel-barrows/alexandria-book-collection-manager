# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  class LibraryStore
    include Logging

    FIX_BIGNUM_REGEX =
      /loaned_since:\s*(\!ruby\/object\:Bignum\s*)?(\d+)\n/

    def initialize(dir)
      @dir = dir
    end

    def load_library(name)
      test = [0, nil]
      ruined_books = []
      library = Library.new(name)
      FileUtils.mkdir_p(library.path) unless File.exist?(library.path)
      Dir.chdir(library.path) do
        Dir['*' + Library::EXT[:book]].each do |filename|
          test[1] = filename if (test[0]).zero?

          unless File.size? test[1]
            log.warn { "Book file #{test[1]} was empty" }
            md = /([\dxX]{10,13})#{Library::EXT[:book]}/.match(filename)
            if md
              file_isbn = md[1]
              ruined_books << [nil, file_isbn, library]
            else
              log.warn { "Filename #{filename} does not contain an ISBN" }
              # TODO: delete this file...
            end
            next
          end
          book = regularize_book_from_yaml(test[1])
          old_isbn = book.isbn
          old_pub_year = book.publishing_year
          begin
            raise "Not a book: #{book.inspect}" unless book.is_a?(Book)
            ean = Library.canonicalise_ean(book.isbn)
            book.isbn = ean if ean

            book.publishing_year = book.publishing_year.to_i unless book.publishing_year.nil?

            # Or if isbn has changed
            raise "#{test[1]} isbn is not okay" unless book.isbn == old_isbn

            # Re-save book if Alexandria::DATA_VERSION changes
            raise "#{test[1]} version is not okay" unless book.version == Alexandria::DATA_VERSION

            # Or if publishing year has changed
            raise "#{test[1]} pub year is not okay" unless book.publishing_year == old_pub_year

            # ruined_books << [book, book.isbn, library]
            book.library = library.name

            ## TODO copy cover image file, if necessary
            # due to #26909 cover files for books without ISBN are re-saved as "g#{ident}.cover"
            if book.isbn.nil? || book.isbn.empty?
              if File.exist? library.old_cover(book)
                log.debug { "#{library.name}; book #{book.title} has no ISBN, fixing cover image" }
                FileUtils::Verbose.mv(library.old_cover(book), library.cover(book))
              end
            end

            library << book
          rescue StandardError
            book.version = Alexandria::DATA_VERSION
            savedfilename = library.simple_save(book)
            test[0] = test[0] + 1
            test[1] = savedfilename

            # retries the Dir.each block...
            # but gives up after three tries
            redo unless test[0] > 2
          else
            test = [0, nil]
          end
        end

        # Since 0.4.0 the cover files '_small.jpg' and
        # '_medium.jpg' have been deprecated for a single medium
        # cover file named '.cover'.

        Dir['*' + '_medium.jpg'].each do |medium_cover|
          begin
            FileUtils.mv(medium_cover,
                         medium_cover.sub(/_medium\.jpg$/,
                                          Library::EXT[:cover]))
          rescue StandardError
          end
        end

        Dir['*' + Library::EXT[:cover]].each do |cover|
          next if cover[0] == 'g'
          md = /(.+)\.cover/.match(cover)
          ean = Library.canonicalise_ean(md[1]) || md[1]
          begin
            FileUtils.mv(cover, ean + Library::EXT[:cover]) unless cover == ean + Library::EXT[:cover]
          rescue StandardError
          end
        end

        FileUtils.rm_f(Dir['*_small.jpg'])
      end
      library.ruined_books = ruined_books

      library
    end

    def regularize_book_from_yaml(name)
      text = IO.read(name)

      # Code to remove the mystery string in books imported from Amazon
      # (In the past, still?) To allow ruby-amazon to be removed.

      # The string is removed on load, but can't make it stick, maybe has to do with cache

      if text =~ /!str:Amazon::Search::Response/
        log.debug { "Removing Ruby/Amazon strings from #{name}" }
        text.gsub!('!str:Amazon::Search::Response', '')
      end

      # Backward compatibility with versions <= 0.6.0, where the
      # loaned_since field was a numeric.
      if (md = FIX_BIGNUM_REGEX.match(text))
        new_yaml = Time.at(md[2].to_i).to_yaml
        # Remove the "---" prefix.
        new_yaml.sub!(/^\s*\-+\s*/, '')
        text.sub!(md[0], "loaned_since: #{new_yaml}\n")
      end

      # TODO: Ensure book loading passes through Book#initialize
      book = YAML.safe_load(text, whitelist_classes = [Book, Time])

      unless book.isbn.class == String
        # HACK
        md = /isbn: (.+)/.match(text)
        if md
          string_isbn = md[1].strip
          book.isbn = string_isbn
        end
      end

      # another HACK of the same type as above
      unless book.saved_ident.class == String

        md2 = /saved_ident: (.+)/.match(text)
        if md2
          string_saved_ident = md2[1].strip
          log.debug { "fixing saved_ident #{book.saved_ident} -> #{string_saved_ident}" }
          book.saved_ident = string_saved_ident
        end
      end
      if (book.isbn.class == String) && book.isbn.empty?
        book.isbn = nil # save trouble later
      end
      book
    end

  end
end
