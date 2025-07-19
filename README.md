# IPL demo

This program targets an IPL present in FDS games developed by Namco.
Once loaded, a CRC32 checksum of the $0200~$07FF region occupied by the IPL will be calculated and displayed.
The checksum for the IPL extracted from Pac-Man (FDS) is `D908C459`.

## Usage

See [IPL-MAIN](https://github.com/TakuikaNinja/IPL-MAIN) for transfer setup and usage instructions.

## Building

Required tools:
- CC65 toolchain: https://cc65.github.io/
- Python IntelHex library: https://github.com/python-intelhex/intelhex

A simple `make` should then work.

## Acknowledgements

`Jroatch-chr-sheet.chr` was converted from the following placeholder CHR sheet: 
https://www.nesdev.org/wiki/File:Jroatch-chr-sheet.chr.png
It contains tiles from Generitiles by Drag, Cavewoman by Sik, and Chase by shiru.

The NESdev Wiki, Forums, and Discord have been a massive help. 
Kudos to everyone keeping this console generation alive!
