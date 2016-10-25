# ExtractKeycodes.py

from __future__ import print_function
import sys
import os, fnmatch

def extractKeysFromGlfw():
	"""Print key value/id pairs for the Glfw library to stdout."""
	header = "glfw3.h"
	glfwpath = os.path.join("C:/lib", "glfw-3.1.2.bin.WIN32", "include", "GLFW", header)
	with open(glfwpath) as infile:
		for line in infile:
			if "#define GLFW_KEY" in line:
				arr = line.split()
				#print(arr)
				lua = '    [{0}] = "{1}",'.format(arr[2], arr[1].replace("GLFW_KEY", "KEY"))
				print(lua)
#
# Main: enter here
#
def main(argv=None):
	extractKeysFromGlfw()

if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
