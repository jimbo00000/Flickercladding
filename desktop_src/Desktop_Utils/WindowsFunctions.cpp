// WindowsFunctions.cpp
#ifdef _WIN32
#include "WindowsFunctions.h"
#include "DebugOutput.h"

#define NOMINMAX
#include <windows.h>

#include <string>
#include <sstream>
#include <vector>
#include <iomanip>
#include <algorithm>

#include <tchar.h>
#include <stdio.h>
#include <strsafe.h>

// http://stackoverflow.com/questions/6218325/how-do-you-check-if-a-directory-exists-on-windows-in-c
bool DirectoryExists(const char* pDirname)
{
    std::string dirNameNarrow(pDirname);
    std::wstring dirNameWide(dirNameNarrow.begin(), dirNameNarrow.end());
    DWORD dwAttrib = ::GetFileAttributes(dirNameWide.c_str());

    return (dwAttrib != INVALID_FILE_ATTRIBUTES && 
         (dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

// http://msdn.microsoft.com/en-us/library/windows/desktop/aa365200(v=vs.85).aspx
std::vector<FileOnDisk> GetListOfFilesInDirectory(const char* pDirname, bool showDirs, bool showFiles)
{
    std::vector<FileOnDisk> files;

    if (pDirname == NULL)
        return files;
    if (strlen(pDirname) >= MAX_PATH)
        return files;

    std::string pathmatch = pDirname;
    pathmatch.append("*");

    WIN32_FIND_DATA ffd;
    TCHAR szDir[MAX_PATH];
    HANDLE hFind = INVALID_HANDLE_VALUE;

#ifdef _DEBUG
    //OutputPrint("Searching for files in [%s]", pathmatch.c_str());
#endif

    size_t retval = 0;
    mbstowcs_s(&retval, &szDir[0], MAX_PATH, pathmatch.c_str(), MAX_PATH);
    if (retval != pathmatch.length() + 1)
    {
        OutputPrint("mbstowcs_s path conversion error.");
    }

    hFind = FindFirstFile(szDir, &ffd);

    if (INVALID_HANDLE_VALUE == hFind)
    {
#ifdef _DEBUG
        //OutputPrint("FindFirstFile returns Invalid handle: No files found in [%s]", pathmatch.c_str());
        return files;
#endif
    }

    do
    {
        ///@note We convert the results of FindFirstFile/FindNextFile back to narrow chars.
        std::wstring wFilename(ffd.cFileName);
        std::string  nFilename(wFilename.begin(), wFilename.end());

        if (!nFilename.compare("."))
            continue;
        if (!nFilename.compare(".."))
            continue;

        const bool isDir = (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        bool addToList = false;
        if (isDir && showDirs)
            addToList = true;
        if (!isDir && showFiles)
            addToList = true;
        if (addToList)
        {
            LARGE_INTEGER filesize;
            filesize.LowPart = ffd.nFileSizeLow;
            filesize.HighPart = ffd.nFileSizeHigh;

            FileOnDisk f;
            f.name = nFilename;
            f.size = filesize;
            FILETIME locFt;
            BOOL ret = FileTimeToLocalFileTime(&ffd.ftLastWriteTime, &locFt);
            if (ret == 0)
            {
                OutputPrint("FileTimeToLocalFileTime error.");
            }
            ret = FileTimeToSystemTime(&locFt, &f.lastmodtime);
            if (ret == 0)
            {
                OutputPrint("FileTimeToSystemTime error.");
            }

            files.push_back(f);
        }
    }
    while (FindNextFile(hFind, &ffd) != 0);

    FindClose(hFind);
    return files;
}

/// Print a given file size in bytes formatted to appropriate units,
/// e.g. "25MB", "4GB", 128kB", etc.
///@param LONGLONG number of bytes
///@return Human-readable string indicating approximate file size.
std::string GetFileSizeFormatted(LONGLONG sizeBytes)
{
    std::ostringstream oss("");
    const LONGLONG kilo = 1024;
    const LONGLONG mega = kilo*kilo;
    const LONGLONG giga = mega * kilo;
    if (sizeBytes > giga)
    {
        oss << sizeBytes / giga
            << "GB";
    }
    else if (sizeBytes > mega)
    {
        oss << sizeBytes / mega
            << "MB";
    }
    else if (sizeBytes > kilo)
    {
        oss << sizeBytes / kilo
            << "KB";
    }
    else
    {
        oss << sizeBytes
            << " bytes";
    }
    return oss.str();
}

std::string GetStringFromSYSTEMTIME(SYSTEMTIME st)
{
    std::ostringstream oss;
    oss << st.wYear
        << "/" << st.wMonth << "/"
        //<< GetMonthName(st.wMonth)
        << st.wDay << " "
        << st.wHour << ":"
        << std::setw(2) << std::setfill('0')
        << st.wMinute;
    return oss.str();
}


std::string GetFileCreationTime(const char* pFilename)
{
    HANDLE hFind;

    WIN32_FIND_DATA FindFileData;
	TCHAR szFilename[MAX_PATH];
    const std::string filename(pFilename);
    size_t retval = 0;
    mbstowcs_s(&retval, &szFilename[0], MAX_PATH, filename.c_str(), MAX_PATH);
    if (retval != filename.length() + 1)
    {
        OutputPrint("mbstowcs_s path conversion error.");
    }

    hFind = FindFirstFile(szFilename, &FindFileData);

    if (hFind == INVALID_HANDLE_VALUE)
        return "";

    FindClose(hFind);

    FILETIME locFt;
    BOOL ret = FileTimeToLocalFileTime(&FindFileData.ftCreationTime, &locFt);
    if (ret == 0)
    {
        OutputPrint("FileTimeToLocalFileTime error.");
    }
    SYSTEMTIME sysTime;
    ret = FileTimeToSystemTime(&locFt, &sysTime);
    if (ret == 0)
    {
        OutputPrint("FileTimeToSystemTime error.");
    }

    return GetStringFromSYSTEMTIME(sysTime);
}

///@brief Sort File list lexicographically by name
bool FileSortFunction(const FileOnDisk& i, const FileOnDisk& j)
{
    return (i.name.compare(j.name) < 0);
}

void SortFilenameVectorByName(std::vector<FileOnDisk>& filenames)
{
    std::sort(filenames.begin(), filenames.end(), FileSortFunction);
}


/// Get the used and available disk space from the volume containing the given path.
///@param freeGBAvailable [inout] Number of available GB on disk
///@param totalNumberOfGB [inout] Number of total GB on disk
///@param strPath [in] Filesystem path to query
///@return True if query was successful, false otherwise
bool GetDiskSpace(DWORD& freeMBAvailable, DWORD& totalNumberOfMB, const std::wstring& strPath)
{
    if (strPath.empty())
        return false;

    bool bDataFound = false;

    for (int nTry = 0; nTry < 10; ++nTry)
    {
        ULARGE_INTEGER ulFreeBytesAvailableToCaller;
        ULARGE_INTEGER ulTotalNumberOfBytes;
        ULARGE_INTEGER ulTotalNumberOfFreeBytes;
        ulFreeBytesAvailableToCaller.QuadPart = 0;

        bDataFound = (0 != ::GetDiskFreeSpaceEx(strPath.c_str(),
            &ulFreeBytesAvailableToCaller,
            &ulTotalNumberOfBytes,
            &ulTotalNumberOfFreeBytes ));
        if (bDataFound)
        {
            const ULONGLONG bytesPerMB = (1024ULL*1024ULL);
            const ULONGLONG freeMBAvailableULL = ulFreeBytesAvailableToCaller.QuadPart / bytesPerMB;
            const ULONGLONG totalNumberOfMBULL = ulTotalNumberOfBytes.QuadPart / bytesPerMB;
            freeMBAvailable = static_cast<DWORD>(freeMBAvailableULL);
            totalNumberOfMB = static_cast<DWORD>(totalNumberOfMBULL);
            break;
        }
        ::Sleep(100);
    }

    return bDataFound;
}

bool GetDataDiskSpace(DWORD& freeMBAvailable, DWORD& totalNumberOfMB)
{
#ifdef _WIN32_WCE
    const std::wstring rootDataPath(L"SD Card\\");
#else
    const std::wstring rootDataPath(L"C:\\");
#endif
    return GetDiskSpace(freeMBAvailable, totalNumberOfMB, rootDataPath);
}

int GetDiskFreePercentage()
{
    int pctg = 0;
    DWORD freeMB = 0;
    DWORD totalMB = 0;
    if (GetDataDiskSpace(freeMB, totalMB))
    {
        const float freeFraction = static_cast<float>(freeMB) / static_cast<float>(totalMB);
        const float usedFraction = 1.0f - freeFraction;
        pctg = static_cast<int>(100.0f * usedFraction);
    }
    return pctg;
}

void SetTimeZoneGMT(int gmt)
{
#ifdef _WIN32_WCE
    // Handle Time Zone information
    // http://msdn.microsoft.com/en-us/library/windows/desktop/ms724944(v=vs.85).aspx
    TIME_ZONE_INFORMATION tziOld, tziNew;
    DWORD dwRet = GetTimeZoneInformation(&tziOld);
    if (dwRet == TIME_ZONE_ID_STANDARD || dwRet == TIME_ZONE_ID_UNKNOWN)
    {
        //wprintf(L"%s\n", tziOld.StandardName);
    }
    else if(dwRet == TIME_ZONE_ID_DAYLIGHT)
    {
        //wprintf(L"%s\n", tziOld.DaylightName);
    }
    else
    {
        printf("GTZI failed (%d)\n", GetLastError());
    }

    // Set up the new time zone struct
    // Round values to the nearest hour
    ///@todo Support minute Time zone offsets
    memcpy(&tziNew, &tziOld, sizeof(TIME_ZONE_INFORMATION));

    ///@note Wince 6 seems to get time zones negative...
    const int biasMinutes = -60 * gmt;
    tziNew.Bias = biasMinutes;

    if (!::SetTimeZoneInformation(&tziNew))
    {
        printf("STZI failed (%d)\n", GetLastError());
    }
#else
    (void)gmt;
#endif
}
#endif
