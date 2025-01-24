#include <iostream>
#include <bit7z/bitarchivereader.hpp>
#include <locale>
#include <test.h>

int main()
{
    std::setlocale(LC_ALL, ".UTF-8");
    try
    { // bit7z classes can throw BitException objects
        using namespace bit7z;

        Bit7zLibrary lib{LIB_DYNAMIC};
        BitArchiveReader arc{lib, "test.rar", BitFormat::Auto};

        // arc.extractTo(".");
        //  Printing archive metadata
        std::cout << "Archive properties\n";
        std::cout << "  Items count: " << arc.itemsCount() << '\n';
        std::cout << "  Folders count: " << arc.foldersCount() << '\n';
        std::cout << "  Files count: " << arc.filesCount() << '\n';
        std::cout << "  Size: " << arc.size() << '\n';
        std::cout << "  Packed size: " << arc.packSize() << "\n\n";

        // Printing the metadata of the archived items
        std::cout << "Archived items";
        for (const auto &item : arc)
        {
            std::cout << '\n';
            std::cout << "  Item index: " << item.index() << '\n';
            std::cout << "    Name: " << item.name() << '\n';
            std::cout << "    Extension: " << item.extension() << '\n';
            std::cout << "    Path: " << item.path() << '\n';
            std::cout << "    IsDir: " << item.isDir() << '\n';
            std::cout << "    Size: " << item.size() << '\n';
            std::cout << "    Packed size: " << item.packSize() << '\n';
            std::cout << "    CRC: " << std::hex << item.crc() << std::dec << '\n';
        }
        std::cout.flush();
    }
    catch (const bit7z::BitException &ex)
    { /* Do something with ex.what()...*/
    }

    return 0;
}