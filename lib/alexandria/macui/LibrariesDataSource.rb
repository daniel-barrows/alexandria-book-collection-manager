# Copyright (C) 2005 Laurent Sansonetti
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

module Alexandria
module UI
    class LibrariesDataSource < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        attr_reader :libraries
        
        def awakeFromNib
            @libraries = Library.loadall
        end
        
        def addLibraryWithAutogeneratedName
            i = 1
            while true do
                name = _("Untitled %d") % i
                break unless @libraries.find { |x| x.name == name }
                i += 1
            end
            library = Library.load(name)
            self.addLibrary(library)
        end
        
        def addLibrary(library)
            @libraries << library
        end
        
        def removeLibraryAtIndex(row)
            library = @libraries[row]
            library.delete
            @libraries.delete(library)
        end
        
        def numberOfRowsInTableView(tableView)
            _librariesCount
        end
        
        def numberOfItemsInComboBox(comboBox)
            _librariesCount
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            _libraryAtIndex(row).name
        end
        
        def comboBox_objectValueForItemAtIndex(comboBox, index)
            _libraryAtIndex(index).name
        end
        
        def tableView_setObjectValue_forTableColumn_row(tableView, objectValue, col, row)
            newName = objectValue.to_s
            if newName !~ /([^\w\s'"()?!:;.\-])/ and
               newName.length > 0 and
               @libraries.find { |x| x.name == newName } == nil

                _libraryAtIndex(row).name = newName
            end
        end
        
        #######
        private
        #######
        
        def _librariesCount
            @libraries != nil ? @libraries.length : 0
        end
        
        def _libraryAtIndex(index)
            @libraries[index]
        end
    end
end
end