#!/usr/bin/python3


import sys
import os
from os import listdir


def get_file_abspath(dir):
    """
    get files absoulate path in dir, incude dirs in dir
    """
    absdir = os.path.abspath(dir)
    files = listdir(dir)
    file_abspath = [ os.path.join(absdir, f_path) for f_path in files]
    return file_abspath

def filter(str_list, pattern=None):
    """
    docstring
    """
    if pattern == None: 
        return str_list

    plen = len(pattern)
    return [s for s in str_list if s[-plen:]==pattern]
    
    


def print_files_abspath(dirlist, pattern=None, prefix=None):
    """
    """
    filelist = []

    for dir in dirlist:
        filelist = filelist + filter(get_file_abspath(dir), pattern)

    with open("./filelist", "w") as f:
        for s in filelist:
            if prefix != None: 
                f.write(prefix)
            f.write(s)
            f.write("\n")

        





if __name__ == "__main__":
    "getfilelist pattern dir"

    l = len(sys.argv)
    print(l)
    print(sys.argv)
    if(l < 2):
        print("usage: getfilelist -p<pattern> -x<prefix> dir1, dir2, dir3...")
        exit()


    if l == 2:
        print_files_abspath(sys.argv[1:2])
        exit()

    pattern = None
    prefix = None
    dirstart = 1
    for s in sys.argv[1:3]:
        print(s)
        if "-p" in s:
            print(s)
            pattern = s[2:]
            dirstart += 1
      
        
        if "-x" in s:
            prefix = s[2:]
            dirstart += 1
     

    print_files_abspath(sys.argv[dirstart:], pattern, prefix)
    

   
    
    
