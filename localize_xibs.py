#!/usr/bin/env python
'''
  PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2009 Ian Wagner
  
	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.
  
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
  
	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
	
	This file is used to generate localized xib files from their corresponding .strings files.
	
	NOTE: You should NEVER EDIT ANY XIB FILE EXCEPT THE ENGLISH ONE!!! The other xib's are
	generated from the objects in the English one. Localizations are generated from the strings in
	the strings files.
'''
import sys
import os

if len(sys.argv) < 2:
  print 'Usage: localize_xibs.py path'
  print '  path  The directory from which the xib files may be reached'
  sys.exit(1)
elif not os.path.exists(sys.argv[-1]):
  print 'path "%s" does not exist!' % sys.argv[-1]
  sys.exit(1)

for root, dirs, files in os.walk(sys.argv[-1]):
  for file in files:
	# Check that we are generating strings for a valid file (a non-english xib file)
    if len(file) > 4 and file[-4:] == '.xib' and 'English.lproj' not in root:
      basename = os.path.join(root, file)[:-4]
      if not os.path.exists(basename + '.strings'):
        print 'Not writing strings for %s.xib' % basename
        continue
      #cmd = 'ibtool --strings-file "%s.strings" --write "%s.xib" "%s/English.lproj/%s"' % (basename, basename, sys.argv[-1], file)
      cmd = 'cp "%s/English.lproj/%s" "%s.xib"' % (sys.argv[-1], file, basename)
      if os.system(cmd) != 0:
        print 'failed to execute command: %s' % cmd