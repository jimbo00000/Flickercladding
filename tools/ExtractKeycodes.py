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


def extractKeysFromSDL():
	"""Print key value/id pairs for the SDL library to stdout."""
	header = "SDL_keycode.h"
	sdlpath = os.path.join("C:/lib", "SDL2-2.0.3", "include", header)
	with open(sdlpath) as infile:
		for line in infile:
			if "SDLK_" in line:
				arr = line.split()
				if arr[1] == '=':
					ch = arr[2][1:-2]
					if len(ch) == 1:
						#print(arr[0], ch, str(ch), ord(str(ch)))
						lua = '    [{0}] = "{1}",'.format(ord(str(ch)), arr[0].replace("SDLK", "KEY").upper())
						print(lua)


def extractKeysFromAndroidSDK():
	"""Print key value/id pairs for the Android SDK to stdout."""
	srcfile = "KeyEvent.java"
	sdlpath = os.path.join("C:/Users", "Jim", "AppData", "Local", "Android", "sdk", "sources", "android-23", "android", "view", srcfile)
	with open(sdlpath) as infile:
		for line in infile:
			if "KEYCODE_" in line:
				arr = line.split()
				if len(arr) > 5 and arr[5] == "=":
					#print(arr)
					lua = '    [{0}] = "{1}",'.format(arr[6][:-1], arr[4].replace("KEYCODE", "KEY").upper())
					print(lua)


#
# Main: enter here
#
def main(argv=None):
	#extractKeysFromGlfw()
	#extractKeysFromSDL()
	extractKeysFromAndroidSDK()

if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
