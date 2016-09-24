# RenameProject.py
# Renames all instances of the project's name to match the directory it's in.

from __future__ import print_function
import sys
import os, fnmatch

def find_files(directory, pattern):
	for root, dirs, files in os.walk(directory):
		for basename in files:
			if fnmatch.fnmatch(basename, pattern):
				filename = os.path.join(root, basename)
				yield filename

def replaceInFile(filepath, replacements):
	if filepath.endswith(('.png', '.jar', '.fnt', '.raw', '.gitignore', 'RenameProject.py')):
		return
	print(filepath)
	lines = []
	with open(filepath) as infile:
		for line in infile:
			for src, target in replacements.iteritems():
				line = line.replace(src, target)
			lines.append(line)
	with open(filepath, 'w') as outfile:
		for line in lines:
			outfile.write(line)

#
# Main: enter here
#
def main(argv=None):
	existingName = "HelloGL3"
	newName = os.path.basename(os.path.normpath(os.getcwd()))
	print("Renaming project from [{0}] to [{1}]".format(existingName, newName))
	
	files = []
	for filename in find_files('.', '*'):
		files.append(filename)
	replacements = {
		existingName : newName,
		existingName.lower() : newName.lower(),
	}
	print(replacements)
	for f in files:
		replaceInFile(f, replacements)

	# File rename pass
	dirName = os.path.join('app', 'src', 'main', 'java', 'com', 'android', newName.lower())
	print(dirName)
	if not os.path.exists(dirName):
		os.makedirs(dirName)
	for f in files:
		r = f
		for src, target in replacements.iteritems():
			r = r.replace(src, target)
		if not f == r:
			print(f)
			print(r)
			from shutil import move
			move(f,r)


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
