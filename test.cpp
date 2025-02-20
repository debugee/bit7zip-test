#include <iostream>
#include <bit7z/bitarchivereader.hpp>
#include <locale>
#include <filesystem>
#include <test.h>
#include <iconv.h>

namespace fs = std::filesystem;

std::string convert(const std::string &input, const char *fromC, const char *toC) {
    iconv_t cd = iconv_open(toC, fromC);
    if (cd == (iconv_t)-1) {
        throw std::runtime_error("iconv_open failed");
    }

    size_t inBytes = input.size();
    size_t outBytes = inBytes * 4; // Allocate enough space for the output
    std::string output(outBytes, '\0');

    char *inBuf = const_cast<char *>(input.data());
    char *outBuf = &output[0];

    if (iconv(cd, &inBuf, &inBytes, &outBuf, &outBytes) == (size_t)-1) {
        iconv_close(cd);
        throw std::runtime_error("iconv failed");
    }

    iconv_close(cd);
    output.resize(output.size() - outBytes); // Resize to the actual output size
    return output;
}

std::string convertToUtf8(const std::wstring &input) {
    const char *fromC = "UTF-32LE";
#ifdef _WIN32
    fromC = "UTF-16LE";
#endif
    iconv_t cd = iconv_open("UTF-8", fromC);
    if (cd == (iconv_t)-1) {
        throw std::runtime_error("iconv_open failed");
    }

    std::vector<char> inbuf((char*)input.data(), (char*)input.data() + input.size() * sizeof(wchar_t));
    std::vector<char> outbuf(inbuf.size() * 2);
    char *inptr = inbuf.data();
    char *outptr = outbuf.data();
    size_t inbytesleft = inbuf.size();
    size_t outbytesleft = outbuf.size();

    if (iconv(cd, &inptr, &inbytesleft, &outptr, &outbytesleft) == (size_t)-1) {
        iconv_close(cd);
        throw std::runtime_error("iconv failed");
    }

    iconv_close(cd);
    return std::string(outbuf.data(), outbuf.size() - outbytesleft);
}

void processArchive(const std::string &archiveFile)
{
    try
    {
        using namespace bit7z;

        Bit7zLibrary lib{LIB_DYNAMIC};
        BitArchiveReader arc{lib, archiveFile, BitFormat::Auto};
        
        // arc.extractTo(".");
        //  Printing archive metadata
        std::cout << "Archive properties\n";
        std::cout << "  Items count: " << arc.itemsCount() << std::endl;
        std::cout << "  Folders count: " << arc.foldersCount() << std::endl;
        std::cout << "  Files count: " << arc.filesCount() << std::endl;
        std::cout << "  Size: " << arc.size() << std::endl;
        std::cout << "  Packed size: " << arc.packSize() << "\n\n";

        // Printing the metadata of the archived items
        std::cout << "Archived items";
        for (const auto &item : arc)
        {
            std::cout << std::endl;
            std::cout << "  Item index: " << item.index() << std::endl;
            //7zip return utf-16 string by CHandler::GetProperty(CPP/7zip/Archive/Zip/ZipHandler.cpp)
            //return UString contain two wchar_t descript surrogate pair
            //if windows, this is right for utf-16 string
            //is other os, this is difference with wchar_t * (utf-32, one wchar_t descript surrogate pair)
            //7zz intelnal use UString(two wchar_t descript surrogate pair) transfer back use function CStdOutStream::Convert_UString_to_AString,when cout
            //so 7zz have no error with this
            //but bit7z use BitPropVariant::getNativeString() (src/bitpropvariant.cpp) to get UString(contain two wchar_t descript surrogate pair) from 7z
            //and bit7z::narrow transfer UString to std::string, it will cause error
            //so item.name() throw Exception: wstring_convert: to_bytes error
            std::cout << "    Name: " << item.name() << std::endl;
            std::cout << "    Extension: " << item.extension() << std::endl;
            std::cout << "    Path: " << item.path() << std::endl;
            std::cout << "    IsDir: " << item.isDir() << std::endl;
            std::cout << "    Size: " << item.size() << std::endl;
            std::cout << "    Packed size: " << item.packSize() << std::endl;
            std::cout << "    CRC: " << std::hex << item.crc() << std::dec << std::endl;
        }
        std::cout.flush();
    }
    catch (const bit7z::BitException &ex)
    {
        std::cerr << "Exception: " << ex.what() << std::endl;
    }
    catch(const std::exception &ex)
    {
        std::cerr << "Exception: " << ex.what() << std::endl;
    }
}

#ifdef _WIN32
int wmain(int argc, wchar_t *argv[])
#else
int main(int argc, char *argv[])
#endif
{

    std::vector<std::string> args;
#ifdef _WIN32
    for(int i = 0; i < argc; i++) {
        args.push_back(convertToUtf8(argv[i]));
    }
#else
    for(int i = 0; i < argc; i++) {
        args.push_back(argv[i]);
    }
#endif
    //mingw-gcc only support "C" and "POSIX"
    //llvm-mingw support ok
    std::locale::global(std::locale("zh_CN.UTF-8"));
    std::cin.imbue(std::locale());
    std::cout.imbue(std::locale());
    std::cerr.imbue(std::locale());

    if (argc <= 1)
    {
        std::cerr << "Usage: " << args[0] << " <file_or_directory>\n";
        return 1;
    }

    //path(string)
    //libc++ treat string as system code page, msvcp treat string as c++ locale
    fs::path path = fs::u8path(args[1]);
    std::cout << args[1] << std::endl;
    try
    {   
        std::wstring wstr_path = path.wstring();
        std::string str_path = convertToUtf8(wstr_path);
        if (fs::is_directory(path))
        {
            for (const auto &entry : fs::directory_iterator(path))
            {
                wstr_path = entry.path().wstring();
                str_path = convertToUtf8(wstr_path);
                if (entry.is_regular_file())
                {
                    std::cout << "Processing archive: " << str_path << std::endl;
                    processArchive(str_path);
                }
            }
        }
        else if (fs::is_regular_file(path))
        {
            std::cout << "Processing archive: " << str_path << std::endl;
            processArchive(str_path);
        }
        else
        {
            std::cerr << "Error: " << convertToUtf8(path.wstring()) << " is neither a file nor a directory.\n";
            return 1;
        }
    }
    catch (const fs::filesystem_error &ex)
    {
        std::cerr << "Exception: " << ex.what() << std::endl;
        return 1;
    }
    catch(const std::exception &ex)
    {
        std::cerr << "Exception: " << ex.what() << std::endl;
        return 1;
    }


    return 0;
}
