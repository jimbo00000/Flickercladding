// WindowsFunctions.h

#  define WINDOWS_LEAN_AND_MEAN
#  define NOMINMAX
#  include <windows.h> // malloc, free

#include <string>
#include <vector>

struct FileOnDisk
{
    std::string   name;
    LARGE_INTEGER size;
    SYSTEMTIME    lastmodtime;
};

bool DirectoryExists(const char* pDirname);
std::vector<FileOnDisk> GetListOfFilesInDirectory(const char* pDirname, bool showDirs=false, bool showFiles=true);
std::string             GetFileSizeFormatted(LONGLONG sizeBytes);
std::string             GetStringFromSYSTEMTIME(SYSTEMTIME st);
std::string             GetFileCreationTime(const char* pFilename);

void SortFilenameVectorByName(std::vector<FileOnDisk>&);

bool GetDiskSpace(DWORD& freeMBAvailable, DWORD& totalNumberOfMB, const std::wstring& strPath);
bool GetDataDiskSpace(DWORD& freeMBAvailable, DWORD& totalNumberOfMB);
int GetDiskFreePercentage();

void SetTimeZoneGMT(int gmt);
